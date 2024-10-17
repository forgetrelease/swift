//===--- Generics.swift ---------------------------------------------------===//
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

import ASTBridging

@_spi(ExperimentalLanguageFeatures)
import SwiftSyntax

extension ASTGenVisitor {
  func generate(genericParameterClause node: GenericParameterClauseSyntax) -> BridgedGenericParamList {
    .createParsed(
      self.ctx,
      leftAngleLoc: self.generateSourceLoc(node.leftAngle),
      parameters: node.parameters.lazy.map(self.generate).bridgedArray(in: self),
      genericWhereClause: self.generate(genericWhereClause: node.genericWhereClause),
      rightAngleLoc: self.generateSourceLoc(node.rightAngle)
    )
  }

  func generate(genericParameter node: GenericParameterSyntax) -> BridgedGenericTypeParamDecl {
    let (name, nameLoc) = self.generateIdentifierAndSourceLoc(node.name)

    var genericParameterIndex: Int?
    for (index, sibling) in (node.parent?.as(GenericParameterListSyntax.self) ?? []).enumerated() {
      if sibling == node {
        genericParameterIndex = index
        break
      }
    }
    guard let genericParameterIndex = genericParameterIndex else {
      preconditionFailure("Node not part of the parent?")
    }

    var paramKind: BridgedGenericTypeParamKind = .type

    if node.specifier?.tokenKind == .keyword(.each) {
      paramKind = .pack
    } else if node.specifier?.tokenKind == .keyword(.let) {
      paramKind = .value
    }

    return .createParsed(
      self.ctx,
      declContext: self.declContext,
      specifierLoc: self.generateSourceLoc(node.specifier),
      name: name,
      nameLoc: nameLoc,
      inheritedType: self.generate(type: node.inheritedType),
      index: genericParameterIndex,
      paramKind: paramKind
    )
  }

  func generate(genericWhereClause node: GenericWhereClauseSyntax) -> BridgedTrailingWhereClause {
    let requirements = node.requirements.lazy.map {
      switch $0.requirement {
      case .conformanceRequirement(let conformance):
        return BridgedRequirementRepr(
          SeparatorLoc: self.generateSourceLoc(conformance.colon),
          Kind: .typeConstraint,
          FirstType: self.generate(type: conformance.leftType),
          SecondType: self.generate(type: conformance.rightType)
        )
      case .sameTypeRequirement(let sameType):
        return BridgedRequirementRepr(
          SeparatorLoc: self.generateSourceLoc(sameType.equal),
          Kind: .sameType,
          FirstType: self.generate(sameTypeLeftType: sameType.leftType),
          SecondType: self.generate(sameTypeRightType: sameType.rightType)
        )
      case .layoutRequirement(_):
        // FIXME: Implement layout requirement translation.
        fatalError("Translation of layout requirements not implemented!")
      }
    }

    return BridgedTrailingWhereClause.createParsed(
      self.ctx,
      whereKeywordLoc: self.generateSourceLoc(node.whereKeyword),
      requirements: requirements.bridgedArray(in: self)
    )
  }

  func generate(sameTypeLeftType node: SameTypeRequirementSyntax.LeftType) -> BridgedTypeRepr {
    switch node {
    case .type(let type):
      return self.generate(type: type)

    // The only expressions same type left types support right now are
    // integer literals, '123', and prefix operators for negative integer
    // literals, '-123'.
    case .expr(let expr):
      switch expr.as(ExprSyntaxEnum.self) {
      case .integerLiteralExpr(let node):
        return self.generate(integerType: node)

      case .prefixOperatorExpr(let node):
        let op = node.operator

        guard op.text == "-" else {
          fatalError("Unknown prefix operator for same type left type")
        }

        guard case .integerLiteralExpr(let node) = node.expression.as(ExprSyntaxEnum.self) else {
          fatalError("Unknown expression kind for same type left type")
        }

        return self.generate(integerType: node, minusLoc: self.generateSourceLoc(op))

      default:
        fatalError("Unknown expression kind for same type left type")
      }
    }
  }

  func generate(sameTypeRightType node: SameTypeRequirementSyntax.RightType) -> BridgedTypeRepr {
    switch node {
    case .type(let type):
      return self.generate(type: type)

    // The only expressions same type right types support right now are
    // integer literals, '123', and prefix operators for negative integer
    // literals, '-123'.
    case .expr(let expr):
      switch expr.as(ExprSyntaxEnum.self) {
      case .integerLiteralExpr(let node):
        return self.generate(integerType: node)

      case .prefixOperatorExpr(let node):
        let op = node.operator

        guard op.text == "-" else {
          fatalError("Unknown prefix operator for same type right type")
        }

        guard case .integerLiteralExpr(let node) = node.expression.as(ExprSyntaxEnum.self) else {
          fatalError("Unknown expression kind for same type right type")
        }

        return self.generate(integerType: node, minusLoc: self.generateSourceLoc(op))

      default:
        fatalError("Unknown expression kind for same type right type")
      }
    }
  }

  func generate(genericArgument node: GenericArgumentSyntax.Argument) -> BridgedTypeRepr {
    switch node {
    case .type(let type):
      return self.generate(type: type)

    // The only expressions generic argument types support right now are
    // integer literals, '123', and prefix operators for negative integer
    // literals, '-123'.
    case .expr(let expr):
      switch expr.as(ExprSyntaxEnum.self) {
      case .integerLiteralExpr(let node):
        return self.generate(integerType: node)

      case .prefixOperatorExpr(let node):
        let op = node.operator

        guard op.text == "-" else {
          fatalError("Unknown prefix operator for generic argument type")
        }

        guard case .integerLiteralExpr(let node) = node.expression.as(ExprSyntaxEnum.self) else {
          fatalError("Unknown expression kind for generic argument type")
        }

        return self.generate(integerType: node, minusLoc: self.generateSourceLoc(op))

      default:
        fatalError("Unknown expression kind for generic argument type")
      }
    }
  }

  func generate(
    integerType node: IntegerLiteralExprSyntax,
    minusLoc: BridgedSourceLoc = BridgedSourceLoc()
  ) -> BridgedTypeRepr {
    var desc = node.trimmedDescription
    let str = desc.withBridgedString {
      self.ctx.allocateCopy(string: $0)
    }

    return BridgedIntegerTypeRepr.createParsed(
      self.ctx,
      string: str,
      loc: self.generateSourceLoc(node),
      minusLoc: minusLoc
    ).asTypeRepr
  }
}
