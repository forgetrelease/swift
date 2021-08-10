//===--- SILGenDistributed.cpp - SILGen for distributed -------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "ArgumentSource.h"
#include "Conversion.h"
#include "ExecutorBreadcrumb.h"
#include "Initialization.h"
#include "LValue.h"
#include "RValue.h"
#include "SILGenFunction.h"
#include "SILGenFunctionBuilder.h"
#include "Scope.h"
#include "swift/AST/ASTMangler.h"
#include "swift/AST/ForeignErrorConvention.h"
#include "swift/AST/GenericEnvironment.h"
#include "swift/AST/ParameterList.h"
#include "swift/AST/PropertyWrappers.h"
#include "swift/Basic/Defer.h"
#include "swift/SIL/SILArgument.h"
#include "swift/SIL/SILUndef.h"
#include "swift/SIL/TypeLowering.h"

using namespace swift;
using namespace Lowering;

/******************************************************************************/
/****************** DISTRIBUTED ACTOR STORAGE INITIALIZATION ******************/
/******************************************************************************/

/// Get the `ActorTransport` parameter of the constructor.
/// Sema should have guaranteed that there is exactly one of them for any
/// designated initializer of a distributed actor.
static SILArgument*
getActorTransportArgument(ASTContext& C, SILFunction& F, ConstructorDecl *ctor) {
  auto *DC = cast<DeclContext>(ctor);
  auto module = DC->getParentModule();

  auto *transportProto =
      C.getProtocol(KnownProtocolKind::ActorTransport);
  Type transportTy = transportProto->getDeclaredInterfaceType();

  for (auto arg : F.getArguments()) {
    // TODO(distributed): also be able to locate a generic transport
    Type argTy = arg->getType().getASTType();
    auto argDecl = arg->getDecl();

    auto conformsToTransport = module->lookupConformance(
        argDecl->getInterfaceType(), transportProto);

    // Is it a protocol that conforms to ActorTransport?
    if (argTy->isEqual(transportTy) || conformsToTransport) {
      return arg;
    }

    // Is it some specific ActorTransport?
    auto result = module->lookupConformance(argTy, transportProto);
    if (!result.isInvalid()) {
      return arg;
    }
  }

  // did not find argument of ActorTransport type!
  llvm_unreachable("Missing required ActorTransport argument!");
}


static AbstractFunctionDecl*
lookupAssignIdentityFunc(ASTContext& C) {
  auto transportDecl = C.getActorTransportDecl();

  for (auto decl : transportDecl->lookupDirect(DeclName(C.Id_assignIdentity)))
    if (auto funcDecl = dyn_cast<AbstractFunctionDecl>(decl))
      return funcDecl;

    return nullptr;
}

/// Synthesize the actorTransport initialization:
///
/// \verbatim
/// // init(..., <transport>: ActorTransport) ... {
///     self.actorTransport = transport
/// // }
/// \endverbatim
static void
emitDistributedActorTransportInit(
    SILGenFunction &SGF,
    ManagedValue borrowedSelfArg, VarDecl *selfDecl,
    ConstructorDecl *ctor,
    Pattern *pattern, VarDecl *var) {
  auto &C = selfDecl->getASTContext();
  auto &B = SGF.B;
  auto &F = SGF.F;
  auto &SGM = SGF.SGM;
  SILGenFunctionBuilder builder(SGM);

  auto loc = SILLocation(ctor);
  loc.markAutoGenerated();

  // ==== Prepare assignment: get the self.transport address
  SILValue transportArgValue = getActorTransportArgument(C, F, ctor);
  ManagedValue transportArgManaged = ManagedValue::forUnmanaged(transportArgValue);
  auto transportDecl = C.getActorTransportDecl();

  // ----
  auto *selfTyDecl = ctor->getParent()->getSelfNominalTypeDecl();
  auto transportFieldAddr = B.createRefElementAddr(
      loc, borrowedSelfArg.getValue(), var,
      SGF.getLoweredType(var->getInterfaceType()));

  // ==== Store the transport
  B.createCopyAddr(loc,
                   /*src*/transportArgValue,
                   /*dest*/transportFieldAddr,
                   IsNotTake, IsInitialization);
}

