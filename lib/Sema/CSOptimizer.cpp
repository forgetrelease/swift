//===--- CSOptimizer.cpp - Constraint Optimizer ---------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file implements disjunction and other constraint optimizations.
//
//===----------------------------------------------------------------------===//

#include "TypeChecker.h"
#include "swift/AST/ExistentialLayout.h"
#include "swift/AST/GenericSignature.h"
#include "swift/Basic/OptionSet.h"
#include "swift/Sema/ConstraintGraph.h"
#include "swift/Sema/ConstraintSystem.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/TinyPtrVector.h"
#include "llvm/Support/SaveAndRestore.h"
#include "llvm/Support/raw_ostream.h"
#include <cstddef>
#include <functional>

using namespace swift;
using namespace constraints;

namespace {

// TODO: both `isIntegerType` and `isFloatType` should be available on Type
// as `isStdlib{Integer, Float}Type`.

static bool isIntegerType(Type type) {
  return type->isInt() || type->isInt8() || type->isInt16() ||
         type->isInt32() || type->isInt64() || type->isUInt() ||
         type->isUInt8() || type->isUInt16() || type->isUInt32() ||
         type->isUInt64();
}

static bool isFloatType(Type type) {
  return type->isFloat() || type->isDouble() || type->isFloat80();
}

static bool isSupportedOperator(Constraint *disjunction) {
  if (!isOperatorDisjunction(disjunction))
    return false;

  auto choices = disjunction->getNestedConstraints();
  auto *decl = getOverloadChoiceDecl(choices.front());

  auto name = decl->getBaseIdentifier();
  if (name.isArithmeticOperator() || name.isStandardComparisonOperator() ||
      name.is("^")) {
    return true;
  }

  // Operators like &<<, &>>, &+, .== etc.
  if (llvm::any_of(choices, [](Constraint *choice) {
        return isSIMDOperator(getOverloadChoiceDecl(choice));
      })) {
    return true;
  }

  return false;
}

static bool isSupportedSpecialConstructor(ConstructorDecl *ctor) {
  if (auto *selfDecl = ctor->getImplicitSelfDecl()) {
    auto selfTy = selfDecl->getInterfaceType();
    /// Support `Int*`, `Float*` and `Double` initializers since their generic
    /// overloads are not too complicated.
    return selfTy && (isIntegerType(selfTy) || isFloatType(selfTy));
  }
  return false;
}

static bool isStandardComparisonOperator(ValueDecl *decl) {
  return decl->isOperator() &&
         decl->getBaseIdentifier().isStandardComparisonOperator();
}

static bool isArithmeticOperator(ValueDecl *decl) {
  return decl->isOperator() && decl->getBaseIdentifier().isArithmeticOperator();
}

static bool isSupportedDisjunction(Constraint *disjunction) {
  auto choices = disjunction->getNestedConstraints();

  if (isSupportedOperator(disjunction))
    return true;

  if (auto *ctor = dyn_cast_or_null<ConstructorDecl>(
          getOverloadChoiceDecl(choices.front()))) {
    if (isSupportedSpecialConstructor(ctor))
      return true;
  }

  // Non-operator disjunctions are supported only if they don't
  // have any generic choices.
  return llvm::all_of(choices, [&](Constraint *choice) {
    if (choice->getKind() != ConstraintKind::BindOverload)
      return false;

    if (auto *decl = getOverloadChoiceDecl(choice))
      return decl->getInterfaceType()->is<FunctionType>();

    return false;
  });
}

NullablePtr<Constraint> getApplicableFnConstraint(ConstraintGraph &CG,
                                                  Constraint *disjunction) {
  auto *boundVar = disjunction->getNestedConstraints()[0]
                       ->getFirstType()
                       ->getAs<TypeVariableType>();
  if (!boundVar)
    return nullptr;

  auto constraints = CG.gatherConstraints(
      boundVar, ConstraintGraph::GatheringKind::EquivalenceClass,
      [](Constraint *constraint) {
        return constraint->getKind() == ConstraintKind::ApplicableFunction;
      });

  if (constraints.size() != 1)
    return nullptr;

  auto *applicableFn = constraints.front();
  // Unapplied disjunction could appear as a argument to applicable function,
  // we are not interested in that.
  return applicableFn->getSecondType()->isEqual(boundVar) ? applicableFn
                                                          : nullptr;
}

void forEachDisjunctionChoice(
    ConstraintSystem &cs, Constraint *disjunction,
    llvm::function_ref<void(Constraint *, ValueDecl *decl, FunctionType *)>
        callback) {
  for (auto constraint : disjunction->getNestedConstraints()) {
    if (constraint->isDisabled())
      continue;

    if (constraint->getKind() != ConstraintKind::BindOverload)
      continue;

    auto choice = constraint->getOverloadChoice();
    auto *decl = choice.getDeclOrNull();
    if (!decl)
      continue;

    // If disjunction choice is unavailable or disfavored we cannot
    // do anything with it.
    if (decl->getAttrs().hasAttribute<DisfavoredOverloadAttr>() ||
        cs.isDeclUnavailable(decl, disjunction->getLocator()))
      continue;

    Type overloadType =
        cs.getEffectiveOverloadType(disjunction->getLocator(), choice,
                                    /*allowMembers=*/true, cs.DC);

    if (!overloadType || !overloadType->is<FunctionType>())
      continue;

    callback(constraint, decl, overloadType->castTo<FunctionType>());
  }
}

static OverloadedDeclRefExpr *isOverloadedDeclRef(Constraint *disjunction) {
  assert(disjunction->getKind() == ConstraintKind::Disjunction);

  auto *locator = disjunction->getLocator();
  if (locator->getPath().empty())
    return getAsExpr<OverloadedDeclRefExpr>(locator->getAnchor());
  return nullptr;
}

/// This maintains an "old hack" behavior where overloads  of some
/// `OverloadedDeclRef` calls were favored purely based on number of
/// argument and (non-defaulted) parameters matching.
static void findFavoredChoicesBasedOnArity(
    ConstraintSystem &cs, Constraint *disjunction, ArgumentList *argumentList,
    llvm::function_ref<void(Constraint *)> favoredChoice) {
  auto *ODRE = isOverloadedDeclRef(disjunction);
  if (!ODRE)
    return;

  if (llvm::count_if(ODRE->getDecls(), [&argumentList](auto *choice) {
        if (auto *paramList = getParameterList(choice))
          return argumentList->size() == paramList->size();
        return false;
      }) > 1)
    return;

  auto isVariadicGenericOverload = [&](ValueDecl *choice) {
    auto genericContext = choice->getAsGenericContext();
    if (!genericContext)
      return false;

    auto *GPL = genericContext->getGenericParams();
    if (!GPL)
      return false;

    return llvm::any_of(GPL->getParams(), [&](const GenericTypeParamDecl *GP) {
      return GP->isParameterPack();
    });
  };

  bool hasVariadicGenerics = false;
  SmallVector<Constraint *> favored;

  forEachDisjunctionChoice(
      cs, disjunction,
      [&](Constraint *choice, ValueDecl *decl, FunctionType *overloadType) {
        if (isVariadicGenericOverload(decl))
          hasVariadicGenerics = true;

        if (overloadType->getNumParams() == argumentList->size() ||
            llvm::count_if(*getParameterList(decl), [](auto *param) {
              return !param->isDefaultArgument();
            }) == argumentList->size())
          favored.push_back(choice);
      });

  if (hasVariadicGenerics)
    return;

  for (auto *choice : favored)
    favoredChoice(choice);
}

} // end anonymous namespace

