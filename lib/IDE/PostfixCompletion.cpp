//===--- DotExprCodeCompletion.cpp ----------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/IDE/PostfixCompletion.h"
#include "swift/IDE/CodeCompletion.h"
#include "swift/IDE/CompletionLookup.h"
#include "swift/Sema/CompletionContextFinder.h"
#include "swift/Sema/ConstraintSystem.h"
#include "swift/Sema/IDETypeChecking.h"

using namespace swift;
using namespace swift::constraints;
using namespace swift::ide;

void PostfixCompletionCallback::fallbackTypeCheck(DeclContext *DC) {
  assert(!gotCallback());

  // Default to checking the completion expression in isolation.
  Expr *fallbackExpr = CompletionExpr;
  DeclContext *fallbackDC = DC;

  CompletionContextFinder finder(DC);
  if (finder.hasCompletionExpr()) {
    if (auto fallback = finder.getFallbackCompletionExpr()) {
      fallbackExpr = fallback->E;
      fallbackDC = fallback->DC;
    }
  }

  SolutionApplicationTarget completionTarget(fallbackExpr, fallbackDC,
                                             CTP_Unused, Type(),
                                             /*isDiscared=*/true);

  typeCheckForCodeCompletion(completionTarget, /*needsPrecheck*/ true,
                             [&](const Solution &S) { sawSolution(S); });
}

static ClosureActorIsolation
getClosureActorIsolation(const Solution &S, AbstractClosureExpr *ACE) {
  auto getType = [&S](Expr *E) -> Type {
    // Prefer the contextual type of the closure because it might be 'weaker'
    // than the type determined for the closure by the constraints system. E.g.
    // the contextual type might have a global actor attribute but because no
    // methods from that global actor are called in the closure, the closure has
    // a non-actor type.
    auto target = S.solutionApplicationTargets.find(dyn_cast<ClosureExpr>(E));
    if (target != S.solutionApplicationTargets.end()) {
      if (auto Ty = target->second.getClosureContextualType()) {
        return Ty;
      }
    }
    return getTypeForCompletion(S, E);
  };
  auto getClosureActorIsolationThunk = [&S](AbstractClosureExpr *ACE) {
    return getClosureActorIsolation(S, ACE);
  };
  return determineClosureActorIsolation(ACE, getType,
                                        getClosureActorIsolationThunk);
}