/// Synthesize the distributed actor's identity (`id`) initialization:
///
/// \verbatim
/// // init(..., <transport>: ActorTransport) ... {
///     self.id = transport.assignIdentity(Self.self)
/// // }
/// \endverbatim
static void
emitDistributedActorIdentityInit(
    SILGenFunction &SGF,
    ManagedValue borrowedSelfArg, VarDecl *selfVarDecl,
    ConstructorDecl *ctor,
    Pattern *pattern, VarDecl *var) {
  auto &C = selfVarDecl->getASTContext();
  auto &B = SGF.B;
  auto &F = SGF.F;
  auto &SGM = SGF.SGM;
  SILGenFunctionBuilder builder(SGM);

  auto loc = SILLocation(ctor);
  loc.markAutoGenerated();

  // === prepare the transport.assignIdentity(_:) function

  AbstractFunctionDecl *assignIdentityFuncDecl = lookupAssignIdentityFunc(C);

  assert(assignIdentityFuncDecl && "Cannot find ActorTransport.assignIdentity!");
  auto assignIdentityFnRef = SILDeclRef(assignIdentityFuncDecl);

  // === Open the transport existential before call
  SILValue transportArgValue = getActorTransportArgument(C, F, ctor);
  SILValue selfArgValue = F.getSelfArgument();
  ProtocolDecl *distributedActorProto = C.getProtocol(KnownProtocolKind::DistributedActor);
  ProtocolDecl *transportProto = C.getProtocol(KnownProtocolKind::ActorTransport);
  assert(distributedActorProto);
  assert(transportProto);

  // --- open the transport existential
  OpenedArchetypeType *Opened;
  auto transportASTType = transportArgValue->getType().getASTType();
  auto openedTransportType =
      transportASTType->openAnyExistentialType(Opened)->getCanonicalType();
  auto openedTransportSILType = F.getLoweredType(openedTransportType);
  auto transportArchetypeValue = B.createOpenExistentialAddr(
      loc, transportArgValue, openedTransportSILType, OpenedExistentialAccess::Immutable);

  // --- prepare `Self.self` metatype
  auto *selfTyDecl = ctor->getParent()->getSelfNominalTypeDecl();
  // This would be bad: since not ok for generic
  // auto selfMetatype = SGF.getLoweredType(selfTyDecl->getInterfaceType());
  auto selfMetatype =
       SGF.getLoweredType(F.mapTypeIntoContext(selfTyDecl->getInterfaceType()));
  // selfVarDecl.getType() // TODO: do this; then dont need the self type decl
  SILValue selfMetatypeValue = B.createMetatype(loc, selfMetatype);

  // === Make the transport.assignIdentity call
  // --- prepare the witness_method
  // Note: it does not matter on what module we perform the lookup,
  // it is currently ignored. So the Stdlib module is good enough.
  auto *module = SGF.getModule().getSwiftModule();

  // the conformance here is just an abstract thing so we can simplify
  //  auto transportConfRef = module->lookupConformance(
  //      openedTransportType, transportProto);
  auto transportConfRef = ProtocolConformanceRef(transportProto);
  assert(!transportConfRef.isInvalid() && "Missing conformance to `ActorTransport`");

  auto selfTy = F.mapTypeIntoContext(selfTyDecl->getDeclaredInterfaceType()); // TODO: thats just self var devl getType

  auto distributedActorConfRef = module->lookupConformance(
      selfTy,
      distributedActorProto);
  assert(!distributedActorConfRef.isInvalid() && "Missing conformance to `DistributedActor`");

  //  auto anyActorIdentityDecl = C.getAnyActorIdentityDecl();

  auto assignIdentityMethod =
      cast<FuncDecl>(transportProto->getSingleRequirement(C.Id_assignIdentity));
  auto assignIdentityRef = SILDeclRef(assignIdentityMethod, SILDeclRef::Kind::Func);
  auto assignIdentitySILTy =
      SGF.getConstantInfo(SGF.getTypeExpansionContext(), assignIdentityRef)
          .getSILType();

  auto assignWitnessMethod = B.createWitnessMethod(
      loc,
      /*lookupTy*/openedTransportType,
      /*Conformance*/transportConfRef,
      /*member*/assignIdentityRef,
      /*methodTy*/assignIdentitySILTy);

  // --- prepare conformance subs
  auto genericSig = assignIdentityMethod->getGenericSignature();

  SubstitutionMap subs =
      SubstitutionMap::get(genericSig,
                           {openedTransportType, selfTy},
                           {transportConfRef, distributedActorConfRef});

  // --- create a temporary storage for the result of the call
  // it will be deallocated automatically as we exit this scope
  auto resultTy = SGF.getLoweredType(var->getInterfaceType());
  auto temp = SGF.emitTemporaryAllocation(loc, resultTy);

  // ---- actually call transport.assignIdentity(Self.self)
  B.createApply(
      loc, assignWitnessMethod, subs,
      { temp, selfMetatypeValue, transportArchetypeValue});

  // ==== Assign the identity to stored property

  // --- Prepare address of self.id
  auto idFieldAddr = B.createRefElementAddr(
      loc, borrowedSelfArg.getValue(), var,
      SGF.getLoweredType(var->getInterfaceType()));

  // --- assign to the property
  B.createCopyAddr(loc, /*src*/temp, /*dest*/idFieldAddr,
                   IsTake, IsInitialization);
}

