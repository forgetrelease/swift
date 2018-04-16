//===--- ClosureLifetimeFixup.cpp - Fixup the lifetime of closures --------===//
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

#define DEBUG_TYPE "closure-lifetime-fixup"

#include "swift/SIL/DebugUtils.h"
#include "swift/SIL/InstructionUtils.h"
#include "swift/SIL/SILArgument.h"
#include "swift/SIL/SILBuilder.h"
#include "swift/SIL/SILInstruction.h"
#include "swift/SILOptimizer/PassManager/Passes.h"
#include "swift/SILOptimizer/PassManager/Transforms.h"
#include "swift/SILOptimizer/Utils/CFG.h"
#include "swift/SILOptimizer/Utils/Local.h"

#include "llvm/Support/CommandLine.h"

llvm::cl::opt<bool> DisableConvertEscapeToNoEscapeSwitchEnumPeephole(
    "sil-disable-convert-escape-to-noescape-switch-peephole",
    llvm::cl::init(false),
    llvm::cl::desc(
        "Disable the convert_escape_to_noescape switch enum peephole. "),
    llvm::cl::Hidden);

using namespace swift;

static SILBasicBlock *getOptionalDiamondSuccessor(SwitchEnumInst *SEI) {
   auto numSuccs = SEI->getNumSuccessors();
   if (numSuccs != 2)
     return nullptr;
   auto *SuccSome = SEI->getCase(0).second;
   auto *SuccNone = SEI->getCase(1).second;
   if (SuccSome->args_size() != 1)
     std::swap(SuccSome, SuccNone);

   if (SuccSome->args_size() != 1 || SuccNone->args_size() != 0)
     return nullptr;

   auto *Succ = SuccSome->getSingleSuccessorBlock();
   if (!Succ)
     return nullptr;

   if (SuccNone == Succ)
     return Succ;

   SuccNone = SuccNone->getSingleSuccessorBlock();
   if (SuccNone == Succ)
     return Succ;

   SuccNone = SuccNone->getSingleSuccessorBlock();
   if (SuccNone == Succ)
     return Succ;

   return nullptr;
}

/// Extend the lifetime of the convert_escape_to_noescape's operand to the end
/// of the function.
static void extendLifetimeToEndOfFunction(SILFunction &Fn,
                                          ConvertEscapeToNoEscapeInst *Cvt) {
  auto EscapingClosure = Cvt->getOperand();
  auto EscapingClosureTy = EscapingClosure->getType();
  auto OptionalEscapingClosureTy = SILType::getOptionalType(EscapingClosureTy);
  auto loc = RegularLocation::getAutoGeneratedLocation();

  SILBuilderWithScope B(Cvt);
  auto NewCvt = B.createConvertEscapeToNoEscape(
      Cvt->getLoc(), Cvt->getOperand(), Cvt->getType(), false, true);
  Cvt->replaceAllUsesWith(NewCvt);
  Cvt->eraseFromParent();
  Cvt = NewCvt;

  // Create an alloc_stack Optional<() -> ()> at the beginning of the function.
  AllocStackInst *Slot;
  auto &Context = Cvt->getModule().getASTContext();
  {
    SILBuilderWithScope B(Fn.getEntryBlock()->begin());
    Slot = B.createAllocStack(loc, OptionalEscapingClosureTy);
    auto *NoneDecl = Context.getOptionalNoneDecl();
    // Store None to it.
    B.createStore(
        loc, B.createEnum(loc, SILValue(), NoneDecl, OptionalEscapingClosureTy),
        Slot, StoreOwnershipQualifier::Init);
  }
  // Insert a copy before the convert_escape_to_noescape and store it to the
  // alloc_stack location.
  {
    SILBuilderWithScope B(Cvt);
    auto *SomeDecl = Context.getOptionalSomeDecl();
    B.createDestroyAddr(loc, Slot);
    auto ClosureCopy = B.createCopyValue(loc, EscapingClosure);
    B.createStore(
        loc,
        B.createEnum(loc, ClosureCopy, SomeDecl, OptionalEscapingClosureTy),
        Slot, StoreOwnershipQualifier::Init);
  }
  // Insert destroys at the function exits.
  SmallVector<SILBasicBlock *, 4> ExitingBlocks;
  Fn.findExitingBlocks(ExitingBlocks);
  for (auto *Exit : ExitingBlocks) {
    auto *Term = Exit->getTerminator();
    SILBuilderWithScope B(Term);
    B.setInsertionPoint(Term);
    B.createDestroyAddr(loc, Slot);
    B.createDeallocStack(loc, Slot);
  }
}

