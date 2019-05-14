//===-------- AutoDiff.cpp - Routines for USR generation ------------------===//
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

#include "swift/AST/AutoDiff.h"
#include "swift/AST/Module.h"
#include "swift/AST/Types.h"
#include "swift/SIL/SILLinkage.h"
#include "swift/Basic/LLVM.h"
#include "swift/Basic/Range.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"

using namespace swift;

bool SILAutoDiffIndices::operator==(const SILAutoDiffIndices &other) const {
  return source == other.source && parameters == other.parameters;
}

AutoDiffAssociatedFunctionKind::
AutoDiffAssociatedFunctionKind(StringRef string) {
  Optional<innerty> result =
      llvm::StringSwitch<Optional<innerty>>(string)
         .Case("jvp", JVP).Case("vjp", VJP);
  assert(result && "Invalid string");
  rawValue = *result;
}

unsigned autodiff::getOffsetForAutoDiffAssociatedFunction(
    unsigned order, AutoDiffAssociatedFunctionKind kind) {
  return (order - 1) * getNumAutoDiffAssociatedFunctions(order) + kind.rawValue;
}

unsigned
autodiff::getNumAutoDiffAssociatedFunctions(unsigned differentiationOrder) {
  return differentiationOrder * 2;
}

bool autodiff::getBuiltinAutoDiffApplyConfig(
    StringRef operationName, AutoDiffAssociatedFunctionKind &kind,
    unsigned &arity, unsigned &order, bool &rethrows) {
  // SWIFT_ENABLE_TENSORFLOW
  if (!operationName.startswith("autodiffApply_"))
    return false;
  operationName = operationName.drop_front(strlen("autodiffApply_"));
  // Parse 'jvp' or 'vjp'.
  if (operationName.startswith("jvp"))
    kind = AutoDiffAssociatedFunctionKind::JVP;
  else if (operationName.startswith("vjp"))
    kind = AutoDiffAssociatedFunctionKind::VJP;
  operationName = operationName.drop_front(3);
  // Parse '_arity'.
  if (operationName.startswith("_arity")) {
    operationName = operationName.drop_front(strlen("_arity"));
    auto arityStr = operationName.take_while(llvm::isDigit);
    operationName = operationName.drop_front(arityStr.size());
    auto converted = llvm::to_integer(arityStr, arity);
    assert(converted); (void)converted;
    assert(arity > 0);
  } else {
    arity = 1;
  }
  // Parse '_order'.
  if (operationName.startswith("_order")) {
    operationName = operationName.drop_front(strlen("_order"));
    auto orderStr = operationName.take_while(llvm::isDigit);
    auto converted = llvm::to_integer(orderStr, order);
    operationName = operationName.drop_front(orderStr.size());
    assert(converted); (void)converted;
    assert(order > 0);
  } else {
    order = 1;
  }
  // Parse '_rethrows'.
  if (operationName.startswith("_rethrows")) {
    operationName = operationName.drop_front(strlen("_rethrows"));
    rethrows = true;
  } else {
    rethrows = false;
  }
  return operationName.empty();
}

SILLinkage autodiff::getAutoDiffFunctionLinkage(SILLinkage originalLinkage,
                                                bool isExported) {
  // If the original is defined externally, then the AD pass is just generating
  // associated functions for use in the current module and therefore these
  // associated functions should not be visible outside the module.
  if (isAvailableExternally(originalLinkage))
    return SILLinkage::Hidden;

  // If the original is public, then external modules may need to link the
  // associated function. Make the associated function public unless
  // differentiation is not explicitly requested.
  if (originalLinkage == SILLinkage::Public ||
      originalLinkage == SILLinkage::PublicNonABI ||
      originalLinkage == SILLinkage::Shared)
    return isExported ? originalLinkage : SILLinkage::Hidden;

  // Otherwise, the original function is defined and used only in the current
  // module, so external modules will never try to access the associated
  // function. Make the associated function hidden.
  return SILLinkage::Hidden;
}