void SILGenFunction::initializeDistributedActorImplicitStorageInit(
    ConstructorDecl *ctor, ManagedValue selfArg) {
  VarDecl *selfVarDecl = ctor->getImplicitSelfDecl();
  auto *dc = ctor->getDeclContext();
  auto classDecl = dc->getSelfClassDecl();
  auto &C = classDecl->getASTContext();

  // Only designated initializers get the lifecycle handling injected
  if (!ctor->isDesignatedInit()) {
    fprintf(stderr, "[%s:%d] (%s) NOT DESIGNATED INIT SKIP\n", __FILE__, __LINE__, __FUNCTION__);

    return;
  }

  SILLocation prologueLoc = RegularLocation(ctor);
  prologueLoc.markAsPrologue(); // TODO: no idea if this is necessary or makes sense

  auto transportTy = C.getActorTransportType();
  auto identityProtoTy = C.getActorIdentityType();
  auto anyIdentityTy = C.getAnyActorIdentityType();

  // ==== Find the stored properties we will initialize
  VarDecl *transportMember = nullptr;
  VarDecl *idMember = nullptr;

  auto borrowedSelfArg = selfArg.borrow(*this, prologueLoc);

  // TODO(distributed): getStoredProperties might be better here, avoid the `break;`
  for (auto member : classDecl->getMembers()) {
    PatternBindingDecl *pbd = dyn_cast<PatternBindingDecl>(member);
    if (!pbd) continue;
    if (pbd->isStatic()) continue;

    Pattern *pattern = pbd->getPattern(0);
    VarDecl *var = pbd->getSingleVar();
    if (!var) continue;

    if (var->getName() == C.Id_actorTransport &&
        var->getInterfaceType()->isEqual(transportTy)) {
      transportMember = var;
      emitDistributedActorTransportInit(*this, borrowedSelfArg, selfVarDecl, ctor, pattern, var);
    } else if (var->getName() == C.Id_id &&
               (var->getInterfaceType()->isEqual(identityProtoTy) ||
                var->getInterfaceType()->isEqual(anyIdentityTy))) { // TODO(distributed): stick one way to store, but today we can't yet store the existential
      idMember = var;
      emitDistributedActorIdentityInit(*this, borrowedSelfArg, selfVarDecl, ctor, pattern, var);
    }
    if (transportMember && idMember) {
      break; // we found all properties we care about, break out of the loop early
    }
  }

  assert(transportMember && "Missing DistributedActor.actorTransport member");
  assert(idMember && "Missing DistributedActor.id member");
}

void SILGenFunction::emitDistributedActorReady(
    ConstructorDecl *ctor, ManagedValue selfArg) {
  // TODO(distributed): implement actorReady call
}

/******************************************************************************/
/******************* DISTRIBUTED DEINIT: resignAddress ************************/
/******************************************************************************/

// TODO: implement calling resignAddress via a defer in deinit



/******************************************************************************/
/***************************** DISTRIBUTED THUNKS *****************************/
/******************************************************************************/

