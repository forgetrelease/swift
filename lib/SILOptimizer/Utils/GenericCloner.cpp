//===--- GenericCloner.cpp - Specializes generic functions  ---------------===//
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

#include "swift/SILOptimizer/Utils/GenericCloner.h"

#include "swift/AST/Type.h"
#include "swift/SIL/OwnershipUtils.h"
#include "swift/SIL/SILArgument.h"
#include "swift/SIL/SILBasicBlock.h"
#include "swift/SIL/SILFunction.h"
#include "swift/SIL/SILInstruction.h"
#include "swift/SIL/SILModule.h"
#include "swift/SIL/SILValue.h"
#include "swift/SIL/ScopedAddressUtils.h"
#include "swift/SILOptimizer/Utils/InstOptUtils.h"
#include "swift/SILOptimizer/Utils/SILOptFunctionBuilder.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"

using namespace swift;

/// Create a new empty function with the correct arguments and a unique name.
SILFunction *GenericCloner::createDeclaration(
    SILOptFunctionBuilder &FunctionBuilder, SILFunction *Orig,
    const ReabstractionInfo &ReInfo, StringRef NewName) {
  assert((!ReInfo.isSerialized() || Orig->isSerialized())
         && "Specialization cannot make body more resilient");
  assert((Orig->isTransparent() || Orig->isBare() || Orig->getLocation())
         && "SILFunction missing location");
  assert((Orig->isTransparent() || Orig->isBare() || Orig->getDebugScope())
         && "SILFunction missing DebugScope");
  assert(!Orig->isGlobalInit() && "Global initializer cannot be cloned");

  // Create a new empty function.
  SILFunction *NewF = FunctionBuilder.createFunction(
      getSpecializedLinkage(Orig, Orig->getLinkage()), NewName,
      ReInfo.getSpecializedType(), ReInfo.getSpecializedGenericEnvironment(),
      Orig->getLocation(), Orig->isBare(), Orig->isTransparent(),
      ReInfo.isSerialized(), IsNotDynamic, IsNotDistributed,
      IsNotRuntimeAccessible, Orig->getEntryCount(), Orig->isThunk(),
      Orig->getClassSubclassScope(), Orig->getInlineStrategy(),
      Orig->getEffectsKind(), Orig, Orig->getDebugScope());
  for (auto &Attr : Orig->getSemanticsAttrs()) {
    NewF->addSemanticsAttr(Attr);
  }
  if (!Orig->hasOwnership()) {
    NewF->setOwnershipEliminated();
  }
  NewF->copyEffects(Orig);
  return NewF;
}

void GenericCloner::populateCloned() {
  assert(AllocStacks.empty() && "Stale cloner state.");
  assert(!ReturnValueAddr && "Stale cloner state.");

  SILFunction *Cloned = getCloned();
  // Create arguments for the entry block.
  SILBasicBlock *OrigEntryBB = &*Original.begin();
  SILBasicBlock *ClonedEntryBB = Cloned->createBasicBlock();
  getBuilder().setInsertionPoint(ClonedEntryBB);

  // Create the entry basic block with the function arguments.
  auto origConv = Original.getConventions();
  unsigned ArgIdx = 0;
  SmallVector<SILValue, 4> entryArgs;
  entryArgs.reserve(OrigEntryBB->getArguments().size());
  for (auto &OrigArg : OrigEntryBB->getArguments()) {
    RegularLocation Loc = OrigArg->getDecl() ?
      RegularLocation((Decl *)OrigArg->getDecl()) :
      RegularLocation::getAutoGeneratedLocation();
    AllocStackInst *ASI = nullptr;
    SILType mappedType = remapType(OrigArg->getType());

    auto createAllocStack = [&]() {
      // We need an alloc_stack as a replacement for the indirect parameter.
      if (mappedType.isAddress()) {
        mappedType = mappedType.getObjectType();
      }
      auto AllocStackLoc = RegularLocation::getAutoGeneratedLocation();
      ASI = getBuilder().createAllocStack(AllocStackLoc, mappedType);
      AllocStacks.push_back(ASI);
    };
    auto handleConversion = [&]() {
      if (!origConv.useLoweredAddresses())
        return false;

      if (ArgIdx < origConv.getSILArgIndexOfFirstParam()) {
        // Handle result arguments.
        unsigned formalIdx =
            origConv.getIndirectFormalResultIndexForSILArg(ArgIdx);
        if (ReInfo.isFormalResultConverted(formalIdx)) {
          // This result is converted from indirect to direct. The return inst
          // needs to load the value from the alloc_stack. See below.
          createAllocStack();
          assert(!ReturnValueAddr);
          ReturnValueAddr = ASI;
          entryArgs.push_back(ASI);
          return true;
        }
      } else if (ReInfo.isDroppedMetatypeArg(ArgIdx)) {
        // Replace the metatype argument with an `metatype` instruction in the
        // entry block.
        auto *mtInst = getBuilder().createMetatype(Loc, mappedType);
        entryArgs.push_back(mtInst);
        return true;
      } else {
        // Handle arguments for formal parameters.
        unsigned paramIdx = ArgIdx - origConv.getSILArgIndexOfFirstParam();
        if (ReInfo.isParamConverted(paramIdx)) {
          assert(mappedType.isAddress());
          mappedType = mappedType.getObjectType();
          auto *NewArg = ClonedEntryBB->createFunctionArgument(
              mappedType, OrigArg->getDecl());
          NewArg->copyFlags(cast<SILFunctionArgument>(OrigArg));

          // Try to create a new debug_value from an existing debug_value w/
          // address value for the argument. We do this before storing to
          // ensure that when we are cloning code in ossa the argument has
          // not been consumed by the store below.
          for (Operand *ArgUse : OrigArg->getUses()) {
            if (auto *DVI = DebugValueInst::hasAddrVal(ArgUse->getUser())) {
              auto *oldScope = getBuilder().getCurrentDebugScope();
              getBuilder().setCurrentDebugScope(
                  remapScope(DVI->getDebugScope()));
              auto VarInfo = DVI->getVarInfo();
              assert(VarInfo && VarInfo->DIExpr &&
                     "No DebugVarInfo or no DIExpr operand?");
              // Drop the op_deref
              VarInfo->DIExpr = VarInfo->DIExpr->dropDeref(DVI->getModule());
              getBuilder().createDebugValue(DVI->getLoc(), NewArg, *VarInfo);
              getBuilder().setCurrentDebugScope(oldScope);
              break;
            }
          }

          // Store the new direct parameter to an alloc_stack.
          createAllocStack();
          SILValue addr;
          if (NewArg->getArgumentConvention().isGuaranteedConvention() &&
              NewArg->getFunction()->hasOwnership()) {
            auto *sbi = getBuilder().createStoreBorrow(Loc, NewArg, ASI);
            StoreBorrowsToCleanup.push_back(sbi);
            addr = sbi;
          } else {
            getBuilder().emitStoreValueOperation(Loc, NewArg, ASI,
                                                 StoreOwnershipQualifier::Init);
            addr = ASI;
          }

          entryArgs.push_back(addr);
          return true;
        }
      }
      return false; // No conversion.
    };
    if (!handleConversion()) {
      auto *NewArg =
          ClonedEntryBB->createFunctionArgument(mappedType, OrigArg->getDecl());
      NewArg->copyFlags(cast<SILFunctionArgument>(OrigArg));
      entryArgs.push_back(NewArg);
    }
    ++ArgIdx;
  }

  // Visit original BBs in depth-first preorder, starting with the
  // entry block, cloning all instructions and terminators.
  cloneFunctionBody(&Original, ClonedEntryBB, entryArgs);
}

