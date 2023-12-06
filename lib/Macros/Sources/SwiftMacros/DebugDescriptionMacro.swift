//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import _StringProcessing // for String.contains(_:)

public enum DebugDescriptionMacro {}
public enum _DebugDescriptionPropertyMacro {}

/// A macro which orchestrates conversion of a description property to an LLDB type summary.
///
/// The job of conversion is split across two macros. This macro performs some analysis on the attached
/// type, and then delegates to `@_DebugDescriptionProperty` to perform the conversion step.
extension DebugDescriptionMacro: MemberAttributeMacro {
    public static func expansion<DeclGroup, DeclSyntax, Context>(
        of node: AttributeSyntax,
        attachedTo declaration: DeclGroup,
        providingAttributesFor member: DeclSyntax,
        in context: Context
    )
    throws -> [AttributeSyntax]
    where DeclGroup: DeclGroupSyntax, DeclSyntax: DeclSyntaxProtocol, Context: MacroExpansionContext
    {
        guard !declaration.is(ProtocolDeclSyntax.self) else {
            let message: ErrorMessage = "cannot be attached to a protocol"
            context.diagnose(node: node, error: message)
            return []
        }

        guard let typeName = declaration.concreteTypeName else {
            let message: ErrorMessage = "cannot be attached to a \(declaration.kind.declName)"
            context.diagnose(node: node, error: message)
            return []
        }

        guard let propertyName = member.as(VariableDeclSyntax.self)?.bindings.only?.name else {
            return []
        }

        guard propertyName == "debugDescription" || propertyName == "description" else {
            return []
        }

        // Expansion is performed multiple times. Exit early to avoid emitting duplicate macros,
        // which leads to duplicate symbol errors. To distinguish been invocations, inspect the
        // current mangled name. This ignores the invocation that adds a "__vg" suffix to the member
        // name, ex "description__vg". See https://github.com/apple/swift/pull/65559.
        let mangledName = context.makeUniqueName("").text
        let substring = "\(propertyName)__vg"
        // Ex: "15description__vg"
        let runlengthSubstring = "\(substring.count)\(substring)"
        guard !mangledName.contains(runlengthSubstring) else {
            return []
        }

        var properties: [String: PatternBindingSyntax] = [:]
        for member in declaration.memberBlock.members {
            for binding in member.decl.as(VariableDeclSyntax.self)?.bindings ?? [] {
                if let name = binding.name {
                    properties[name] = binding
                }
            }
        }

        // `debugDescription` takes priority: skip `description` if `debugDescription` also exists.
        if propertyName == "description" && properties["debugDescription"] != nil {
            return []
        }

        guard let moduleName = context.moduleName(of: declaration) else {
            // Assertion as a diagnostic.
            let message: ErrorMessage = "could not determine module name from fileID (internal error)"
            context.diagnose(node: declaration, error: message)
            return []
        }

        var typeIdentifier: String
        if let typeParameters = declaration.asProtocol(WithGenericParametersSyntax.self)?.genericParameterClause?.parameters, typeParameters.count > 0 {
            let typePatterns = Array(repeating: ".+", count: typeParameters.count).joined(separator: ",")
            // A regex matching that matches the generic type.
            typeIdentifier = "^\(moduleName)\\.\(typeName)<\(typePatterns)>"
        } else if declaration.is(ExtensionDeclSyntax.self) {
            // When attached to an extension, the type may or may not be a generic type.
            // This regular expression handles both cases.
            typeIdentifier = "^\(moduleName)\\.\(typeName)(<.+>)?$"
        } else {
            typeIdentifier = "\(moduleName).\(typeName)"
        }

        let computedProperties = properties.values.filter(\.isComputedProperty).compactMap(\.name)

        return ["@_DebugDescriptionProperty(\"\(raw: typeIdentifier)\", \(raw: computedProperties))"]
    }
}

