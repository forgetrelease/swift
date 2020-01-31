//===- SwiftAbstractBasicWriter.h - Clang serialization adapter -*- C++ -*-===//
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
// This file provides an intermediate CRTP class which implements most of
// Clang's AbstractBasicWriter interface, allowing largely the same logic
// to be used for both the importer's "can this be serialized" checks and
// the serializer's actual serialization logic.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_CLANGIMPORTER_SWIFTABSTRACTBASICWRITER_H
#define SWIFT_CLANGIMPORTER_SWIFTABSTRACTBASICWRITER_H

#include "clang/AST/AbstractTypeWriter.h"

namespace swift {

/// The subclass must implement:
///   void writeUInt64(uint64_t value);
///   void writeIdentifier(const clang::IdentifierInfo *ident);
///   void writeStmtRef(const clang::Stmt *stmt);
///   void writeDeclRef(const clang::Decl *decl);
template <class Impl>
class DataStreamBasicWriter
       : public clang::serialization::DataStreamBasicWriter<Impl> {
  using super = clang::serialization::DataStreamBasicWriter<Impl>;
public:
  using super::asImpl;

  /// Perform all the calls necessary to write out the given type.
  void writeTypeRef(const clang::Type *type) {
    asImpl().writeUInt64(uint64_t(type->getTypeClass()));
    clang::serialization::AbstractTypeWriter<Impl>(asImpl()).write(type);
  }

  void writeBool(bool value) {
    asImpl().writeUInt64(uint64_t(value));
  }

  void writeUInt32(uint32_t value) {
    asImpl().writeUInt64(uint64_t(value));
  }

  void writeSelector(clang::Selector selector) {
    if (selector.isNull()) {
      asImpl().writeUInt64(0);
      return;
    }

    asImpl().writeUInt64(selector.getNumArgs() + 1);
    for (unsigned i = 0, e = std::max(selector.getNumArgs(), 1U); i != e; ++i)
      asImpl().writeIdentifier(selector.getIdentifierInfoForSlot(i));
  }

  void writeSourceLocation(clang::SourceLocation loc) {
    // Always read null
  }

  void writeQualType(clang::QualType type) {
    assert(!type.isNull());

    auto split = type.split();
    asImpl().writeQualifiers(split.Quals);

    // Just recursively visit the given type.
    asImpl().writeTypeRef(split.Ty);
  }
};

}

#endif
