//===--- GenericSignature.h - Generic Signature AST -------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file defines the GenericSignature class and its related classes.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_AST_GENERIC_SIGNATURE_H
#define SWIFT_AST_GENERIC_SIGNATURE_H

#include "swift/AST/Requirement.h"
#include "swift/AST/Substitution.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/FoldingSet.h"
#include "llvm/Support/TrailingObjects.h"

namespace swift {

class ArchetypeBuilder;
class ProtocolConformanceRef;
class ProtocolType;
class Substitution;
class SubstitutionMap;

/// Iterator that walks the generic parameter types declared in a generic
/// signature and their dependent members.
class GenericSignatureWitnessIterator {
  ArrayRef<Requirement> p;

  void checkValid() const {
    assert(!p.empty() &&
           p.front().getKind() == RequirementKind::WitnessMarker);
  }

  bool shouldSkip() const {
    return (!p.empty() &&
            p.front().getKind() != RequirementKind::WitnessMarker);
  }

public:
  GenericSignatureWitnessIterator() = default;
  GenericSignatureWitnessIterator(ArrayRef<Requirement> requirements)
      : p(requirements) {
    while (shouldSkip()) { p = p.slice(1); }
  }
  
  GenericSignatureWitnessIterator &operator++() {
    checkValid();
    do { p = p.slice(1); } while (shouldSkip());
    return *this;
  }
  
  GenericSignatureWitnessIterator operator++(int) {
    auto copy = *this;
    ++(*this);
    return copy;
  }
  
  Type operator*() const {
    checkValid();
    return p.front().getFirstType();
  }
  
  Type operator->() const {
    checkValid();
    return p.front().getFirstType();
  }
  
  bool operator==(const GenericSignatureWitnessIterator &o) {
    return p.data() == o.p.data() && p.size() == o.p.size();
  }
  
  bool operator!=(const GenericSignatureWitnessIterator &o) {
    return p.data() != o.p.data() || p.size() != o.p.size();
  }
  
  static GenericSignatureWitnessIterator emptyRange() {
    return GenericSignatureWitnessIterator();
  }
  