void PostfixCompletionCallback::sawSolutionImpl(
    const constraints::Solution &S) {
  auto &CS = S.getConstraintSystem();
  auto *ParsedExpr = CompletionExpr->getBase();
  auto *SemanticExpr = ParsedExpr->getSemanticsProvidingExpr();

  auto BaseTy = getTypeForCompletion(S, ParsedExpr);
  // If base type couldn't be determined (e.g. because base expression
  // is an invalid reference), let's not attempt to do a lookup since
  // it wouldn't produce any useful results anyway.
  if (!BaseTy)
    return;

  auto *Locator = CS.getConstraintLocator(SemanticExpr);
  Type ExpectedTy = getTypeForCompletion(S, CompletionExpr);
  Expr *ParentExpr = CS.getParentExpr(CompletionExpr);
  if (!ParentExpr && !ExpectedTy)
    ExpectedTy = CS.getContextualType(CompletionExpr, /*forConstraint=*/false);

  auto *CalleeLocator = S.getCalleeLocator(Locator);
  ValueDecl *ReferencedDecl = nullptr;
  if (auto SelectedOverload = S.getOverloadChoiceIfAvailable(CalleeLocator))
    ReferencedDecl = SelectedOverload->choice.getDeclOrNull();

  llvm::DenseMap<AbstractClosureExpr *, ClosureActorIsolation>
      ClosureActorIsolations;
  bool IsAsync = isContextAsync(S, DC);
  for (auto SAT : S.solutionApplicationTargets) {
    if (auto ACE = getAsExpr<AbstractClosureExpr>(SAT.second.getAsASTNode())) {
      ClosureActorIsolations[ACE] = getClosureActorIsolation(S, ACE);
    }
  }

  auto Key = std::make_pair(BaseTy, ReferencedDecl);
  auto Ret = BaseToSolutionIdx.insert({Key, Results.size()});
  if (Ret.second) {
    bool ISDMT = S.isStaticallyDerivedMetatype(ParsedExpr);
    bool ImplicitReturn = isImplicitSingleExpressionReturn(CS, CompletionExpr);
    bool DisallowVoid = false;
    DisallowVoid |= ExpectedTy && !ExpectedTy->isVoid();
    DisallowVoid |= !ParentExpr &&
                    CS.getContextualTypePurpose(CompletionExpr) != CTP_Unused;
    for (auto SAT : S.solutionApplicationTargets) {
      if (DisallowVoid) {
        // DisallowVoid is already set. No need to iterate further.
        break;
      }
      if (SAT.second.getAsExpr() == CompletionExpr) {
        DisallowVoid |= SAT.second.getExprContextualTypePurpose() != CTP_Unused;
      }
    }

    Results.push_back({BaseTy, ReferencedDecl,
                       /*ExpectedTypes=*/{}, DisallowVoid, ISDMT,
                       ImplicitReturn, IsAsync, ClosureActorIsolations});
    if (ExpectedTy) {
      Results.back().ExpectedTypes.push_back(ExpectedTy);
    }
  } else if (ExpectedTy) {
    auto &ExistingResult = Results[Ret.first->getSecond()];
    ExistingResult.IsInAsyncContext |= IsAsync;
    auto IsEqual = [&](Type Ty) { return ExpectedTy->isEqual(Ty); };
    if (!llvm::any_of(ExistingResult.ExpectedTypes, IsEqual)) {
      ExistingResult.ExpectedTypes.push_back(ExpectedTy);
    }
  }
}

void PostfixCompletionCallback::deliverResults(
    Expr *BaseExpr, DeclContext *DC, SourceLoc DotLoc, bool IsInSelector,
    CodeCompletionContext &CompletionCtx, CodeCompletionConsumer &Consumer) {
  ASTContext &Ctx = DC->getASTContext();
  CompletionLookup Lookup(CompletionCtx.getResultSink(), Ctx, DC,
                          &CompletionCtx);

  if (DotLoc.isValid())
    Lookup.setHaveDot(DotLoc);

  Lookup.setIsSuperRefExpr(isa<SuperRefExpr>(BaseExpr));

  if (auto *DRE = dyn_cast<DeclRefExpr>(BaseExpr))
    Lookup.setIsSelfRefExpr(DRE->getDecl()->getName() == Ctx.Id_self);

  if (isa<BindOptionalExpr>(BaseExpr) || isa<ForceValueExpr>(BaseExpr))
    Lookup.setIsUnwrappedOptional(true);

  if (IsInSelector) {
    Lookup.includeInstanceMembers();
    Lookup.setPreferFunctionReferencesToCalls();
  }

  Lookup.shouldCheckForDuplicates(Results.size() > 1);
  for (auto &Result : Results) {
    Lookup.setCanCurrDeclContextHandleAsync(Result.IsInAsyncContext);
    Lookup.setClosureActorIsolations(Result.ClosureActorIsolations);
    Lookup.setIsStaticMetatype(Result.BaseIsStaticMetaType);
    Lookup.getPostfixKeywordCompletions(Result.BaseTy, BaseExpr);
    Lookup.setExpectedTypes(Result.ExpectedTypes,
                            Result.IsImplicitSingleExpressionReturn,
                            Result.ExpectsNonVoid);
    if (isDynamicLookup(Result.BaseTy))
      Lookup.setIsDynamicLookup();
    Lookup.getValueExprCompletions(Result.BaseTy, Result.BaseDecl);
  }

  deliverCompletionResults(CompletionCtx, Lookup, DC, Consumer);
}
