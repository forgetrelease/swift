//===--- GraphOperationInfo.h - GraphOperationInst Parse Logic --*- C++ -*-===//
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
// This file defines the parsing logic for a GraphOperationInst, in particular
// decoding the mangled inst name string for the operands and attributes.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_SIL_GRAPH_OPERATION_INFO_H
#define SWIFT_SIL_GRAPH_OPERATION_INFO_H

#include "swift/AST/Identifier.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"

namespace swift {
class GraphOperationInst;

namespace tf {
/// Holds information about a TensorFlow operation as represented in SIL
/// as GraphOperationInst.
struct GraphOperationInfo {
  /// One of these records exists for every operand that the BuiltinInst has,
  /// classifying the operand into a couple of buckets.  The most coarse grain
  /// classification is "input" vs "attribute": the inputs come first,
  /// followed by the attributes.  However, we need to be able to model the
  /// fact that some input arguments are aggregated together into a single
  /// input that is an array of tensors.  An integer attribute may be either
  /// a Tensor value or an integer-encoded DType, etc.
  enum class OperandClass {
    /// Indicates one of the following:
    /// 1) A normal tensor input: the value is a TensorHandle.
    /// 2) An normal attribute (without modifier).
    /// 3) A tensor or shape attribute (need a modifier for proper lowering).
    /// 4) An array attribute (needed for parsing tfop, and dropped before graph
    ///    lowering).
    Input,

    /// No modifier.
    Normal,

    /// Indicates that the array or scalar should be turned into a TF_Tensor.
    Tensor,

    /// Indicates that the array of integers should be interpreted as a shape.
    Shape,

    /// Indicates the metatype of a TensorFlow value type or an aggregate of
    /// TensorFlow value types should be turned into a list of unknown shapes.
    UnknownShapeList,

    /// Indicates that the operand should be interpreted as an array. When
    /// applied to the metatype of a TensorFlow value type or an aggregate of
    /// TensorFlow value types, it will be flattened into an array of dtypes of
    /// each TensorFlow value type as a Normal operand.
    Array,

    /// An operand specifying the address where an indirect output should be
    /// stored.  This occurs when the tfop exists in a context where its output
    /// is address-only.  Deabstraction eliminates Out operands before forming
    /// graph_ops, by rewriting the tfop to return the value directly.  This
    /// rewriting is possible because tfop outputs must always be loadable in
    /// deabstraction scopes.
    Out,
  };

  /// Return the string suffix for the specified attribute modifier.
  static const char *
  getOperandClassSuffix(GraphOperationInfo::OperandClass opClass);

  /// Return the operand class of the specified string form like "tensor"
  static llvm::Optional<GraphOperationInfo::OperandClass>
  getOperandClass(StringRef suffix);

  /// The instruction being analyzed.
  GraphOperationInst *inst;

  explicit GraphOperationInfo(GraphOperationInst *inst) : inst(inst) {}

  /// Return the device attribute associated with `inst`, which is required to
  /// exist.
  // StringRef getDeviceString() const;

  // /// Return the device type for this instruction.
  // DeviceType getDeviceType() const {
  //   return getOpDeviceType(getDeviceString());
  // }

  enum InputMarker {
    /// Scalar input, used by tfc.scalarToTensor only.
    IM_Scalar,
    /// Normal tensor, variant or resource input.
    IM_Normal,
    /// Marker for the start of an input list, has no corresponding operand.
    IM_InputList,
    /// Element of an input list.
    IM_InputListElt,
  };

  /// Return a comma and letter identifier whose letter corresponds to the
  /// specified InputMarker.
  static const char *getInputMarker(InputMarker kind) {
    switch (kind) {
    case IM_Scalar:
      return ",s";
    case IM_Normal:
      return ",i";
    case IM_InputList:
      return ",L";
    case IM_InputListElt:
      return ",e";
    }
  }

  /// Decode the name of a graph_op into its TensorFlow op name and a list of
  /// information about the operands.
  llvm::StringRef decodeName(llvm::SmallVectorImpl<InputMarker> &inputInfo);

  /// Given an attribute name like foo$tensor, decode the name and the class.
  /// If there is no modifier specified, this defaults to
  /// OperandClass::Normal.
  static std::pair<llvm::StringRef, OperandClass>
  decodeAttributeName(Identifier name);

  /// Get an int-typed attribute at `attrIdx`, which must have `attrName`.
  int64_t getIntAttr(unsigned attrIdx, llvm::StringRef attrName) const;

  /// Get a string-typed attribute at `attrIdx`, which must have `attrName`.
  std::string getStringAttr(unsigned attrIdx, llvm::StringRef attrName) const;
  // /// Get a float-typed attribute at `attrIdx`, which must have `attrName`.
  // float getFloatAttr(unsigned attrIdx, llvm::StringRef attrName) const;

  void assertWithDump(bool cond, const char *assertMsg) const;
};
} // end namespace tf
} // end namespace swift
#endif // SWIFT_SIL_GRAPH_OPERATION_INFO_H
