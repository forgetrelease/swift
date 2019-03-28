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
#include "swift/Basic/LLVM.h"
#include "swift/Basic/Range.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringSwitch.h"

using namespace swift;

SILAutoDiffIndices::SILAutoDiffIndices(
    unsigned source, ArrayRef<unsigned> parameters) : source(source) {
  if (parameters.empty())
    return;

  auto max = *std::max_element(parameters.begin(), parameters.end());
  this->parameters.resize(max + 1);
  int last = -1;
  for (auto paramIdx : parameters) {
    assert((int)paramIdx > last && "Parameter indices must be ascending");
    last = paramIdx;
    this->parameters.set(paramIdx);
  }
}

bool SILAutoDiffIndices::operator==(
    const SILAutoDiffIndices &other) const {
  if (source != other.source)
    return false;

  // The parameters are the same when they have exactly the same set bit
  // indices, even if they have different sizes.
  llvm::SmallBitVector buffer(std::max(parameters.size(),
                                       other.parameters.size()));
  buffer ^= parameters;
  buffer ^= other.parameters;
  return buffer.none();
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
llvm::SmallBitVector
AutoDiffParameterIndices::getLowered(AnyFunctionType *functionType) const {
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
  llvm::SmallBitVector result(totalLoweredSize);
  unsigned currentBitIndex = 0;
  for (unsigned i : range(parameters.size())) {
    auto paramLoweredSize = paramLoweredSizes[i];
    if (parameters[i])
      result.set(currentBitIndex, currentBitIndex + paramLoweredSize);
    currentBitIndex += paramLoweredSize;
  }

  return result;
}

static unsigned getNumAutoDiffParameterIndices(AnyFunctionType *fnTy) {
  unsigned numAutoDiffParameterIndices = 0;
  // FIXME: Compute the exact parameter count.
  // Do not loop ad-infinitum; loop either 1 or 2 iterations, depending on
  // whether the function is a free function/static method/instance method.
  while (fnTy != nullptr) {
    numAutoDiffParameterIndices += fnTy->getNumParams();
    fnTy = fnTy->getResult()->getAs<AnyFunctionType>();
  }
  return numAutoDiffParameterIndices;
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

AutoDiffIndexSubset *
AutoDiffIndexSubset::get(ASTContext &ctx, unsigned capacity, bool includeAll) {
  auto *buf = reinterpret_cast<AutoDiffIndexSubset *>(
      ctx.Allocate(sizeof(AutoDiffIndexSubset), alignof(AutoDiffIndexSubset)));
  return new (buf) AutoDiffIndexSubset(SmallBitVector(capacity, includeAll));
}

AutoDiffIndexSubset *
AutoDiffIndexSubset::get(ASTContext &ctx, const SmallBitVector &rawIndices) {
  auto *buf = reinterpret_cast<AutoDiffIndexSubset *>(
      ctx.Allocate(sizeof(AutoDiffIndexSubset), alignof(AutoDiffIndexSubset)));
  return new (buf) AutoDiffIndexSubset(std::move(rawIndices));
}

AutoDiffIndexSubset *AutoDiffIndexSubset::get(ASTContext &ctx,
                                              unsigned capacity,
                                              IntRange<> range) {
  auto *subset = get(ctx, capacity);
  subset->rawIndices.set(range.front(), range.back());
  return subset;
}

AutoDiffIndexSubset *AutoDiffIndexSubset::get(ASTContext &ctx,
                                              unsigned capacity,
                                              ArrayRef<unsigned> indices) {
  auto *subset = get(ctx, capacity);
  for (auto i : indices) {
    assert(i < capacity && "Index must be smaller than capacity");
    subset->rawIndices.set(i);
  }
  return subset;
}

bool AutoDiffIndexSubset::equals(const AutoDiffIndexSubset *other) const {
  return rawIndices == other->rawIndices;
}

bool AutoDiffIndexSubset::
isProperSubsetOf(const AutoDiffIndexSubset *other) const {
  return getSize() == other->getSize() && other->rawIndices.test(rawIndices);
}

bool AutoDiffIndexSubset::
isProperSupersetOf(const AutoDiffIndexSubset *other) const {
  return getSize() == other->getSize() && rawIndices.test(other->rawIndices);
}

AutoDiffIndexSubset *
AutoDiffIndexSubset::adding(unsigned index, ASTContext &ctx) const {
  assert(index < getCapacity());

}

AutoDiffIndexSubset *
AutoDiffIndexSubset::adding(AutoDiffIndexSubset *other, ASTContext &ctx) const {
  return get(ctx, rawIndices | other->rawIndices);
}

void AutoDiffIndexSubset::Profile(llvm::FoldingSetNodeID &id,
                                  const SmallBitVector &rawIndices) {
  id.AddInteger(rawIndices.size());
  for (auto i : rawIndices.set_bits())
    id.AddInteger(i);
}

AutoDiffFunctionParameterSubset::
AutoDiffFunctionParameterSubset(ASTContext &ctx,
                                AutoDiffIndexSubset *parameterSubset,
                                Optional<bool> isSelfIncluded) {
  if (isSelfIncluded.hasValue()) {
    indexSubset =
        AutoDiffIndexSubset::get(ctx, parameterSubset->getCapacity() + 1);
  }
}