void SILGenFunction::emitDistributedThunk(SILDeclRef thunk) {
  // Check if actor is local or remote and call respective function
  //
  // func X_distributedThunk(...) async throws -> T {
  //   if __isRemoteActor(self) {
  //     return try await self._remote_X(...)
  //   } else {
  //     return try await self.X(...)
  //   }
  // }
  //

  assert(thunk.isDistributed);
  SILDeclRef native = thunk.asDistributed(false);
  auto fd = cast<AbstractFunctionDecl>(thunk.getDecl());

  ASTContext &ctx = getASTContext();

  // Use the same generic environment as the native entry point.
  F.setGenericEnvironment(SGM.Types.getConstantGenericEnvironment(native));

  auto loc = thunk.getAsRegularLocation();
  loc.markAutoGenerated();
  Scope scope(Cleanups, CleanupLocation(loc));

  auto isRemoteBB = createBasicBlock();
  auto isLocalBB = createBasicBlock();
  auto localErrorBB = createBasicBlock();
  auto remoteErrorBB = createBasicBlock();
  auto localReturnBB = createBasicBlock();
  auto remoteReturnBB = createBasicBlock();
  auto errorBB = createBasicBlock();
  auto returnBB = createBasicBlock();

  auto methodTy = SGM.Types.getConstantOverrideType(getTypeExpansionContext(),
                                                    thunk);
  auto derivativeFnSILTy = SILType::getPrimitiveObjectType(methodTy);
  auto silFnType = derivativeFnSILTy.castTo<SILFunctionType>();
  SILFunctionConventions fnConv(silFnType, SGM.M);
  auto resultType = fnConv.getSILResultType(getTypeExpansionContext());

  auto *selfVarDecl = fd->getImplicitSelfDecl();

  SmallVector<SILValue, 8> params;

  bindParametersForForwarding(fd->getParameters(), params);
  bindParameterForForwarding(selfVarDecl, params);
  auto selfValue = ManagedValue::forUnmanaged(params[params.size() - 1]);
  auto selfType = selfVarDecl->getType();

  // if __isRemoteActor(self) {
  //   ...
  // } else {
  //   ...
  // }
  {
    FuncDecl* isRemoteFn = ctx.getIsRemoteDistributedActor();
    assert(isRemoteFn &&
    "Could not find 'is remote' function, is the '_Distributed' module available?");

    ManagedValue selfAnyObject = B.createInitExistentialRef(loc, getLoweredType(ctx.getAnyObjectType()),
                                                            CanType(selfType),
                                                            selfValue, {});
    auto result = emitApplyOfLibraryIntrinsic(loc, isRemoteFn, SubstitutionMap(),
                                              {selfAnyObject}, SGFContext());

    SILValue isRemoteResult = std::move(result).forwardAsSingleValue(*this, loc);
    SILValue isRemoteResultUnwrapped = emitUnwrapIntegerResult(loc, isRemoteResult);

    B.createCondBranch(loc, isRemoteResultUnwrapped, isRemoteBB, isLocalBB);
  }

  // // if __isRemoteActor(self)
  // {
  //   return try await self._remote_X(...)
  // }
  {
    B.emitBlock(isRemoteBB);

    auto *selfTyDecl = FunctionDC->getParent()->getSelfNominalTypeDecl();
    assert(selfTyDecl && "distributed function declared outside of actor");

    auto remoteFnDecl = selfTyDecl->lookupDirectRemoteFunc(fd);
    assert(remoteFnDecl && "Could not find _remote_<dist_func_name> function");
    auto remoteFnRef = SILDeclRef(remoteFnDecl);

    SILGenFunctionBuilder builder(SGM);
    auto remoteFnSIL = builder.getOrCreateFunction(loc, remoteFnRef, ForDefinition);
    SILValue remoteFn = B.createFunctionRefFor(loc, remoteFnSIL);

    auto subs = F.getForwardingSubstitutionMap();

    SmallVector<SILValue, 8> remoteParams(params);

    B.createTryApply(loc, remoteFn, subs, remoteParams, remoteReturnBB, remoteErrorBB);
  }

  // // else
  // {
  //   return (try)? (await)? self.X(...)
  // }
  {
    B.emitBlock(isLocalBB);

    auto nativeMethodTy = SGM.Types.getConstantOverrideType(getTypeExpansionContext(),
                                                            native);
    auto nativeFnSILTy = SILType::getPrimitiveObjectType(nativeMethodTy);
    auto nativeSilFnType = nativeFnSILTy.castTo<SILFunctionType>();

    SILValue nativeFn = emitClassMethodRef(
        loc, params[params.size() - 1], native, nativeMethodTy);
    auto subs = F.getForwardingSubstitutionMap();

    if (nativeSilFnType->hasErrorResult()) {
      B.createTryApply(loc, nativeFn, subs, params, localReturnBB, localErrorBB);
    } else {
      auto result = B.createApply(loc, nativeFn, subs, params);
      B.createBranch(loc, returnBB, {result});
    }
  }

  {
    B.emitBlock(remoteErrorBB);
    SILValue error = remoteErrorBB->createPhiArgument(
        fnConv.getSILErrorType(getTypeExpansionContext()),
        OwnershipKind::Owned);

    B.createBranch(loc, errorBB, {error});
  }

  {
    B.emitBlock(localErrorBB);
    SILValue error = localErrorBB->createPhiArgument(
        fnConv.getSILErrorType(getTypeExpansionContext()),
        OwnershipKind::Owned);

    B.createBranch(loc, errorBB, {error});
  }

  {
    B.emitBlock(remoteReturnBB);
    SILValue result = remoteReturnBB->createPhiArgument(
        resultType, OwnershipKind::Owned);
    B.createBranch(loc, returnBB, {result});
  }

  {
    B.emitBlock(localReturnBB);
    SILValue result = localReturnBB->createPhiArgument(
        resultType, OwnershipKind::Owned);
    B.createBranch(loc, returnBB, {result});
  }

  // Emit return logic
  {
    B.emitBlock(returnBB);
    SILValue resArg = returnBB->createPhiArgument(
        resultType, OwnershipKind::Owned);
    B.createReturn(loc, resArg);
  }

  // Emit the rethrow logic.
  {
    B.emitBlock(errorBB);
    SILValue error = errorBB->createPhiArgument(
        fnConv.getSILErrorType(getTypeExpansionContext()),
        OwnershipKind::Owned);

    Cleanups.emitCleanupsForReturn(CleanupLocation(loc), IsForUnwind);
    B.createThrow(loc, error);
  }
}