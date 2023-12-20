//===--- SimplifyBeginBorrow.swift ----------------------------------------===//
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

import SIL

extension BeginBorrowInst : OnoneSimplifyable {
  func simplify(_ context: SimplifyContext) {
    if borrowedValue.ownership == .owned,
       // We need to keep lexical lifetimes in place.
       !isLexical,
       // The same for borrow-scopes which encapsulated pointer escapes.
       !findPointerEscapingUse(of: borrowedValue)
    {
      tryReplaceBorrowWithOwnedOperand(beginBorrow: self, context)
    }
  }
}

private func tryReplaceBorrowWithOwnedOperand(beginBorrow: BeginBorrowInst, _ context: SimplifyContext) {
  // The last value of a (potentially empty) forwarding chain, beginning at the `begin_borrow`.
  let forwardedValue = beginBorrow.lookThroughSingleForwardingUses()
  if forwardedValue.allUsesCanBeConvertedToOwned {
    if tryReplaceCopy(of: forwardedValue, withCopiedOperandOf: beginBorrow, context) {
      return
    }
    if beginBorrow.borrowedValue.isDestroyed(after: beginBorrow, context) {
      convertAllUsesToOwned(of: beginBorrow, context)
    }
  }
}

/// Replace
/// ```
///   %1 = begin_borrow %0
///   %2 = struct_extract %1     // a chain of forwarding instructions
///   %3 = copy_value %1
///   // ... uses of %3
///   end_borrow %1
/// ```
/// with
/// ```
///   %1 = copy_value %0
///   %3 = destructure_struct %0 // owned version of the forwarding instructions
///   // ... uses of %3
/// ```
private func tryReplaceCopy(
  of forwardedValue: Value,
  withCopiedOperandOf beginBorrow: BeginBorrowInst,
  _ context: SimplifyContext
) -> Bool {
  guard let singleUser = forwardedValue.uses.ignoreUsers(ofType: EndBorrowInst.self).singleUse?.instruction,
        let copy = singleUser as? CopyValueInst,
        copy.parentBlock == beginBorrow.parentBlock else {
    return false
  }
  let builder = Builder(before: beginBorrow, context)
  let copiedOperand = builder.createCopyValue(operand: beginBorrow.borrowedValue)
  let forwardedOwnedValue = replace(guaranteedValue: beginBorrow, withOwnedValue: copiedOperand, context)
  copy.uses.replaceAll(with: forwardedOwnedValue, context)
  context.erase(instruction: copy)
  context.erase(instructionIncludingAllUsers: beginBorrow)
  return true
}

/// Replace
/// ```
///   %1 = begin_borrow %0
///   %2 = struct_extract %1     // a chain of forwarding instructions
///   // ... uses of %2
///   end_borrow %1
///   destroy_value %1           // the only other use of %0 beside begin_borrow
/// ```
/// with
/// ```
///   %2 = destructure_struct %0 // owned version of the forwarding instructions
///   // ... uses of %2
///   destroy_value %2
/// ```
private func convertAllUsesToOwned(of beginBorrow: BeginBorrowInst, _ context: SimplifyContext) {
  let forwardedOwnedValue = replace(guaranteedValue: beginBorrow, withOwnedValue: beginBorrow.borrowedValue, context)
  beginBorrow.borrowedValue.replaceAllDestroys(with: forwardedOwnedValue, context)
  context.erase(instructionIncludingAllUsers: beginBorrow)
}

private extension Value {
  /// Returns the last value of a (potentially empty) forwarding chain.
  /// For example, returns %3 for the following def-use chain:
  /// ```
  ///   %1 = struct_extract %self, #someField
  ///   %2 = tuple_extract %1, 0
  ///   %3 = struct $S(%2)   // %3 has no forwarding users
  /// ```
  /// Returns self if this value has no uses which are ForwardingInstructions.
  func lookThroughSingleForwardingUses() -> Value {
    if let singleUse = uses.ignoreUsers(ofType: EndBorrowInst.self).singleUse,
       let fwdInst = singleUse.instruction as? (SingleValueInstruction & ForwardingInstruction),
       fwdInst.canConvertToOwned,
       fwdInst.isSingleForwardedOperand(singleUse),
       fwdInst.parentBlock == parentBlock
    {
      return fwdInst.lookThroughSingleForwardingUses()
    }
    return self
  }