/// Allocates and initializes an `AutoDiffParameterIndices` corresponding to
/// the given `string` generated by `getString()`. If the string is invalid,
/// returns nullptr.
AutoDiffParameterIndices *
AutoDiffParameterIndices::create(ASTContext &C, StringRef string) {
  if (string.size() < 1)
    return nullptr;

  llvm::SmallBitVector parameters(string.size());
  for (unsigned i : range(parameters.size())) {
    if (string[i] == 'S')
      parameters.set(i);
    else if (string[i] != 'U')
      return nullptr;
  }

  return get(parameters, C);
}

/// Returns a textual string description of these indices,
///
///   [SU]+
///
/// "S" means that the corresponding index is set
/// "U" means that the corresponding index is unset
std::string AutoDiffParameterIndices::getString() const {
  std::string result;
  for (unsigned i : range(parameters.size())) {
    if (parameters[i])
      result += "S";
    else
      result += "U";
  }
  return result;
}

static void unwrapCurryLevels(AnyFunctionType *fnTy,
                              SmallVectorImpl<AnyFunctionType *> &result) {
  while (fnTy != nullptr) {
    result.push_back(fnTy);
    fnTy = fnTy->getResult()->getAs<AnyFunctionType>();
  }
}

/// Pushes the subset's parameter's types to `paramTypes`, in the order in
/// which they appear in the function type. For example,
///
///   functionType = (A, B, C) -> R
///   if "A" and "C" are in the set,
///   ==> pushes {A, C} to `paramTypes`.
///
///   functionType = (A, B) -> (C, D) -> R
///   if "A", "C", and "D" are in the set,
///   ==> pushes {A, C, D} to `paramTypes`.
///
///   functionType = (Self) -> (A, B, C) -> R
///   if "Self" and "C" are in the set,
///   ==> pushes {Self, C} to `paramTypes`.
///
void AutoDiffParameterIndices::getSubsetParameterTypes(
    AnyFunctionType *functionType, SmallVectorImpl<Type> &paramTypes) const {
  SmallVector<AnyFunctionType *, 2> curryLevels;
  unwrapCurryLevels(functionType, curryLevels);

  SmallVector<unsigned, 2> curryLevelParameterIndexOffsets(curryLevels.size());
  unsigned currentOffset = 0;
  for (unsigned curryLevelIndex : reversed(indices(curryLevels))) {
    curryLevelParameterIndexOffsets[curryLevelIndex] = currentOffset;
    currentOffset += curryLevels[curryLevelIndex]->getNumParams();
  }

  for (unsigned curryLevelIndex : indices(curryLevels)) {
    auto *curryLevel = curryLevels[curryLevelIndex];
    unsigned parameterIndexOffset =
        curryLevelParameterIndexOffsets[curryLevelIndex];
    for (unsigned paramIndex : range(curryLevel->getNumParams()))
      if (parameters[parameterIndexOffset + paramIndex])
        paramTypes.push_back(
            curryLevel->getParams()[paramIndex].getPlainType());
  }
}

static unsigned countNumFlattenedElementTypes(Type type) {
  if (auto *tupleTy = type->getCanonicalType()->getAs<TupleType>())
    return accumulate(tupleTy->getElementTypes(), 0,
                      [&](unsigned num, Type type) {
                        return num + countNumFlattenedElementTypes(type);
                      });
  return 1;
}

