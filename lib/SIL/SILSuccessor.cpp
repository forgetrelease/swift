//===--- SILSuccessor.cpp - Implementation of SILSuccessor.h --------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - current Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/SIL/SILSuccessor.h"
#include "swift/SIL/SILBasicBlock.h"
using namespace swift;

void SILSuccessor::operator=(SILBasicBlock *BB) {
  // If we're not changing anything, we're done.
  if (SuccessorBlock == BB) return;
  
  assert(ContainingInst &&"init method not called after default construction?");
  
  // If we were already pointing to a basic block, remove ourself from its
  // predecessor list.
  if (SuccessorBlock) {
    *Prev = Next;
    if (Next) Next->Prev = Prev;
  }
  
  // If we have a successor, add ourself to its prev list.
  if (BB) {
    Prev = &BB->PredList;
    Next = BB->PredList;
    if (Next) Next->Prev = &Next;
    BB->PredList = this;
  }
  
  SuccessorBlock = BB;
}

// Dereferencing the pred_iterator returns the predecessor's SILBasicBlock.
SILBasicBlock *SILSuccessor::pred_iterator::operator*() {
  assert(Cur && "Can't deference end (or default constructed) iterator");
  return Cur->ContainingInst->getParent();
}

// Dereferencing the pred_iterator returns the predecessor's SILBasicBlock.
const SILBasicBlock *SILSuccessor::pred_iterator::operator*() const {
  assert(Cur && "Can't deference end (or default constructed) iterator");
  return Cur->ContainingInst->getParent();
}