/// Given a set of disjunctions, attempt to determine
/// favored choices in the current context.
static Constraint *determineBestChoicesInContext(
    ConstraintSystem &cs, SmallVectorImpl<Constraint *> &disjunctions,
    llvm::DenseMap<Constraint *,
                   std::pair<double, llvm::TinyPtrVector<Constraint *>>>
        &favorings) {
  double bestOverallScore = 0.0;
  // Tops scores across all of the disjunctions.
  llvm::DenseMap<Constraint *, double> disjunctionScores;
  llvm::DenseMap<Constraint *, llvm::TinyPtrVector<Constraint *>>
      favoredChoicesPerDisjunction;

  for (auto *disjunction : disjunctions) {
    auto applicableFn =
        getApplicableFnConstraint(cs.getConstraintGraph(), disjunction);

    if (applicableFn.isNull())
      continue;

    auto argFuncType =
        applicableFn.get()->getFirstType()->getAs<FunctionType>();

    auto argumentList = cs.getArgumentList(applicableFn.get()->getLocator());
    if (!argumentList)
      return nullptr;

    for (const auto &argument : *argumentList) {
      if (auto *expr = argument.getExpr()) {
        // Directly `<#...#>` or has one inside.
        if (isa<CodeCompletionExpr>(expr) ||
            cs.containsIDEInspectionTarget(expr))
          return nullptr;
      }
    }

    // This maintains an "old hack" behavior where overloads
    // of `OverloadedDeclRef` calls were favored purely
    // based on arity of arguments and parameters matching.
    {
      findFavoredChoicesBasedOnArity(
          cs, disjunction, argumentList, [&](Constraint *choice) {
            favoredChoicesPerDisjunction[disjunction].push_back(choice);
          });

      if (!favoredChoicesPerDisjunction[disjunction].empty()) {
        disjunctionScores[disjunction] = 0.01;
        bestOverallScore = std::max(bestOverallScore, 0.01);
        continue;
      }
    }

    if (!isSupportedDisjunction(disjunction))
      continue;

    SmallVector<FunctionType::Param, 8> argsWithLabels;
    {
      argsWithLabels.append(argFuncType->getParams().begin(),
                            argFuncType->getParams().end());
      FunctionType::relabelParams(argsWithLabels, argumentList);
    }

    SmallVector<SmallVector<std::pair<Type, /*fromLiteral=*/bool>, 2>, 2>
        candidateArgumentTypes;
    candidateArgumentTypes.resize(argFuncType->getNumParams());

    llvm::TinyPtrVector<Type> resultTypes;

    for (unsigned i = 0, n = argFuncType->getNumParams(); i != n; ++i) {
      const auto &param = argFuncType->getParams()[i];
      auto argType = cs.simplifyType(param.getPlainType());

      SmallVector<std::pair<Type, bool>, 2> types;
      if (auto *typeVar = argType->getAs<TypeVariableType>()) {
        auto bindingSet = cs.getBindingsFor(typeVar, /*finalize=*/true);

        for (const auto &binding : bindingSet.Bindings) {
          types.push_back({binding.BindingType, /*fromLiteral=*/false});
        }

        for (const auto &literal : bindingSet.Literals) {
          if (literal.second.hasDefaultType()) {
            // Add primary default type
            types.push_back(
                {literal.second.getDefaultType(), /*fromLiteral=*/true});
          }
        }

        // Helps situations like `1 + {Double, CGFloat}(...)` by inferring
        // a type for the second operand of `+` based on a type being constructed.
        //
        // Currently limited to Double and CGFloat only since we need to 
        // support implicit `Double<->CGFloat` conversion.
        if (typeVar->getImpl().isFunctionResult() &&
            isOperatorDisjunction(disjunction)) {
          auto resultLoc = typeVar->getImpl().getLocator();
          if (auto *call = getAsExpr<CallExpr>(resultLoc->getAnchor())) {
            if (auto *typeExpr = dyn_cast<TypeExpr>(call->getFn())) {
              auto instanceTy = cs.getType(typeExpr)->getMetatypeInstanceType();
              if (instanceTy->isDouble() || instanceTy->isCGFloat())
                types.push_back({instanceTy, /*fromLiteral=*/false});
            }
          }
        }
      } else {
        types.push_back({argType, /*fromLiteral=*/false});
      }

      candidateArgumentTypes[i].append(types);
    }

    auto resultType = cs.simplifyType(argFuncType->getResult());
    if (auto *typeVar = resultType->getAs<TypeVariableType>()) {
      auto bindingSet = cs.getBindingsFor(typeVar, /*finalize=*/true);

      for (const auto &binding : bindingSet.Bindings) {
        resultTypes.push_back(binding.BindingType);
      }
    } else {
      resultTypes.push_back(resultType);
    }

    // Determine whether all of the argument candidates are inferred from literals.
    // This information is going to be used later on when we need to decide how to
    // score a matching choice.
    bool onlyLiteralCandidates =
        argFuncType->getNumParams() > 0 &&
        llvm::none_of(
            indices(argFuncType->getParams()), [&](const unsigned argIdx) {
              auto &candidates = candidateArgumentTypes[argIdx];
              return llvm::any_of(candidates, [&](const auto &candidate) {
                return !candidate.second;
              });
            });

    // Match arguments to the given overload choice.
    auto matchArguments = [&](OverloadChoice choice, FunctionType *overloadType)
			-> std::optional<MatchCallArgumentResult> {
      auto *decl = choice.getDeclOrNull();
      assert(decl);

      auto hasAppliedSelf =
          decl->hasCurriedSelf() &&
          doesMemberRefApplyCurriedSelf(choice.getBaseType(), decl);

      ParameterListInfo paramListInfo(overloadType->getParams(), decl,
                                      hasAppliedSelf);

      MatchCallArgumentListener listener;
      return matchCallArguments(argsWithLabels, overloadType->getParams(),
                                paramListInfo,
                                argumentList->getFirstTrailingClosureIndex(),
                                /*allow fixes*/ false, listener, std::nullopt);
    };

    // Determine whether the candidate type is a subclass of the superclass
    // type.
    std::function<bool(Type, Type)> isSubclassOf = [&](Type candidateType,
                                                       Type superclassType) {
      // Conversion from a concrete type to its existential value.
      if (superclassType->isExistentialType() && !superclassType->isAny()) {
        auto layout = superclassType->getExistentialLayout();

        if (auto layoutConstraint = layout.getLayoutConstraint()) {
          if (layoutConstraint->isClass() &&
              !(candidateType->isClassExistentialType() ||
                candidateType->mayHaveSuperclass()))
            return false;
        }

        if (layout.explicitSuperclass &&
            !isSubclassOf(candidateType, layout.explicitSuperclass))
          return false;

        return llvm::all_of(layout.getProtocols(), [&](ProtocolDecl *P) {
          if (auto superclass = P->getSuperclassDecl()) {
            if (!isSubclassOf(candidateType,
                              superclass->getDeclaredInterfaceType()))
              return false;
          }

          return bool(TypeChecker::containsProtocol(candidateType, P,
                                                    /*allowMissing=*/false));
        });
      }

      auto *subclassDecl = candidateType->getClassOrBoundGenericClass();
      auto *superclassDecl = superclassType->getClassOrBoundGenericClass();

      if (!(subclassDecl && superclassDecl))
        return false;

      return superclassDecl->isSuperclassOf(subclassDecl);
    };

    enum class MatchFlag {
      OnParam,
      Literal,
      ExactOnly,
    };

    using MatchOptions = OptionSet<MatchFlag>;

    // Perform a limited set of checks to determine whether the candidate
    // could possibly match the parameter type:
    //
    // - Equality
    // - Protocol conformance(s)
    // - Optional injection
    // - Superclass conversion
    // - Array-to-pointer conversion
    // - Value to existential conversion
    // - Exact match on top-level types
    std::function<double(GenericSignature, Type, Type, MatchOptions)>
        scoreCandidateMatch = [&](GenericSignature genericSig,
                                  Type candidateType, Type paramType,
                                  MatchOptions options) -> double {
      auto areEqual = [](Type a, Type b) {
        return a->getDesugaredType()->isEqual(b->getDesugaredType());
      };

      if (options.contains(MatchFlag::ExactOnly))
        return areEqual(candidateType, paramType) ? 1 : 0;

      // Exact match between candidate and parameter types.
      if (areEqual(candidateType, paramType))
        return options.contains(MatchFlag::Literal) ? 0.3 : 1;

      if (options.contains(MatchFlag::Literal))
        return 0;

      // Check whether match would require optional injection.
      {
        SmallVector<Type, 2> candidateOptionals;
        SmallVector<Type, 2> paramOptionals;

        candidateType =
            candidateType->lookThroughAllOptionalTypes(candidateOptionals);
        paramType = paramType->lookThroughAllOptionalTypes(paramOptionals);

        if (!candidateOptionals.empty() || !paramOptionals.empty()) {
          if (paramOptionals.size() >= candidateOptionals.size()) {
            auto score = scoreCandidateMatch(genericSig, candidateType,
                                             paramType, options);
            // Injection lowers the score slightly to comply with
            // old behavior where exact matches on operator parameter
            // types were always preferred.
            return score == 1 && isOperatorDisjunction(disjunction) ? 0.9
                                                                    : score;
          }

          // Optionality mismatch.
          return 0;
        }
      }

      // Candidate could be converted to a superclass.
      if (isSubclassOf(candidateType, paramType))
        return 1;

      // Possible Array<T> -> Unsafe*Pointer conversion.
      if (options.contains(MatchFlag::OnParam)) {
        if (candidateType->isArrayType() &&
            paramType->getAnyPointerElementType())
          return 1;
      }

      // If both argument and parameter are tuples of the same arity,
      // it's a match.
      {
        if (auto *candidateTuple = candidateType->getAs<TupleType>()) {
          auto *paramTuple = paramType->getAs<TupleType>();
          if (paramTuple &&
              candidateTuple->getNumElements() == paramTuple->getNumElements())
            return 1;
        }
      }

      // Check protocol requirement(s) if this parameter is a
      // generic parameter type.
      if (genericSig && paramType->is<GenericTypeParamType>()) {
        // If candidate is not fully resolved, check conformances only
        // and lower the score.
        if (candidateType->hasTypeVariable()) {
          auto protocolRequirements =
              genericSig->getRequiredProtocols(paramType);
          if (llvm::all_of(protocolRequirements, [&](ProtocolDecl *protocol) {
                return bool(cs.lookupConformance(candidateType, protocol));
              })) {
            if (auto *GP = paramType->getAs<GenericTypeParamType>()) {
              auto *paramDecl = GP->getDecl();
              if (paramDecl && paramDecl->isOpaqueType())
                return 1.0;
            }
            return 0.7;
          }

          return 0;
        }

        // If the candidate type is fully resolved, let's check all of
        // the requirements that are associated with the corresponding
        // parameter, if all of them are satisfied this candidate is
        // an exact match.

        auto isParameterType = [&paramType](Type type) {
          return type->isEqual(paramType);
        };

        SmallVector<Requirement, 4> requirements;
        for (const auto &requirement : genericSig.getRequirements()) {
          if (requirement.getFirstType().findIf(isParameterType) ||
              (requirement.getKind() != RequirementKind::Layout &&
               requirement.getSecondType().findIf(isParameterType)))
            requirements.push_back(requirement);
        }

        auto result = checkRequirements(
            requirements,
            [&paramType, &candidateType](SubstitutableType *type) -> Type {
              if (type->isEqual(paramType))
                return candidateType;
              return ErrorType::get(type);
            },
            SubstOptions(std::nullopt));

        // Concrete operator overloads are always more preferable to
        // generic ones if there are exact or subtype matches, for
        // everything else the solver should try both concrete and
        // generic and disambiguate during ranking.
        if (result == CheckRequirementsResult::Success)
          return isOperatorDisjunction(disjunction) ? 0.9 : 1.0;

        return 0;
      }

      // Parameter is generic, let's check whether top-level
      // types match i.e. Array<Element> as a parameter.
      //
      // This is slightly better than all of the conformances matching
      // because the parameter is concrete and could split the graph.      
      if (paramType->hasTypeParameter()) {
        auto *candidateDecl = candidateType->getAnyNominal();
        auto *paramDecl = paramType->getAnyNominal();

        if (candidateDecl && paramDecl && candidateDecl == paramDecl)
          return 0.8;
      }

      return 0;
    };

    // The choice with the best score.
    double bestScore = 0.0;
    SmallVector<std::pair<Constraint *, double>, 2> favoredChoices;

    bool isOverloadedDeclRefDisjunction = isOverloadedDeclRef(disjunction);

    forEachDisjunctionChoice(
        cs, disjunction,
        [&](Constraint *choice, ValueDecl *decl, FunctionType *overloadType) {
          GenericSignature genericSig;
          {
            if (auto *GF = dyn_cast<AbstractFunctionDecl>(decl)) {
              genericSig = GF->getGenericSignature();
            } else if (auto *SD = dyn_cast<SubscriptDecl>(decl)) {
              genericSig = SD->getGenericSignature();
            }
          }

          auto matchings =
              matchArguments(choice->getOverloadChoice(), overloadType);
          if (!matchings)
            return;

          bool favorExactMatchesOnly = false;
          // Preserves old behavior where for unary calls to members
          // the solver would not consider choices that didn't match on
          // the number of parameters (regardless of defaults) and only
          // exact matches were favored.
          if (!isOverloadedDeclRefDisjunction && argumentList->size() == 1) {
            // Old behavior completely disregarded the fact that some of
            // the parameters could be defaulted.
            if (overloadType->getNumParams() != 1)
              return;

            favorExactMatchesOnly = true;
          }

          double score = 0.0;
          unsigned numDefaulted = 0;
          for (unsigned paramIdx = 0, n = overloadType->getNumParams();
               paramIdx != n; ++paramIdx) {
            const auto &param = overloadType->getParams()[paramIdx];

            auto argIndices = matchings->parameterBindings[paramIdx];
            switch (argIndices.size()) {
            case 0:
              // Current parameter is defaulted, mark and continue.
              ++numDefaulted;
              continue;

            case 1:
              // One-to-one match between argument and parameter.
              break;

            default:
              // Cannot deal with multiple possible matchings at the moment.
              return;
            }

            auto argIdx = argIndices.front();

            // Looks like there is nothing know about the argument.
            if (candidateArgumentTypes[argIdx].empty())
              continue;

            const auto paramFlags = param.getParameterFlags();

            // If parameter is variadic we cannot compare because we don't know
            // real arity.
            if (paramFlags.isVariadic())
              continue;

            auto paramType = param.getPlainType();

            // FIXME: Let's skip matching function types for now
            // because they have special rules for e.g. Concurrency
            // (around @Sendable) and @convention(c).
            if (paramType->is<FunctionType>())
              continue;

            // The idea here is to match the parameter type against
            // all of the argument candidate types and pick the best
            // match (i.e. exact equality one).
            //
            // If none of the candidates match exactly and they are
            // all bound concrete types, we consider this is mismatch
            // at this parameter position and remove the overload choice
            // from consideration.
            double bestCandidateScore = 0;
            llvm::BitVector mismatches(candidateArgumentTypes[argIdx].size());

            for (unsigned candidateIdx :
                 indices(candidateArgumentTypes[argIdx])) {
              // If one of the candidates matched exactly there is no reason
              // to continue checking.
              if (bestCandidateScore == 1)
                break;

              Type candidateType;
              bool isLiteralDefault;

              std::tie(candidateType, isLiteralDefault) =
                  candidateArgumentTypes[argIdx][candidateIdx];

              // `inout` parameter accepts only l-value argument.
              if (paramFlags.isInOut() && !candidateType->is<LValueType>()) {
                mismatches.set(candidateIdx);
                continue;
              }

              // The specifier only matters for `inout` check.
              candidateType = candidateType->getWithoutSpecifierType();

              MatchOptions options(MatchFlag::OnParam);
              if (isLiteralDefault)
                options |= MatchFlag::Literal;
              if (favorExactMatchesOnly)
                options |= MatchFlag::ExactOnly;

              auto score = scoreCandidateMatch(genericSig, candidateType,
                                               paramType, options);
              if (score > 0) {
                bestCandidateScore = std::max(bestCandidateScore, score);
                continue;
              }

              // Only established arguments could be considered mismatches,
              // literal default types should be regarded as holes if they
              // didn't match.
              if (!isLiteralDefault && !candidateType->hasTypeVariable())
                mismatches.set(candidateIdx);
            }

            // If none of the candidates for this parameter matched, let's
            // drop this overload from any further consideration.
            if (mismatches.all())
              return;

            score += bestCandidateScore;
          }

          // An overload whether all of the parameters are defaulted
          // that's called without arguments.
          if (numDefaulted == overloadType->getNumParams())
            return;

          // Average the score to avoid disfavoring disjunctions with fewer
          // parameters.
          score /= (overloadType->getNumParams() - numDefaulted);

          // Make sure that the score is uniform for all disjunction
          // choices that match on literals only, this would make sure that
          // in operator chains that consist purely of literals we'd
          // always prefer outermost disjunction instead of innermost
          // one.
          //
          // Preferring outer disjunction first works better in situations
          // when contextual type for the whole chain becomes available at
          // some point during solving at it would allow for faster pruning.
          if (score > 0 && onlyLiteralCandidates)
            score = 0.1;

          // If one of the result types matches exactly, that's a good
          // indication that overload choice should be favored.
          //
          // If nothing is known about the arguments it's only safe to
          // check result for operators (except to standard comparison
          // ones that all have the same result type), regular
          // functions/methods and especially initializers could end up
          // with a lot of favored overloads because on the result type alone.
          if (decl->isOperator() && !isStandardComparisonOperator(decl)) {
            if (llvm::any_of(resultTypes, [&](const Type candidateResultTy) {
                  return scoreCandidateMatch(genericSig,
                                             overloadType->getResult(),
                                             candidateResultTy,
                                             /*options=*/{}) > 0;
                })) {
              score += 1.0;
            }
          }

          if (score > 0) {
            // Nudge the score slightly to prefer homogeneous arithmetic operators.
            //
            // This is an opportunistic optimization based on the operator
            // use patterns where homogeneous operators are the most
            // heavily used ones.
            if (isArithmeticOperator(decl) &&
                overloadType->getNumParams() == 2) {
              auto resultTy = overloadType->getResult();
              if (llvm::all_of(overloadType->getParams(),
                               [&resultTy](const auto &param) {
                                 return param.getPlainType()->isEqual(resultTy);
                               }))
                score += 0.001;
            }

            favoredChoices.push_back({choice, score});
            bestScore = std::max(bestScore, score);
          }
        });

    if (cs.isDebugMode()) {
      PrintOptions PO;
      PO.PrintTypesForDebugging = true;

      llvm::errs().indent(cs.solverState->getCurrentIndent())
          << "<<< Disjunction "
          << disjunction->getNestedConstraints()[0]->getFirstType()->getString(
                 PO)
          << " with score " << bestScore << "\n";
    }

    // No matching overload choices to favor.
    if (bestScore == 0.0)
      continue;

    bestOverallScore = std::max(bestOverallScore, bestScore);

    disjunctionScores[disjunction] = bestScore;
    for (const auto &choice : favoredChoices) {
      if (choice.second == bestScore)
        favoredChoicesPerDisjunction[disjunction].push_back(choice.first);
    }
  }

  if (cs.isDebugMode() && bestOverallScore > 0) {
    PrintOptions PO;
    PO.PrintTypesForDebugging = true;

    auto getLogger = [&](unsigned extraIndent = 0) -> llvm::raw_ostream & {
      return llvm::errs().indent(cs.solverState->getCurrentIndent() +
                                 extraIndent);
    };

    {
      auto &log = getLogger();
      log << "(Optimizing disjunctions: [";

      interleave(
          disjunctions,
          [&](const auto *disjunction) {
            log << disjunction->getNestedConstraints()[0]
                       ->getFirstType()
                       ->getString(PO);
          },
          [&]() { log << ", "; });

      log << "]\n";
    }

    getLogger(/*extraIndent=*/4)
        << "Best overall score = " << bestOverallScore << '\n';

    for (const auto &entry : disjunctionScores) {
      getLogger(/*extraIndent=*/4)
          << "[Disjunction '"
          << entry.first->getNestedConstraints()[0]->getFirstType()->getString(
                 PO)
          << "' with score = " << entry.second << '\n';

      for (const auto *choice : favoredChoicesPerDisjunction[entry.first]) {
        auto &log = getLogger(/*extraIndent=*/6);

        log << "- ";
        choice->print(log, &cs.getASTContext().SourceMgr);
        log << '\n';
      }

      getLogger(/*extraIdent=*/4) << "]\n";
    }

    getLogger() << ")\n";
  }

  if (bestOverallScore == 0)
    return nullptr;

  for (auto &entry : disjunctionScores) {
    TinyPtrVector<Constraint *> favoredChoices;
    for (auto *choice : favoredChoicesPerDisjunction[entry.first])
      favoredChoices.push_back(choice);
    favorings[entry.first] = std::make_pair(entry.second, favoredChoices);
  }

  Constraint *bestDisjunction = nullptr;
  for (auto *disjunction : disjunctions) {
    if (disjunctionScores[disjunction] != bestOverallScore)
      continue;

    if (!bestDisjunction)
      bestDisjunction = disjunction;
    else // Multiple disjunctions with the same score.
      return nullptr;
  }

  return bestDisjunction;
}

