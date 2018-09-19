//=== GraphOperationBuilder.cpp - GraphOperationInst Build Logic *- C++ -*-===//
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
// This file defines the construction logic for a GraphOperationInst, in
// particular encoding the mangled inst name string for the operands and
// attributes.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_SIL_GRAPH_OPERATION_BUILDER_H
#define SWIFT_SIL_GRAPH_OPERATION_BUILDER_H

#include "swift/SIL/SILConstants.h"
#include "swift/SIL/SILValue.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"

namespace swift {
class ASTContext;
class GraphOperationInst;
class SILBuilder;
class SILLocation;
class SILType;

namespace tf {

class GraphOperationBuilder {
  std::string MangledName;
  llvm::SmallVector<SILValue, 4> Operands;
  llvm::SmallVector<GraphOperationAttribute, 4> Attributes;

public:
  /// Start building a GraphOperationInst for op `OpName`.
  GraphOperationBuilder(llvm::StringRef OpName);

  /// Add a single operand to the GraphOperationInst, with an optional name.
  void addOperand(SILValue operand, llvm::StringRef name = llvm::StringRef());

  /// Add a list operand to the GraphOperationInst, with an optional name.
  void addListOperand(llvm::ArrayRef<SILValue> operands,
                      llvm::StringRef name = llvm::StringRef());

  /// Add an attribute with known constant value to the GraphOperationInst.
  /// Returns a reference to the attribute, valid for the lifetime of the
  /// GraphOperationBuilder, that you can use to mutate the attribute before
  /// buiding the GraphOperationInst.
  GraphOperationAttribute &addAttribute(
      const GraphOperationAttribute &attribute);

  /// Special method that should only be used for "tfc.scalarToTensor"'s operand,
  /// because it has special name mangling. (Marker is "s").
  void addScalarOperand(SILValue operand);

  /// Special method that should only be used for "tf_tensor_to_i1"'s operand,
  /// because it has special name mangling. (No marker for its operand).
  /// TODO: Make "tf_tensor_to_i1" support normal name mangling, and then remove
  /// this.
  void addTFTensorToI1Operand(SILValue operand);

  /// Build the GraphOperationInst.
  GraphOperationInst* build(
      SILBuilder &B, ASTContext &C, SILLocation loc,
      llvm::ArrayRef<SILType> resultSILTypes) const;
};

} // end namespace tf
} // end namespace swift

#endif // SWIFT_SIL_GRAPH_OPERATION_BUILDER_H
