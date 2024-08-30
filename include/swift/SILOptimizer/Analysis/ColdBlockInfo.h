//===--- ColdBlockInfo.h - Fast/slow path analysis for SIL CFG --*- C++ -*-===//
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

#ifndef SWIFT_SILOPTIMIZER_ANALYSIS_COLDBLOCKS_H
#define SWIFT_SILOPTIMIZER_ANALYSIS_COLDBLOCKS_H

#include "llvm/ADT/DenseMap.h"
#include "swift/SIL/SILValue.h"
#include <bitset>

namespace swift {
class DominanceAnalysis;
class PostDominanceAnalysis;
class SILBasicBlock;
class CondBranchInst;

/// Cache a set of basic blocks that have been determined to be cold or hot.
///
/// This does not inherit from SILAnalysis because it is not worth preserving
/// across passes.
class ColdBlockInfo {
public:
  // Represents the temperatures of edges flowing into a block.
  //
  //         T = "top" -- both warm and cold edges
  //        /  \
  //     Warm  Cold
  //        \  /
  //         B = "bottom" -- neither warm or cold edges
  struct State {
    // Each state kind, as an integer, is its position in any bit vectors.
    enum Temperature {
      Warm = 0,
      Cold = 1
    };

    // Number of states, excluding Top or Bottom, in this flow problem.
    static constexpr unsigned NumStates = 2;
  };

  using Energy = std::bitset<State::NumStates>;

private:
  DominanceAnalysis *DA;
  PostDominanceAnalysis *PDA;

  /// Each block in this map has been determined to be cold and/or warm.
  llvm::DenseMap<const SILBasicBlock*, Energy> EnergyMap;
  bool changedMap = false;

  // This is a cache and shouldn't be copied around.
  ColdBlockInfo(const ColdBlockInfo &) = delete;
  ColdBlockInfo &operator=(const ColdBlockInfo &) = delete;
  LLVM_DUMP_METHOD void dump() const;

  void resetToCold(const SILBasicBlock *BB);
  void set(const SILBasicBlock *BB, State::Temperature temp);

  using ExpectedValue = std::optional<bool>;

  void setExpectedCondition(CondBranchInst *CondBranch, ExpectedValue value);

  ExpectedValue searchForExpectedValue(SILValue Cond,
                                       unsigned recursionDepth = 0);
  void searchForExpectedValue(CondBranchInst *CondBranch);

public:
  ColdBlockInfo(DominanceAnalysis *DA, PostDominanceAnalysis *PDA);

  void analyze(SILFunction *F);

  bool isCold(const SILBasicBlock *BB) const;
};
} // end namespace swift

#endif