/// Returns a bitvector for the SILFunction parameters corresponding to the
/// parameters in this set. In particular, this explodes tuples. For example,
///
///   functionType = (A, B, C) -> R
///   if "A" and "C" are in the set,
///   ==> returns 101
///   (because the lowered SIL type is (A, B, C) -> R)
///
///   functionType = (Self) -> (A, B, C) -> R
///   if "Self" and "C" are in the set,
///   ==> returns 0011
///   (because the lowered SIL type is (A, B, C, Self) -> R)
///
///   functionType = (A, (B, C), D) -> R
///   if "A" and "(B, C)" are in the set,
///   ==> returns 1110
///   (because the lowered SIL type is (A, B, C, D) -> R)
///
AutoDiffIndexSubset *
AutoDiffParameterIndices::getLowered(ASTContext &ctx,
                                     AnyFunctionType *functionType) const {
  SmallVector<AnyFunctionType *, 2> curryLevels;
  unwrapCurryLevels(functionType, curryLevels);

  // Calculate the lowered sizes of all the parameters.
  SmallVector<unsigned, 8> paramLoweredSizes;
  unsigned totalLoweredSize = 0;
  auto addLoweredParamInfo = [&](Type type) {
    unsigned paramLoweredSize = countNumFlattenedElementTypes(type);
    paramLoweredSizes.push_back(paramLoweredSize);
    totalLoweredSize += paramLoweredSize;
  };
  for (auto *curryLevel : reversed(curryLevels))
    for (auto &param : curryLevel->getParams())
      addLoweredParamInfo(param.getPlainType());

  // Construct the result by setting each range of bits that corresponds to each
  // "on" parameter.
  llvm::SmallVector<unsigned, 8> loweredIndices;
  unsigned currentBitIndex = 0;
  for (unsigned i : range(parameters.size())) {
    auto paramLoweredSize = paramLoweredSizes[i];
    if (parameters[i]) {
      auto indices = range(currentBitIndex, currentBitIndex + paramLoweredSize);
      loweredIndices.append(indices.begin(), indices.end());
    }
    currentBitIndex += paramLoweredSize;
  }

  return AutoDiffIndexSubset::get(ctx, totalLoweredSize, loweredIndices);
}

static unsigned getNumAutoDiffParameterIndices(AnyFunctionType *fnTy) {
  // TODO: For more correct counting, we still need to know whether it's a
  // method or not.
  unsigned numParameters = fnTy->getNumParams();
  if (auto *innerFn = fnTy->getResult()->getAs<AnyFunctionType>())
    numParameters += innerFn->getNumParams();
  return numParameters;
}

/// Returns true if the given type conforms to `Differentiable` in the given
/// module.
static bool conformsToDifferentiableInModule(Type type, ModuleDecl *module) {
  auto &ctx = module->getASTContext();
  auto *differentiableProto =
      ctx.getProtocol(KnownProtocolKind::Differentiable);
  return LookUpConformanceInModule(module)(
      differentiableProto->getDeclaredInterfaceType()->getCanonicalType(),
      type, differentiableProto).hasValue();
};

AutoDiffParameterIndicesBuilder::AutoDiffParameterIndicesBuilder(
    AnyFunctionType *functionType)
    : parameters(getNumAutoDiffParameterIndices(functionType)) {}

AutoDiffParameterIndicesBuilder
AutoDiffParameterIndicesBuilder::inferParameters(AnyFunctionType *functionType,
                                                 ModuleDecl *module) {
  AutoDiffParameterIndicesBuilder builder(functionType);
  SmallVector<Type, 4> allParamTypes;

  // Returns true if the i-th parameter type is differentiable.
  auto isDifferentiableParam = [&](unsigned i) -> bool {
    if (i >= allParamTypes.size())
      return false;
    auto paramType = allParamTypes[i];
    // Return false for class/existential types.
    if ((!paramType->hasTypeParameter() &&
         paramType->isAnyClassReferenceType()) ||
        paramType->isExistentialType())
      return false;
    // Return false for function types.
    if (paramType->is<AnyFunctionType>())
      return false;
    // Return true if the type conforms to `Differentiable`.
    return conformsToDifferentiableInModule(paramType, module);
  };

  // Get all parameter types.
  // NOTE: To be robust, result function type parameters should be added only if
  // `functionType` comes from a static/instance method, and not a free function
  // returning a function type. In practice, this code path should not be
  // reachable for free functions returning a function type.
  if (auto resultFnType = functionType->getResult()->getAs<AnyFunctionType>())
    for (auto &param : resultFnType->getParams())
      allParamTypes.push_back(param.getPlainType());
  for (auto &param : functionType->getParams())
    allParamTypes.push_back(param.getPlainType());

  // Set differentiation parameters.
  for (unsigned i : range(builder.parameters.size()))
    if (isDifferentiableParam(i))
      builder.setParameter(i);

  return builder;
}

AutoDiffParameterIndices *
AutoDiffParameterIndicesBuilder::build(ASTContext &C) const {
  return AutoDiffParameterIndices::get(parameters, C);
}

void AutoDiffParameterIndicesBuilder::setParameter(unsigned paramIndex) {
  assert(paramIndex < parameters.size() && "paramIndex out of bounds");
  parameters.set(paramIndex);
}