/// An internal macro which performs which converts compatible description implementations to an LLDB type
/// summary.
///
/// The LLDB type summary record is emitted into a custom section, which LLDB loads from at debug time.
///
/// Conversion has limitations, primarily that expression evaluation is not supported. If a description
/// property calls another function, it cannot be converted. When conversion cannot be performed, an error
/// diagnostic is emitted.
///
/// Note: There is one ambiguous case: computed properties. The macro can identify some, but not all, uses of
/// computed properties. When a computed property cannot be identified at compile time, LLDB will emit a
/// warning at debug time.
///
/// See https://lldb.llvm.org/use/variable.html#type-summary
extension _DebugDescriptionPropertyMacro: PeerMacro {
    public static func expansion<Decl, Context>(
        of node: AttributeSyntax,
        providingPeersOf declaration: Decl,
        in context: Context
    )
    throws -> [DeclSyntax]
    where Decl: DeclSyntaxProtocol, Context: MacroExpansionContext
    {
        guard let arguments = node.arguments else {
            // Assertion as a diagnostic.
            let message: ErrorMessage = "no arguments given to _DebugDescriptionProperty (internal error)"
            context.diagnose(node: node, error: message)
            return []
        }

        guard case .argumentList(let argumentList) = arguments else {
            // Assertion as a diagnostic.
            let message: ErrorMessage = "unexpected arguments to _DebugDescriptionProperty (internal error)"
            context.diagnose(node: arguments, error: message)
            return []
        }

        let argumentExprs = argumentList.map(\.expression)
        guard argumentExprs.count == 2,
              let typeIdentifier = String(expr: argumentExprs[0]),
              let computedProperties = Array<String>(expr: argumentExprs[1]) else {
            // Assertion as a diagnostic.
            let message: ErrorMessage = "incorrect arguments to _DebugDescriptionProperty (internal error)"
            context.diagnose(node: argumentList, error: message)
            return []
        }

        guard let onlyBinding = declaration.as(VariableDeclSyntax.self)?.bindings.only else {
            // Assertion as a diagnostic.
            let message: ErrorMessage = "invalid declaration of _DebugDescriptionProperty (internal error)"
            context.diagnose(node: declaration, error: message)
            return []
        }

        // Validate the body of the description function.
        //   1. The code block must have a single item
        //   2. The single item must be a return of a string literal
        //   3. Later on, the interpolation in the string literal will be validated.
        guard let codeBlock = onlyBinding.accessorBlock?.accessors.as(CodeBlockItemListSyntax.self),
              let descriptionString = codeBlock.onlyReturnExpr?.as(StringLiteralExprSyntax.self) else {
            let message: ErrorMessage = "body must consist of a single string literal"
            context.diagnose(node: declaration, error: message)
            return []
        }

        // Iterate the string's segments, and convert property expressions into LLDB variable references.
        var summarySegments: [String] = []
        for segment in descriptionString.segments {
            switch segment {
            case let .stringSegment(segment):
                summarySegments.append(segment.content.text)
            case let .expressionSegment(segment):
                guard let onlyLabeledExpr = segment.expressions.only, onlyLabeledExpr.label == nil else {
                    // This catches `appendInterpolation` overrides.
                    let message: ErrorMessage = "unsupported custom string interpolation expression"
                    context.diagnose(node: segment, error: message)
                    return []
                }

                let expr = onlyLabeledExpr.expression

                // "Parse" the expression into a flattened chain of property accesses.
                var propertyChain: [DeclReferenceExprSyntax] = []
                var invalidExpr: ExprSyntax? = nil
                if let declRef = expr.as(DeclReferenceExprSyntax.self) {
                    // A reference to a single property on self.
                    propertyChain.append(declRef)
                } else if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
                    do {
                        propertyChain = try memberAccess.propertyChain()
                    } catch let error as UnexpectedExpr {
                        invalidExpr = error.expr
                    }
                } else {
                    // The expression was neither a DeclReference nor a MemberAccess.
                    invalidExpr = expr
                }

                if let invalidExpr {
                    let message: ErrorMessage = "only references to stored properties are allowed"
                    context.diagnose(node: invalidExpr, error: message)
                    return []
                }

                // Eliminate explicit self references. The debugger doesn't support `self` in
                // variable paths.
                propertyChain.removeAll(where: { $0.baseName.tokenKind == .keyword(.self) })

                // Check that the root property is not a computed property of `self`. Ideally, all
                // properties would be verified, but a macro expansion has limited scope.
                guard let rootProperty = propertyChain.first else {
                    return []
                }

                guard !computedProperties.contains(where: { $0 == rootProperty.baseName.text }) else {
                    let message: ErrorMessage = "cannot reference computed properties"
                    context.diagnose(node: rootProperty, error: message)
                    return []
                }

                let propertyPath = propertyChain.map(\.baseName.text).joined(separator: ".")
                summarySegments.append("${var.\(propertyPath)}")
            @unknown default:
                let message: ErrorMessage = "unexpected string literal segment"
                context.diagnose(node: segment, error: message)
                return []
            }
        }