// Attempt to find a disjunction of bind constraints where all options
// in the disjunction are binding the same type variable.
//
// Prefer disjunctions where the bound type variable is also the
// right-hand side of a conversion constraint, since having a concrete
// type that we're converting to can make it possible to split the
// constraint system into multiple ones.
static Constraint *
selectBestBindingDisjunction(ConstraintSystem &cs,
                             SmallVectorImpl<Constraint *> &disjunctions) {

  if (disjunctions.empty())
    return nullptr;

  auto getAsTypeVar = [&cs](Type type) {
    return cs.simplifyType(type)->getRValueType()->getAs<TypeVariableType>();
  };

  Constraint *firstBindDisjunction = nullptr;
  for (auto *disjunction : disjunctions) {
    auto choices = disjunction->getNestedConstraints();
    assert(!choices.empty());

    auto *choice = choices.front();
    if (choice->getKind() != ConstraintKind::Bind)
      continue;

    // We can judge disjunction based on the single choice
    // because all of choices (of bind overload set) should
    // have the same left-hand side.
    // Only do this for simple type variable bindings, not for
    // bindings like: ($T1) -> $T2 bind String -> Int
    auto *typeVar = getAsTypeVar(choice->getFirstType());
    if (!typeVar)
      continue;

    if (!firstBindDisjunction)
      firstBindDisjunction = disjunction;

    auto constraints = cs.getConstraintGraph().gatherConstraints(
        typeVar, ConstraintGraph::GatheringKind::EquivalenceClass,
        [](Constraint *constraint) {
          return constraint->getKind() == ConstraintKind::Conversion;
        });

    for (auto *constraint : constraints) {
      if (typeVar == getAsTypeVar(constraint->getSecondType()))
        return disjunction;
    }
  }

  // If we had any binding disjunctions, return the first of
  // those. These ensure that we attempt to bind types earlier than
  // trying the elements of other disjunctions, which can often mean
  // we fail faster.
  return firstBindDisjunction;
}