static SILInstruction *lookThroughRebastractionUsers(
    SILInstruction *Inst,
    llvm::DenseMap<SILInstruction *, SILInstruction *> &Memoized) {

  if (Inst == nullptr)
    return nullptr;

  // Try a cached lookup.
  auto Res = Memoized.find(Inst);
  if (Res != Memoized.end())
    return Res->second;

  // Cache recursive results.
  auto memoizeResult = [&] (SILInstruction *from, SILInstruction *toResult) {
    Memoized[from] = toResult;
    return toResult;
  };

  // If we have a convert_function, just look at its user.
  if (auto *Cvt = dyn_cast<ConvertFunctionInst>(Inst))
    return memoizeResult(Inst, lookThroughRebastractionUsers(
                                   getSingleNonDebugUser(Cvt), Memoized));
  if (auto *Cvt = dyn_cast<ConvertEscapeToNoEscapeInst>(Inst))
    return memoizeResult(Inst, lookThroughRebastractionUsers(
                                   getSingleNonDebugUser(Cvt), Memoized));

  // If we have a partial_apply user look at its single (non release) user.
  auto *PA = dyn_cast<PartialApplyInst>(Inst);
  if (!PA) return Inst;

  SILInstruction *SingleNonDebugNonRefCountUser = nullptr;
  for (auto *Usr : getNonDebugUses(PA)) {
    auto *I = Usr->getUser();
    if (onlyAffectsRefCount(I))
      continue;
    if (SingleNonDebugNonRefCountUser) {
      SingleNonDebugNonRefCountUser = nullptr;
      break;
    }
    SingleNonDebugNonRefCountUser = I;
  }

  return memoizeResult(Inst, lookThroughRebastractionUsers(
                                 SingleNonDebugNonRefCountUser, Memoized));
}

static bool tryExtendLifetimeToLastUse(
    ConvertEscapeToNoEscapeInst *Cvt,
    llvm::DenseMap<SILInstruction *, SILInstruction *> &Memoized) {
  // Don't optimize converts that might have been escaped by the function call
  // (materializeForSet 'escapes' its arguments into the writeback buffer).
  if (Cvt->isEscapedByUser())
    return false;

  // If there is a single user that is an apply this is simple: extend the
  // lifetime of the operand until after the apply.
  auto SingleUser = lookThroughRebastractionUsers(Cvt, Memoized);
  if (!SingleUser)
    return false;

  // Handle an apply.
  if (auto SingleApplyUser = FullApplySite::isa(SingleUser)) {
    // FIXME: Don't know how-to handle begin_apply/end_apply yet.
    if (auto *Begin =
            dyn_cast<BeginApplyInst>(SingleApplyUser.getInstruction())) {
      return false;
    }

    auto loc = RegularLocation::getAutoGeneratedLocation();

    // Insert a copy at the convert_escape_to_noescape [not_guaranteed] and
    // change the instruction to the guaranteed form.
    auto EscapingClosure = Cvt->getOperand();
    {
      SILBuilderWithScope B(Cvt);
      auto NewCvt = B.createConvertEscapeToNoEscape(
          Cvt->getLoc(), Cvt->getOperand(), Cvt->getType(), false, true);
      Cvt->replaceAllUsesWith(NewCvt);
      Cvt->eraseFromParent();
      Cvt = NewCvt;
    }

    SILBuilderWithScope B2(Cvt);
    auto ClosureCopy = B2.createCopyValue(loc, EscapingClosure);

    // Insert a destroy after the apply.
    if (auto *Apply = dyn_cast<ApplyInst>(SingleApplyUser.getInstruction())) {
      auto InsertPt = std::next(SILBasicBlock::iterator(Apply));
      SILBuilderWithScope B3(InsertPt);
      B3.createDestroyValue(loc, ClosureCopy);

    } else if (auto *Try =
                   dyn_cast<TryApplyInst>(SingleApplyUser.getInstruction())) {
      for (auto *SuccBB : Try->getSuccessorBlocks()) {
        SILBuilderWithScope B3(SuccBB->begin());
        B3.createDestroyValue(loc, ClosureCopy);
      }
    } else {
      llvm_unreachable("Unknown FullApplySite instruction kind");
    }
    return true;
  }
  return false;
}