        let summaryString = summarySegments.joined()

        // Serialize the type summary into a global record, in a custom section, for LLDB to load.
        let decl: DeclSyntax = """
        #if os(Linux)
        @_section(".lldbsummaries")
        #elseif os(Windows)
        @_section(".lldbsummaries")
        #else
        @_section("__DATA_CONST,__lldbsummaries")
        #endif
        @_used
        static let _lldb_summary = (
            \(raw: encodeTypeSummaryRecord(typeIdentifier, summaryString))
        )
        """

        return [decl]
    }
}

// MARK: - Encoding

fileprivate let ENCODING_VERSION: UInt = 1

/// Construct an LLDB type summary record.
///
/// The record is serializeed as a tuple of `UInt8` bytes.
///
/// The record contains the following:
///   * Version number of the record format
///   * The size of the record (encoded as ULEB)
///   * The type identifier, which is either a type name, or for generic types a type regex
///   * The description string converted to an LLDB summary string
///
/// The strings (type identifier and summary) are encoded with both a length prefix (also ULEB)
/// and with a null terminator.
fileprivate func encodeTypeSummaryRecord(_ typeIdentifier: String, _ summaryString: String) -> String {
    let encodedIdentifier = typeIdentifier.byteEncoded
    let encodedSummary = summaryString.byteEncoded
    let recordSize = UInt(encodedIdentifier.count + encodedSummary.count)
    return """
    /* version */ \(swiftLiteral: ENCODING_VERSION.ULEBEncoded),
    /* record size */ \(swiftLiteral: recordSize.ULEBEncoded),
    /* "\(typeIdentifier)" */ \(swiftLiteral: encodedIdentifier),
    /* "\(summaryString)" */ \(swiftLiteral: encodedSummary)
    """
}

extension DefaultStringInterpolation {
    /// Generate a _partial_ Swift literal from the given bytes. It is partial in that must be embedded
    /// into some other syntax, specifically as a tuple.
    fileprivate mutating func appendInterpolation(swiftLiteral bytes: [UInt8]) {
        let literalBytes = bytes.map({ "\($0) as UInt8" }).joined(separator: ", ")
        appendInterpolation(literalBytes)
    }
}

extension String {
    /// Encode a string into UTF8 bytes, prefixed by a ULEB length, and suffixed by the null terminator.
    fileprivate var byteEncoded: [UInt8] {
        let size = UInt(self.utf8.count) + 1 // including null terminator
        var bytes: [UInt8] = []
        bytes.append(contentsOf: size.ULEBEncoded)
        bytes.append(contentsOf: self.utf8)
        bytes.append(0) // null terminator
        return bytes
    }
}

extension UInt {
    /// Encode an unsigned integer into ULEB format. See https://en.wikipedia.org/wiki/LEB128
    fileprivate var ULEBEncoded: [UInt8] {
        guard self > 0 else {
            return [0]
        }

        var bytes: [UInt8] = []
        var buffer = self
        while buffer > 0 {
            var byte = UInt8(buffer & 0b0111_1111)
            buffer >>= 7
            if buffer > 0 {
                byte |= 0b1000_0000
            }
            bytes.append(byte)
        }
        return bytes
    }
}

// MARK: - Diagnostics

fileprivate struct ErrorMessage: DiagnosticMessage, ExpressibleByStringInterpolation {
    init(stringLiteral value: String) {
        self.message = value
    }
    var message: String
    var diagnosticID: MessageID { .init(domain: "DebugDescription", id: "DebugDescription")}
    var severity: DiagnosticSeverity { .error }
}

extension MacroExpansionContext {
    fileprivate func diagnose(node: some SyntaxProtocol, error message: ErrorMessage) {
        diagnose(Diagnostic(node: node, message: message))
    }
}