std::optional<std::pair<Constraint *, llvm::TinyPtrVector<Constraint *>>>
ConstraintSystem::selectDisjunction() {
  SmallVector<Constraint *, 4> disjunctions;

  collectDisjunctions(disjunctions);
  if (disjunctions.empty())
    return std::nullopt;

  if (auto *disjunction = selectBestBindingDisjunction(*this, disjunctions))
    return std::make_pair(disjunction, llvm::TinyPtrVector<Constraint *>());

  llvm::DenseMap<Constraint *,
                 std::pair</*bestScore=*/double, llvm::TinyPtrVector<Constraint *>>>
      favorings;
  if (auto *bestDisjunction =
          determineBestChoicesInContext(*this, disjunctions, favorings))
    return std::make_pair(bestDisjunction, favorings[bestDisjunction].second);

  // Pick the disjunction with the smallest number of favored, then active
  // choices.
  auto bestDisjunction = std::min_element(
      disjunctions.begin(), disjunctions.end(),
      [&](Constraint *first, Constraint *second) -> bool {
        unsigned firstActive = first->countActiveNestedConstraints();
        unsigned secondActive = second->countActiveNestedConstraints();

        auto &[firstScore, firstFavoredChoices] = favorings[first];
        auto &[secondScore, secondFavoredChoices] = favorings[second];

        // Rank based on scores only if both disjunctions are supported.
        if (isSupportedDisjunction(first) && isSupportedDisjunction(second)) {
          // If both disjunctions have the same score they should be ranked
          // based on number of favored/active choices.
          if (firstScore != secondScore)
            return firstScore > secondScore;
        }

        unsigned numFirstFavored = firstFavoredChoices.size();
        unsigned numSecondFavored = secondFavoredChoices.size();

        if (numFirstFavored == numSecondFavored) {
          if (firstActive != secondActive)
            return firstActive < secondActive;
        }

        numFirstFavored = numFirstFavored ? numFirstFavored : firstActive;
        numSecondFavored = numSecondFavored ? numSecondFavored : secondActive;

        return numFirstFavored < numSecondFavored;
      });

  if (bestDisjunction != disjunctions.end())
    return std::make_pair(*bestDisjunction, favorings[*bestDisjunction].second);

  return std::nullopt;
}