/// Ensure the lifetime of the closure accross an
///
///   optional<@escaping () -> ()> to
///   optional<@noescape @convention(block) () -> ()>
///
///   conversion and its use.
///
///   The pattern this is looking for
///                            switch_enum %closure
///                           /           \
///     convert_escape_to_noescape          nil
///                             switch_enum
///                           /           \
///                convertToBlock          nil
///                           \            /
///                     (%convertOptionalBlock :)
///   We will insert a copy_value of the original %closure before the two
///   diamonds. And a destroy of %closure at the last destroy of
///   %convertOptionalBlock.
static bool trySwitchEnumPeephole(ConvertEscapeToNoEscapeInst *Cvt) {
  // Don't optimize converts that might have been escaped by the function call
  // (materializeForSet 'escapes' its arguments into the writeback buffer).
  if (Cvt->isEscapedByUser())
    return false;

  auto *blockArg = dyn_cast<SILArgument>(Cvt->getOperand());
  if (!blockArg)
    return false;
  auto *PredBB = Cvt->getParent()->getSinglePredecessorBlock();
  if (!PredBB)
    return false;
  auto *ConvertSuccessorBlock = Cvt->getParent()->getSingleSuccessorBlock();
  if (!ConvertSuccessorBlock)
    return false;
  auto *SwitchEnum1 = dyn_cast<SwitchEnumInst>(PredBB->getTerminator());
  if (!SwitchEnum1)
    return false;
  auto *DiamondSucc = getOptionalDiamondSuccessor(SwitchEnum1);
  if (!DiamondSucc)
    return false;
  auto *SwitchEnum2 = dyn_cast<SwitchEnumInst>(DiamondSucc->getTerminator());
  if (!SwitchEnum2)
    return false;
  auto *DiamondSucc2 = getOptionalDiamondSuccessor(SwitchEnum2);
  if (!DiamondSucc2)
    return false;
  if (DiamondSucc2->getNumArguments() != 1)
    return false;

  // Look for the last and only destroy.
  SILInstruction *onlyDestroy = [&]() -> SILInstruction * {
    SILInstruction *lastDestroy = nullptr;
    for (auto *Use : DiamondSucc2->getArgument(0)->getUses()) {
      SILInstruction *Usr = Use->getUser();
      if (isa<ReleaseValueInst>(Usr) || isa<StrongReleaseInst>(Usr) ||
          isa<DestroyValueInst>(Usr)) {
        if (lastDestroy)
          return nullptr;
        lastDestroy = Usr;
      }
    }
    return lastDestroy;
  }();
  if (!onlyDestroy)
    return false;

  // Replace the convert_escape_to_noescape instruction.
  {
    SILBuilderWithScope B(Cvt);
    auto NewCvt = B.createConvertEscapeToNoEscape(
        Cvt->getLoc(), Cvt->getOperand(), Cvt->getType(), false, true);
    Cvt->replaceAllUsesWith(NewCvt);
    Cvt->eraseFromParent();
    Cvt = NewCvt;
  }

  // Extend the lifetime.
  SILBuilderWithScope B(SwitchEnum1);
  auto loc = RegularLocation::getAutoGeneratedLocation();
  auto copy =
      B.createCopyValue(loc, SwitchEnum1->getOperand());
  B.setInsertionPoint(onlyDestroy);
  B.createDestroyValue(loc, copy);
  return true;
}

static bool fixupConvertEscapeToNoEscapeLifetime(SILFunction &Fn) {
  bool Changed = false;

  // tryExtendLifetimeToLastUse uses a cache of recursive instruction use
  // queries.
  llvm::DenseMap<SILInstruction *, SILInstruction *> MemoizedQueries;

  for (auto &BB : Fn) {
    auto I = BB.begin();
    while (I != BB.end()) {
      SILInstruction *Inst = &*I;
      ++I;
      auto *Cvt = dyn_cast<ConvertEscapeToNoEscapeInst>(Inst);
      if (!Cvt || Cvt->isLifetimeGuaranteed())
        continue;

      // First try to peephole a known pattern.
      if (!DisableConvertEscapeToNoEscapeSwitchEnumPeephole &&
          trySwitchEnumPeephole(Cvt)) {
        Changed |= true;
        continue;
      }

      if (tryExtendLifetimeToLastUse(Cvt, MemoizedQueries)) {
        Changed |= true;
        continue;
      }

      // Otherwise, extend the lifetime of the operand to the end of the
      // function.
      extendLifetimeToEndOfFunction(Fn, Cvt);
      Changed |= true;
    }
  }
  return Changed;
}

/// Fix-up the lifetime of the escaping closure argument of
/// convert_escape_to_noescape [not_guaranteed] instructions.
///
/// convert_escape_to_noescape [not_guaranteed] assume that someone guarantees
/// the lifetime of the operand for the duration of the trivial closure result.
/// SILGen does not guarantee this for '[not_guaranteed]' instructions so we
/// ensure it here.
namespace {
class ClosureLifetimeFixup : public SILFunctionTransform {

  /// The entry point to the transformation.
  void run() override {
    // Don't rerun diagnostics on deserialized functions.
    if (getFunction()->wasDeserializedCanonical())
      return;

    // Fixup lifetimes of optional convertEscapeToNoEscape.
    if (fixupConvertEscapeToNoEscapeLifetime(*getFunction()))
      invalidateAnalysis(SILAnalysis::InvalidationKind::FunctionBody);
    DEBUG(getFunction()->verify());

  }

};
} // end anonymous namespace

SILTransform *swift::createClosureLifetimeFixup() {
  return new ClosureLifetimeFixup();
}