void GenericCloner::visitTerminator(SILBasicBlock *BB) {
  TermInst *OrigTermInst = BB->getTerminator();
  if (auto *RI = dyn_cast<ReturnInst>(OrigTermInst)) {
    SILValue ReturnValue;
    if (ReturnValueAddr) {
      // The result is converted from indirect to direct. We have to load the
      // returned value from the alloc_stack.
      ReturnValue = getBuilder().emitLoadValueOperation(
          ReturnValueAddr->getLoc(), ReturnValueAddr,
          LoadOwnershipQualifier::Take);
    }
    for (AllocStackInst *ASI : reverse(AllocStacks)) {
      getBuilder().createDeallocStack(ASI->getLoc(), ASI);
    }
    if (ReturnValue) {
      auto *NewReturn = getBuilder().createReturn(RI->getLoc(), ReturnValue);
      FunctionExits.push_back(NewReturn);
      return;
    }
  } else if (OrigTermInst->isFunctionExiting()) {
    for (AllocStackInst *ASI : reverse(AllocStacks)) {
      getBuilder().createDeallocStack(ASI->getLoc(), ASI);
    }
  }
  visit(OrigTermInst);
}

const SILDebugScope *GenericCloner::remapScope(const SILDebugScope *DS) {
  if (!DS)
    return nullptr;
  auto it = RemappedScopeCache.find(DS);
  if (it != RemappedScopeCache.end())
    return it->second;

  auto &M = getBuilder().getModule();
  auto *ParentFunction = DS->Parent.dyn_cast<SILFunction *>();
  if (ParentFunction == &Original)
    ParentFunction = getCloned();
  else if (ParentFunction)
    ParentFunction = remapParentFunction(
        FuncBuilder, M, ParentFunction, SubsMap,
        Original.getLoweredFunctionType()->getInvocationGenericSignature());

  auto *ParentScope = DS->Parent.dyn_cast<const SILDebugScope *>();
  auto *RemappedScope =
      new (M) SILDebugScope(DS->Loc, ParentFunction, remapScope(ParentScope),
                            remapScope(DS->InlinedCallSite));
  RemappedScopeCache.insert({DS, RemappedScope});
  return RemappedScope;
}

void GenericCloner::postFixUp(SILFunction *f) {
  for (auto *apply : noReturnApplies) {
    auto applyBlock = apply->getParent();
    applyBlock->split(std::next(SILBasicBlock::iterator(apply)));
    getBuilder().setInsertionPoint(applyBlock);
    getBuilder().createUnreachable(apply->getLoc());
  }

  SmallVector<SILBasicBlock *, 4> discoveredBlocks;
  for (auto *sbi : StoreBorrowsToCleanup) {
    ScopedAddressValue scopedAddress(sbi);
    if (scopedAddress->getUses().empty()) {
      scopedAddress.createScopeEnd(sbi->getNextInstruction()->getIterator(),
                                   RegularLocation::getAutoGeneratedLocation());
      continue;
    }
    discoveredBlocks.clear();
    // FIXME: Call OSSA lifetime fixup on all values used within the unreachable
    // code. This will recursively fixup nested scopes from the inside out so
    // that transitive liveness is not required.
    SSAPrunedLiveness storeBorrowLiveness(&discoveredBlocks);
    AddressUseKind useKind =
        scopedAddress.computeTransitiveLiveness(storeBorrowLiveness);
    if (useKind == AddressUseKind::NonEscaping) {
      scopedAddress.endScopeAtLivenessBoundary(&storeBorrowLiveness);
      continue;
    }
    auto *alloc = cast<AllocStackInst>(sbi->getDest());
    for (auto *dealloc : alloc->getUsersOfType<DeallocStackInst>()) {
      scopedAddress.createScopeEnd(dealloc->getIterator(),
                                   RegularLocation::getAutoGeneratedLocation());
    }
  }
}