void AutoDiffParameterIndicesBuilder::setParameters(unsigned lowerBound,
                                                    unsigned upperBound) {
  parameters.set(lowerBound, upperBound);
}

Type VectorSpace::getType() const {
  switch (kind) {
  case Kind::Vector:
    return value.vectorType;
  case Kind::Tuple:
    return value.tupleType;
  case Kind::Function:
    return value.functionType;
  }
}

CanType VectorSpace::getCanonicalType() const {
  return getType()->getCanonicalType();
}

NominalTypeDecl *VectorSpace::getNominal() const {
  return getVector()->getNominalOrBoundGenericNominal();
}

bool AutoDiffIndexSubset::isSubsetOf(AutoDiffIndexSubset *other) const {
  assert(capacity == other->capacity);
  for (auto index : range(numBitWords))
    if (getBitWord(index) & ~other->getBitWord(index))
      return false;
  return true;
}

bool AutoDiffIndexSubset::isSupersetOf(AutoDiffIndexSubset *other) const {
  assert(capacity == other->capacity);
  for (auto index : range(numBitWords))
    if (~getBitWord(index) & other->getBitWord(index))
      return false;
  return true;
}

AutoDiffIndexSubset *AutoDiffIndexSubset::adding(unsigned index,
                                                 ASTContext &ctx) const {
  assert(index < getCapacity());
  if (contains(index))
    return const_cast<AutoDiffIndexSubset *>(this);
  SmallVector<unsigned, 8> newIndices;
  newIndices.reserve(capacity + 1);
  bool inserted = false;
  for (auto curIndex : getIndices()) {
    if (!inserted && curIndex > index) {
      newIndices.push_back(index);
      inserted = true;
    }
    newIndices.push_back(curIndex);
  }
  return get(ctx, capacity, newIndices);
}

AutoDiffIndexSubset *AutoDiffIndexSubset::extendingCapacity(
    ASTContext &ctx, unsigned newCapacity) const {
  assert(newCapacity >= capacity);
  if (newCapacity == capacity)
    return const_cast<AutoDiffIndexSubset *>(this);
  SmallVector<unsigned, 8> indices;
  for (auto index : getIndices())
    indices.push_back(index);
  return AutoDiffIndexSubset::get(ctx, newCapacity, indices);
}

int AutoDiffIndexSubset::findNext(int startIndex) const {
  assert(startIndex < (int)capacity && "Start index cannot be past the end");
  unsigned bitWordIndex = 0, offset = 0;
  if (startIndex >= 0) {
    auto indexAndOffset = getBitWordIndexAndOffset(startIndex);
    bitWordIndex = indexAndOffset.first;
    offset = indexAndOffset.second + 1;
  }
  for (; bitWordIndex < numBitWords; ++bitWordIndex, offset = 0) {
    for (; offset < numBitsPerBitWord; ++offset) {
      auto index = bitWordIndex * numBitsPerBitWord + offset;
      auto bitWord = getBitWord(bitWordIndex);
      if (!bitWord)
        break;
      if (index >= capacity)
        return capacity;
      if (bitWord & ((BitWord)1 << offset))
        return index;
    }
  }
  return capacity;
}

int AutoDiffIndexSubset::findPrevious(int endIndex) const {
  assert(endIndex >= 0 && "End index cannot be before the start");
  int bitWordIndex = numBitWords - 1, offset = numBitsPerBitWord - 1;
  if (endIndex < (int)capacity) {
    auto indexAndOffset = getBitWordIndexAndOffset(endIndex);
    bitWordIndex = (int)indexAndOffset.first;
    offset = (int)indexAndOffset.second - 1;
  }
  for (; bitWordIndex >= 0; --bitWordIndex, offset = numBitsPerBitWord - 1) {
    for (; offset < (int)numBitsPerBitWord; --offset) {
      auto index = bitWordIndex * (int)numBitsPerBitWord + offset;
      auto bitWord = getBitWord(bitWordIndex);
      if (!bitWord)
        break;
      if (index < 0)
        return -1;
      if (bitWord & ((BitWord)1 << offset))
        return index;
    }
  }
  return -1;
}