  // Allow the witness iterator to be used with a ranged for.
  GenericSignatureWitnessIterator begin() const {
    return *this;
  }
  GenericSignatureWitnessIterator end() const {
    return GenericSignatureWitnessIterator({p.end(), p.end()});
  }
};

/// Describes the generic signature of a particular declaration, including
/// both the generic type parameters and the requirements placed on those
/// generic parameters.
class alignas(1 << TypeAlignInBits) GenericSignature final
  : public llvm::FoldingSetNode,
    private llvm::TrailingObjects<GenericSignature, GenericTypeParamType *,
                                  Requirement> {
  friend TrailingObjects;

  unsigned NumGenericParams;
  unsigned NumRequirements;

  // Make vanilla new/delete illegal.
  void *operator new(size_t Bytes) = delete;
  void operator delete(void *Data) = delete;

  size_t numTrailingObjects(OverloadToken<GenericTypeParamType *>) const {
    return NumGenericParams;
  }
  size_t numTrailingObjects(OverloadToken<Requirement>) const {
    return NumRequirements;
  }

  /// Retrieve a mutable version of the generic parameters.
  MutableArrayRef<GenericTypeParamType *> getGenericParamsBuffer() {
    return {getTrailingObjects<GenericTypeParamType *>(), NumGenericParams};
  }

  /// Retrieve a mutable version of the requirements.
  MutableArrayRef<Requirement> getRequirementsBuffer() {
    return {getTrailingObjects<Requirement>(), NumRequirements};
  }

  GenericSignature(ArrayRef<GenericTypeParamType *> params,
                   ArrayRef<Requirement> requirements,
                   bool isKnownCanonical);

  mutable llvm::PointerUnion<GenericSignature *, ASTContext *>
    CanonicalSignatureOrASTContext;
  
  static ASTContext &getASTContext(ArrayRef<GenericTypeParamType *> params,
                                   ArrayRef<Requirement> requirements);

  /// Retrieve the canonical generic environment for this generic signature.
  GenericEnvironment *getCanonicalGenericEnvironment(ModuleDecl &mod);

public:
  /// Create a new generic signature with the given type parameters and
  /// requirements.
  static GenericSignature *get(ArrayRef<GenericTypeParamType *> params,
                               ArrayRef<Requirement> requirements,
                               bool isKnownCanonical = false);

  /// Create a new generic signature with the given type parameters and
  /// requirements, first canonicalizing the types.
  static CanGenericSignature getCanonical(ArrayRef<GenericTypeParamType *> params,
                                          ArrayRef<Requirement> requirements);

  /// Retrieve the generic parameters.
  ArrayRef<GenericTypeParamType *> getGenericParams() const {
    return const_cast<GenericSignature *>(this)->getGenericParamsBuffer();
  }

  /// Retrieve the innermost generic parameters.
  ///
  /// Given a generic signature for a nested generic type, produce an
  /// array of the generic parameters for the innermost generic type.
  ArrayRef<GenericTypeParamType *> getInnermostGenericParams() const;

  /// Retrieve the requirements.
  ArrayRef<Requirement> getRequirements() const {
    return const_cast<GenericSignature *>(this)->getRequirementsBuffer();
  }

  /// Check if the generic signature makes all generic parameters
  /// concrete.
  bool areAllParamsConcrete() const {
    auto iter = getAllDependentTypes();
    return iter.begin() == iter.end();
  }

  /// Only allow allocation by doing a placement new.
  void *operator new(size_t Bytes, void *Mem) {
    assert(Mem);
    return Mem;
  }

  /// Build an interface type substitution map from a vector of Substitutions
  /// that correspond to the generic parameters in this generic signature.
  SubstitutionMap getSubstitutionMap(ArrayRef<Substitution> args) const;

  /// Same as above, but updates an existing map.
  void getSubstitutionMap(ArrayRef<Substitution> args,
                          SubstitutionMap &subMap) const;

  using LookupConformanceFn =
      llvm::function_ref<ProtocolConformanceRef(CanType, Type, ProtocolType *)>;

  /// Build an array of substitutions from an interface type substitution map,
  /// using the given function to look up conformances.
  void getSubstitutions(ModuleDecl &mod,
                        const TypeSubstitutionMap &subMap,
                        LookupConformanceFn lookupConformance,
                        SmallVectorImpl<Substitution> &result) const;

  /// Build an array of substitutions from an interface type substitution map,
  /// using the given function to look up conformances.
  void getSubstitutions(ModuleDecl &mod,
                        const SubstitutionMap &subMap,
                        SmallVectorImpl<Substitution> &result) const;

  /// Return a range that iterates through first all of the generic parameters
  /// of the signature, followed by all of their recursive member types exposed
  /// through protocol requirements.
  GenericSignatureWitnessIterator getAllDependentTypes() const {
    return GenericSignatureWitnessIterator(getRequirements());
  }

  /// Determines whether this GenericSignature is canonical.
  bool isCanonical() const;
  
  ASTContext &getASTContext() const;
  
  /// Canonicalize the components of a generic signature.
  CanGenericSignature getCanonicalSignature() const;

  /// Uniquing for the ASTContext.
  void Profile(llvm::FoldingSetNodeID &ID) {
    Profile(ID, getGenericParams(), getRequirements());
  }
  
  /// Determine whether the given dependent type is required to be a class.
  bool requiresClass(Type type, ModuleDecl &mod);

  /// Determine the superclass bound on the given dependent type.
  Type getSuperclassBound(Type type, ModuleDecl &mod);

  /// Determine the set of protocols to which the given dependent type
  /// must conform.
  ArrayRef<ProtocolDecl *> getConformsTo(Type type, ModuleDecl &mod);

  /// Determine whether the given dependent type is equal to a concrete type.
  bool isConcreteType(Type type, ModuleDecl &mod);

  /// Return the concrete type that the given dependent type is constrained to,
  /// or the null Type if it is not the subject of a concrete same-type
  /// constraint.
  Type getConcreteType(Type type, ModuleDecl &mod);

  /// Return the preferred representative of the given type parameter within
  /// this generic signature.  This may yield a concrete type or a
  /// different type parameter.
  Type getRepresentative(Type type, ModuleDecl &mod);

  /// Return whether two type parameters represent the same type under this
  /// generic signature.
  ///
  /// The type parameters must be known to not be concrete within the context.
  bool areSameTypeParameterInContext(Type type1, Type type2, ModuleDecl &mod);

  /// Return the canonical version of the given type under this generic
  /// signature.
  CanType getCanonicalTypeInContext(Type type, ModuleDecl &mod);
  bool isCanonicalTypeInContext(Type type, ModuleDecl &mod);

  static void Profile(llvm::FoldingSetNodeID &ID,
                      ArrayRef<GenericTypeParamType *> genericParams,
                      ArrayRef<Requirement> requirements);
  
  void print(raw_ostream &OS) const;
  void dump() const;
  std::string getAsString() const;
};
  
inline
CanGenericSignature::CanGenericSignature(GenericSignature *Signature)
  : Signature(Signature)
{
  assert(!Signature || Signature->isCanonical());
}
  
inline ArrayRef<CanTypeWrapper<GenericTypeParamType>>
CanGenericSignature::getGenericParams() const{
  ArrayRef<GenericTypeParamType*> params = Signature->getGenericParams();
  auto base = reinterpret_cast<const CanTypeWrapper<GenericTypeParamType>*>(
                                                                params.data());
  return {base, params.size()};
}

} // end namespace swift

#endif // SWIFT_AST_GENERIC_SIGNATURE_H
