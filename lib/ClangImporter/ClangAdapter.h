//===--- ClangAdapter.h - Interfaces with Clang entities --------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file provides convenient and canonical interfaces with Clang entities,
// serving as both a useful place to put utility functions and a canonical
// interface that can abstract nitty gritty Clang internal details.
//
//===----------------------------------------------------------------------===//
#ifndef CLANG_ADAPTER_H
#define CLANG_ADAPTER_H

#include "swift/Basic/StringExtras.h"
#include "swift/Serialization/ModuleFormat.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/SmallBitVector.h"
#include "clang/Basic/Specifiers.h"

#include "ImportName.h"

namespace clang {
class ASTContext;
class Decl;
class DeclContext;
class MacroInfo;
class Module;
class NamedDecl;
class ObjCInterfaceDecl;
class ObjCMethodDecl;
class ObjCPropertyDecl;
class ParmVarDecl;
class QualType;
class Sema;
class SwiftNewtypeAttr;
class Type;
class TypedefNameDecl;
}

// TODO: pull more off of the ImportImpl

namespace swift {
namespace importer {
struct PlatformAvailability;

/// Returns the redeclaration of \p D that contains its definition for any
/// tag type decl (struct, enum, or union) or Objective-C class or protocol.
///
/// Returns \c None if \p D is not a redeclarable type declaration.
/// Returns null if \p D is a redeclarable type, but it does not have a
/// definition yet.
Optional<const clang::Decl *>
getDefinitionForClangTypeDecl(const clang::Decl *D);

/// Returns the module \p D comes from, or \c None if \p D does not have
/// a valid associated module.
///
/// The returned module may be null (but not \c None) if \p D comes from
/// an imported header.
Optional<clang::Module *>
getClangSubmoduleForDecl(const clang::Decl *D,
                         bool allowForwardDeclaration = false);

/// Retrieve the type of an instance of the given Clang declaration context,
/// or a null type if the DeclContext does not have a corresponding type.
clang::QualType getClangDeclContextType(const clang::DeclContext *dc);

/// Retrieve the type name of a Clang type for the purposes of
/// omitting unneeded words.
OmissionTypeName getClangTypeNameForOmission(clang::ASTContext &ctx,
                                             clang::QualType type);

/// Find the swift_newtype attribute on the given typedef, if present.
clang::SwiftNewtypeAttr *getSwiftNewtypeAttr(const clang::TypedefNameDecl *decl,
                                             ImportNameVersion version);

/// Retrieve a bit vector containing the non-null argument
/// annotations for the given declaration.
llvm::SmallBitVector
getNonNullArgs(const clang::Decl *decl,
               ArrayRef<const clang::ParmVarDecl *> params);

/// Whether the given decl is a global Notification
bool isNSNotificationGlobal(const clang::NamedDecl *);

// If this decl is associated with a swift_newtype (and we're honoring
// swift_newtype), return it, otherwise null
clang::TypedefNameDecl *findSwiftNewtype(const clang::NamedDecl *decl,
                                         clang::Sema &clangSema,
                                         ImportNameVersion version);

/// Whether the passed type is NSString *
bool isNSString(const clang::Type *);
bool isNSString(clang::QualType);

/// Whether the given declaration was exported from Swift.
///
/// Note that this only checks the immediate declaration being passed.
/// For things like methods and properties that are nested in larger types,
/// it's the top-level declaration that should be checked.
bool hasNativeSwiftDecl(const clang::Decl *decl);

/// Translation API nullability from an API note into an optional kind.
OptionalTypeKind translateNullability(clang::NullabilityKind kind);

/// Determine whether the given class has designated initializers,
/// consulting
bool hasDesignatedInitializers(const clang::ObjCInterfaceDecl *classDecl);

/// Determine whether the given method is a designated initializer
/// of the given class.
bool isDesignatedInitializer(const clang::ObjCInterfaceDecl *classDecl,
                             const clang::ObjCMethodDecl *method);

/// Determine whether the given method is a required initializer
/// of the given class.
bool isRequiredInitializer(const clang::ObjCMethodDecl *method);

/// Determine whether this property should be imported as its getter and setter
/// rather than as a Swift property.
bool shouldImportPropertyAsAccessors(const clang::ObjCPropertyDecl *prop);

/// Determine whether this method is an Objective-C "init" method
/// that will be imported as a Swift initializer.
bool isInitMethod(const clang::ObjCMethodDecl *method);

/// Determine whether this is the declaration of Objective-C's 'id' type.
bool isObjCId(const clang::Decl *decl);

/// Determine whether the given declaration is considered
/// 'unavailable' in Swift.
bool isUnavailableInSwift(const clang::Decl *decl, const PlatformAvailability &,
                          bool enableObjCInterop);

/// Determine the optionality of the given Clang parameter.
///
/// \param swiftLanguageVersion What version of Swift we're using, which affects
/// how optionality is inferred.
///
/// \param param The Clang parameter.
///
/// \param knownNonNull Whether a function- or method-level "nonnull" attribute
/// applies to this parameter.
OptionalTypeKind getParamOptionality(version::Version swiftLanguageVersion,
                                     const clang::ParmVarDecl *param,
                                     bool knownNonNull);
}
}

#endif