  var allUsesCanBeConvertedToOwned: Bool {
    let relevantUses = uses.ignoreUsers(ofType: EndBorrowInst.self)
    return relevantUses.allSatisfy { $0.canAccept(ownership: .owned) }
  }

  func isDestroyed(after nonDestroyUser: Instruction, _ context: SimplifyContext) -> Bool {
    if uses.getSingleUser(notOfType: DestroyValueInst.self) != nonDestroyUser {
      return false
    }
    let dominatorTree = context.dominatorTree
    let nonDestroyBlock = nonDestroyUser.parentBlock
    for use in uses {
      if use.instruction == nonDestroyUser {
        continue
      }
      if !nonDestroyBlock.dominates(use.instruction.parentBlock, dominatorTree) {
        return false
      }
    }
    return true
  }

  func replaceAllDestroys(with replacement: Value, _ context: SimplifyContext) {
    uses.filterUsers(ofType: DestroyValueInst.self).replaceAll(with: replacement, context)
  }
}

private extension ForwardingInstruction {
  func isSingleForwardedOperand(_ operand: Operand) -> Bool {
    switch self {
    case is StructInst, is TupleInst:
      // TODO: we could move that logic to StructInst/TupleInst.singleForwardedOperand.
      return operands.lazy.map({ $0.value.type }).hasSingleNonTrivialElement(at: operand.index, in: parentFunction)
    default:
      if let sfo = singleForwardedOperand {
        return sfo == operand
      }
      return false
    }
  }
}

/// Replaces a guaranteed value with an owned value.
/// 
/// If the `guaranteedValue`'s use is a ForwardingInstruction (or forwarding instruction chain),
/// it is converted to an owned version of the forwarding instruction (or instruction chain).
///
/// Returns the last owned value in a forwarding-chain or `ownedValue` if `guaranteedValue` has
/// no forwarding uses.
private func replace(guaranteedValue: Value, withOwnedValue ownedValue: Value, _ context: SimplifyContext) -> Value {
  var result = ownedValue
  var numForwardingUses = 0
  for use in guaranteedValue.uses {

    switch use.instruction {
    case let tei as TupleExtractInst:
      numForwardingUses += 1
      let dti = Builder(before: tei, context).createDestructureTuple(tuple: ownedValue)
      result = replace(guaranteedValue: tei, withOwnedValue: dti.results[tei.fieldIndex], context)
      context.erase(instruction: tei)
    case let sei as StructExtractInst:
      numForwardingUses += 1
      let dsi = Builder(before: sei, context).createDestructureStruct(struct: ownedValue)
      result = replace(guaranteedValue: sei, withOwnedValue: dsi.results[sei.fieldIndex], context)
      context.erase(instruction: sei)
    case let fwdInst as (SingleValueInstruction & ForwardingInstruction) where
         fwdInst.isSingleForwardedOperand(use):
      // Other forwarding instructions beside tuple_extract and struct_extract
      numForwardingUses += 1
      use.set(to: ownedValue, context)
      fwdInst.setForwardingOwnership(to: .owned, context)
      result = replace(guaranteedValue: fwdInst, withOwnedValue: fwdInst, context)
    case is EndBorrowInst:
      break
    default:
      precondition(use.canAccept(ownership: .owned))
      use.set(to: ownedValue, context)
    }
  }
  precondition(numForwardingUses <= 1, "guaranteed value must not have multiple forwarding uses")
  return result
}

private extension ForwardingInstruction {
  var canConvertToOwned: Bool {
    switch self {
    case let si as StructExtractInst:
      if si.struct.type.isMoveOnly {
        // We cannot easily convert a struct_extract to a destructure_struct of a move-only type, because
        // the deinit would get lost.
        return false
      }
      let structFields = si.struct.type.getNominalFields(in: parentFunction)
      return structFields?.hasSingleNonTrivialElement(at: si.fieldIndex, in: parentFunction) ?? false
    case let ti as TupleExtractInst:
      return ti.tuple.type.tupleElements.hasSingleNonTrivialElement(at: ti.fieldIndex, in: parentFunction)
    default:
      return canForwardOwnedValues
    }
  }
}

private extension Collection where Element == Type {
  func hasSingleNonTrivialElement(at nonTrivialElementIndex: Int, in function: Function) -> Bool {
    for (elementIdx, elementTy) in self.enumerated() {
      if elementTy.isTrivial(in: function) != (elementIdx != nonTrivialElementIndex) {
        return false
      }
    }
    return true
  }
}