// MARK: - Syntax Tree Helpers

extension MacroExpansionContext {
    /// Determine the module name of the Syntax node, via its fileID.
    /// See https://developer.apple.com/documentation/swift/fileid()
    fileprivate func moduleName<T: SyntaxProtocol>(of node: T) -> String? {
        if let fileID = self.location(of: node)?.file.as(StringLiteralExprSyntax.self)?.representedLiteralValue,
           let firstSlash = fileID.firstIndex(of: "/") {
            return String(fileID.prefix(upTo: firstSlash))
        }
        return nil
    }
}

extension DeclGroupSyntax {
    /// The name of the concrete type represented by this `DeclGroupSyntax`.
    /// This excludes protocols, which return nil.
    fileprivate var concreteTypeName: String? {
        switch self.kind {
        case .actorDecl, .classDecl, .enumDecl, .structDecl:
            return self.asProtocol(NamedDeclSyntax.self)?.name.text
        case .extensionDecl:
            return self.as(ExtensionDeclSyntax.self)?.extendedType.description
        default:
            // New types of decls are not presumed to be valid.
            return nil
        }
        return nil
    }
}

extension SyntaxKind {
    fileprivate var declName: String {
        var name = String(describing: self)
        name.removeSuffix("Decl")
        return name
    }
}

extension String {
    fileprivate mutating func removeSuffix(_ suffix: String) {
        if self.hasSuffix(suffix) {
            return self.removeLast(suffix.count)
        }
    }
}

extension PatternBindingSyntax {
    /// The property's name.
    fileprivate var name: String? {
        self.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }

    /// Predicate which identifies computed properties.
    fileprivate var isComputedProperty: Bool {
        switch self.accessorBlock?.accessors {
        case nil:
            // No accessor block, not computed.
            return false
        case .accessors(let accessors)?:
            // A `get` accessor indicates a computed property.
            return accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.get) }
        case .getter?:
            // A property with an implementation block is a computed property.
            return true
        @unknown default:
            return true
        }
    }
}

extension CodeBlockItemListSyntax {
    /// The return statement or expression for a code block consisting of only a single item.
    fileprivate var onlyReturnExpr: ExprSyntax? {
        guard let item = self.only?.item else {
            return nil
        }
        return item.as(ReturnStmtSyntax.self)?.expression ?? item.as(ExprSyntax.self)
    }
}

fileprivate struct UnexpectedExpr: Error {
    let expr: ExprSyntax
}

extension MemberAccessExprSyntax {
    /// Parse a member access consisting only of property references. Any other syntax throws an error.
    fileprivate func propertyChain() throws -> [DeclReferenceExprSyntax] {
        // MemberAccess is left associative: a.b.c is ((a.b).c).
        var propertyChain: [DeclReferenceExprSyntax] = []
        var current = self
        while let base = current.base {
            propertyChain.append(current.declName)
            if let declRef = base.as(DeclReferenceExprSyntax.self) {
                propertyChain.append(declRef)
                // Terminal case.
                break
            }
            if let next = base.as(MemberAccessExprSyntax.self) {
                current = next
                // Recursive case.
                continue
            }
            // The expression was neither a DeclReference nor a MemberAccess.
            throw UnexpectedExpr(expr: base)
        }

        guard current.base != nil else {
            throw UnexpectedExpr(expr: ExprSyntax(current))
        }

       // Top-down traversal produces references in reverse order.
        propertyChain.reverse()
        return propertyChain
    }
}

extension String {
    /// Convert a StringLiteralExprSyntax to a String.
    fileprivate init?(expr: ExprSyntax) {
        guard let string = expr.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
            return nil
        }
        self = string
    }
}

extension Array where Element == String {
    /// Convert an ArrayExprSyntax consisting of StringLiteralExprSyntax to an Array<String>.
    fileprivate init?(expr: ExprSyntax) {
        guard let elements = expr.as(ArrayExprSyntax.self)?.elements else {
            return nil
        }
        self = elements.compactMap { String(expr: $0.expression) }
    }
}

// MARK: - Generic Extensions

extension Collection {
    /// Convert a single element collection to a single value. When a collection consists of
    /// multiple elements, nil is returned.
    fileprivate var only: Element? {
        count == 1 ? first : nil
    }
}
