//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftShims

@inlinable @inline(__always) // top-level fastest-paths
@_effects(readonly)
internal func _stringCompare(
  _ lhs: _StringGuts, _ rhs: _StringGuts, expecting: _StringComparisonResult
) -> Bool {
  if lhs.rawBits == rhs.rawBits { return expecting == .equal }
  return _stringCompareWithSmolCheck(lhs, rhs, expecting: expecting)
}

@usableFromInline
@_effects(readonly)
internal func _stringCompareWithSmolCheck(
  _ lhs: _StringGuts, _ rhs: _StringGuts, expecting: _StringComparisonResult
) -> Bool {
  // ASCII small-string fast-path:
  if lhs.isSmallASCII && rhs.isSmallASCII {
    let lhsRaw = lhs.asSmall._storage
    let rhsRaw = rhs.asSmall._storage

    if lhsRaw.0 != rhsRaw.0 {
      return _lexicographicalCompare(
        lhsRaw.0.byteSwapped, rhsRaw.0.byteSwapped, expecting: expecting)
    }
    return _lexicographicalCompare(
      lhsRaw.1.byteSwapped, rhsRaw.1.byteSwapped, expecting: expecting)
  }

  return _stringCompareInternal(lhs, rhs, expecting: expecting)
}

@inline(never) // Keep `_stringCompareWithSmolCheck` fast-path fast
@usableFromInline
@_effects(readonly)
internal func _stringCompareInternal(
  _ lhs: _StringGuts, _ rhs: _StringGuts, expecting: _StringComparisonResult
) -> Bool {
  guard _fastPath(lhs.isFastUTF8 && rhs.isFastUTF8) else {
    return _stringCompareSlow(lhs, rhs, expecting: expecting)
  }

  let isNFC = lhs.isNFC && rhs.isNFC
  return lhs.withFastUTF8 { lhsUTF8 in
    return rhs.withFastUTF8 { rhsUTF8 in
      return _stringCompareFastUTF8(
        lhsUTF8, rhsUTF8, expecting: expecting, bothNFC: isNFC)
    }
  }
}

@inlinable @inline(__always) // top-level fastest-paths
@_effects(readonly)
internal func _stringCompare(
  _ lhs: _StringGuts, _ lhsRange: Range<Int>,
  _ rhs: _StringGuts, _ rhsRange: Range<Int>,
  expecting: _StringComparisonResult
) -> Bool {
  if lhs.rawBits == rhs.rawBits && lhsRange == rhsRange {
    return expecting == .equal
  }
  return _stringCompareInternal(
    lhs, lhsRange, rhs, rhsRange, expecting: expecting)
}

@usableFromInline
@_effects(readonly)
internal func _stringCompareInternal(
  _ lhs: _StringGuts, _ lhsRange: Range<Int>,
  _ rhs: _StringGuts, _ rhsRange: Range<Int>,
  expecting: _StringComparisonResult
) -> Bool {
  guard _fastPath(lhs.isFastUTF8 && rhs.isFastUTF8) else {
    return _stringCompareSlow(
      lhs, lhsRange, rhs, rhsRange, expecting: expecting)
  }

  let isNFC = lhs.isNFC && rhs.isNFC
  return lhs.withFastUTF8(range: lhsRange) { lhsUTF8 in
    return rhs.withFastUTF8(range: rhsRange) { rhsUTF8 in
      return _stringCompareFastUTF8(
        lhsUTF8, rhsUTF8, expecting: expecting, bothNFC: isNFC)
    }
  }
}

@_effects(readonly)
private func _stringCompareFastUTF8(
  _ utf8Left: UnsafeBufferPointer<UInt8>,
  _ utf8Right: UnsafeBufferPointer<UInt8>,
  expecting: _StringComparisonResult,
  bothNFC: Bool
) -> Bool {
  if _fastPath(bothNFC) {
    let cmp = _binaryCompare(utf8Left, utf8Right)
    return _lexicographicalCompare(cmp, 0, expecting: expecting)
  }

  return _stringCompareFastUTF8Abnormal(
    utf8Left, utf8Right, expecting: expecting)
}

@_effects(readonly)
private func _stringCompareFastUTF8Abnormal(
  _ utf8Left: UnsafeBufferPointer<UInt8>,
  _ utf8Right: UnsafeBufferPointer<UInt8>,
  expecting: _StringComparisonResult
) -> Bool {
  // Do a binary-equality prefix scan, to skip over long common prefixes.
  guard let diffIdx = _findDiffIdx(utf8Left, utf8Right) else {
    // We finished one of our inputs.
    //
    // TODO: This gives us a consistent and good ordering, but technically it
    // could differ from our stated ordering if combination with a prior scalar
    // did not produce a greater-value scalar. Consider checking normality.
    return _lexicographicalCompare(
      utf8Left.count, utf8Right.count, expecting: expecting)
  }

  let scalarDiffIdx = _scalarAlign(utf8Left, diffIdx)
  _internalInvariant(scalarDiffIdx == _scalarAlign(utf8Right, diffIdx))

  let (leftScalar, leftLen) = _decodeScalar(utf8Left, startingAt: scalarDiffIdx)
  let (rightScalar, rightLen) = _decodeScalar(
    utf8Right, startingAt: scalarDiffIdx)

  // Very frequent fast-path: point of binary divergence is a NFC single-scalar
  // segment. Check that we diverged at the start of a segment, and the next
  // scalar is both NFC and its own segment.
  if _fastPath(
    leftScalar._isNFCStarter && rightScalar._isNFCStarter &&
    utf8Left.hasNormalizationBoundary(before: scalarDiffIdx &+ leftLen) &&
    utf8Right.hasNormalizationBoundary(before: scalarDiffIdx &+ rightLen)
  ) {
    guard expecting == .less else {
      // We diverged
      _internalInvariant(expecting == .equal)
      return false
    }
    return _lexicographicalCompare(
      leftScalar.value, rightScalar.value, expecting: .less)
  }

  // Back up to the nearest normalization boundary before doing a slow
  // normalizing compare.
  let boundaryIdx = Swift.min(
    _findBoundary(utf8Left, before: diffIdx),
    _findBoundary(utf8Right, before: diffIdx))
  _internalInvariant(boundaryIdx <= diffIdx)

  return _stringCompareSlow(
    UnsafeBufferPointer(rebasing: utf8Left[boundaryIdx...]),
    UnsafeBufferPointer(rebasing: utf8Right[boundaryIdx...]),
    expecting: expecting)
}

@_effects(readonly)
private func _stringCompareSlow(
  _ lhs: _StringGuts, _ rhs: _StringGuts, expecting: _StringComparisonResult
) -> Bool {
  return _stringCompareSlow(
    lhs, 0..<lhs.count, rhs, 0..<rhs.count, expecting: expecting)
}

@_effects(readonly)
private func _stringCompareSlow(
  _ lhs: _StringGuts, _ lhsRange: Range<Int>,
  _ rhs: _StringGuts, _ rhsRange: Range<Int>,
  expecting: _StringComparisonResult
) -> Bool {
  // TODO: Just call the normalizer directly with range

  return _StringGutsSlice(lhs, lhsRange).compare(
    with: _StringGutsSlice(rhs, rhsRange),
    expecting: expecting)
}

@_effects(readonly)
private func _stringCompareSlow(
  _ leftUTF8: UnsafeBufferPointer<UInt8>,
  _ rightUTF8: UnsafeBufferPointer<UInt8>,
  expecting: _StringComparisonResult
) -> Bool {
  // TODO: Just call the normalizer directly

  let left = _StringGutsSlice(_StringGuts(leftUTF8, isASCII: false))
  let right = _StringGutsSlice(_StringGuts(rightUTF8, isASCII: false))
  return left.compare(with: right, expecting: expecting)
}

// Return the point of binary divergence. If they have no binary difference
// (even if one is longer), returns nil.
@_effects(readonly)
private func _findDiffIdx(
  _ left: UnsafeBufferPointer<UInt8>, _ right: UnsafeBufferPointer<UInt8>
) -> Int? {
  let count = Swift.min(left.count, right.count)
  var idx = 0
  while idx < count {
    guard left[_unchecked: idx] == right[_unchecked: idx] else {
      return idx
    }
    idx &+= 1
  }
  return nil
}

@_effects(readonly)
@inline(__always)
private func _lexicographicalCompare<I: FixedWidthInteger>(
  _ lhs: I, _ rhs: I, expecting: _StringComparisonResult
) -> Bool {
  return expecting == .equal ? lhs == rhs : lhs < rhs
}

@_effects(readonly)
private func _findBoundary(
  _ utf8: UnsafeBufferPointer<UInt8>, before: Int
) -> Int {
  var idx = before
  _internalInvariant(idx >= 0)

  // End of string is a normalization boundary
  guard idx < utf8.count else {
    _internalInvariant(before == utf8.count)
    return utf8.count
  }

  // Back up to scalar boundary
  while _isContinuation(utf8[_unchecked: idx]) {
    idx &-= 1
  }

  while true {
    if idx == 0 { return 0 }

    let scalar = _decodeScalar(utf8, startingAt: idx).0
    if scalar._hasNormalizationBoundaryBefore { return idx }

    idx &-= _utf8ScalarLength(utf8, endingAt: idx)
  }
}

@_frozen
@usableFromInline
internal enum _StringComparisonResult {
  case equal
  case less

  @inlinable @inline(__always)
  internal init(signedNotation int: Int) {
    _internalInvariant(int <= 0)
    self = int == 0 ? .equal : .less
  }

  @inlinable @inline(__always)
  static func ==(
    _ lhs: _StringComparisonResult, _ rhs: _StringComparisonResult
  ) -> Bool {
    switch (lhs, rhs) {
      case (.equal, .equal): return true
      case (.less, .less): return true
      default: return false
    }
  }
}

// Perform a binary comparison of bytes in memory. Return value is negative if
// less, 0 if equal, positive if greater.
@_effects(readonly)
internal func _binaryCompare<UInt8>(
  _ lhs: UnsafeBufferPointer<UInt8>, _ rhs: UnsafeBufferPointer<UInt8>
) -> Int {
  var cmp = Int(truncatingIfNeeded:
    _swift_stdlib_memcmp(
      lhs.baseAddress._unsafelyUnwrappedUnchecked,
      rhs.baseAddress._unsafelyUnwrappedUnchecked,  
      Swift.min(lhs.count, rhs.count)))
  if cmp == 0 {
    cmp = lhs.count &- rhs.count
  }
  return cmp
}

// Double dispatch functions
extension _StringGutsSlice {
  @_effects(readonly)
  internal func compare(
    with other: _StringGutsSlice, expecting: _StringComparisonResult
  ) -> Bool {
    if _fastPath(self.isFastUTF8 && other.isFastUTF8) {
      Builtin.onFastPath() // aggressively inline / optimize
      let isEqual = self.withFastUTF8 { utf8Self in
        return other.withFastUTF8 { utf8Other in
          return 0 == _binaryCompare(utf8Self, utf8Other)
        }
      }
      if isEqual { return expecting == .equal }
    }

    return _slowCompare(with: other, expecting: expecting)
  }

  @inline(never) // opaque slow-path
  @_effects(readonly)
  internal func _slowCompare(
    with other: _StringGutsSlice,
    expecting: _StringComparisonResult
  ) -> Bool {
    var left_output = _FixedArray16<UInt8>(allZeros: ())
    var left_icuInput = _FixedArray16<UInt16>(allZeros: ())
    var left_icuOutput = _FixedArray16<UInt16>(allZeros: ())
    var right_output = _FixedArray16<UInt8>(allZeros: ())
    var right_icuInput = _FixedArray16<UInt16>(allZeros: ())
    var right_icuOutput = _FixedArray16<UInt16>(allZeros: ())
    if _fastPath(self.isFastUTF8 && other.isFastUTF8) {
      return self.withFastUTF8 { leftUTF8 in
        other.withFastUTF8 { rightUTF8 in
          let leftStartIndex = String.Index(encodedOffset: 0)
          let rightStartIndex = String.Index(encodedOffset: 0)
          let leftEndIndex = String.Index(encodedOffset: leftUTF8.count)
          let rightEndIndex = String.Index(encodedOffset: rightUTF8.count)
          return _normalizedCompareImpl(
            left_outputBuffer: _castOutputBuffer(&left_output),
            left_icuInputBuffer: _castOutputBuffer(&left_icuInput),
            left_icuOutputBuffer: _castOutputBuffer(&left_icuOutput),
            right_outputBuffer: _castOutputBuffer(&right_output),
            right_icuInputBuffer: _castOutputBuffer(&right_icuInput),
            right_icuOutputBuffer: _castOutputBuffer(&right_icuOutput),
            left_range: leftStartIndex..<leftEndIndex,
            right_range: rightStartIndex..<rightEndIndex,
            expecting: expecting,
            normalizeLeft: { readIndex, outputBuffer, icuInputBuffer, icuOutputBuffer in
              _fastNormalize(
                readIndex: readIndex,
                sourceBuffer: leftUTF8,
                outputBuffer: &outputBuffer,
                icuInputBuffer: &icuInputBuffer,
                icuOutputBuffer: &icuOutputBuffer)
            },
            normalizeRight: { readIndex, outputBuffer, icuInputBuffer, icuOutputBuffer in
              _fastNormalize(
                readIndex: readIndex,
                sourceBuffer: rightUTF8,
                outputBuffer: &outputBuffer,
                icuInputBuffer: &icuInputBuffer,
                icuOutputBuffer: &icuOutputBuffer)
            })
        }
      }
    } else {
      return _normalizedCompareImpl(
        left_outputBuffer: _castOutputBuffer(&left_output),
        left_icuInputBuffer: _castOutputBuffer(&left_icuInput),
        left_icuOutputBuffer: _castOutputBuffer(&left_icuOutput),
        right_outputBuffer: _castOutputBuffer(&right_output),
        right_icuInputBuffer: _castOutputBuffer(&right_icuInput),
        right_icuOutputBuffer: _castOutputBuffer(&right_icuOutput),
        left_range: range,
        right_range: other.range,
        expecting: expecting,
        normalizeLeft: { readIndex, outputBuffer, icuInputBuffer, icuOutputBuffer in
          _foreignNormalize(
            readIndex: readIndex,
            endIndex: range.upperBound,
            guts: _guts,
            outputBuffer: &outputBuffer,
            icuInputBuffer: &icuInputBuffer,
            icuOutputBuffer: &icuOutputBuffer)
        },
        normalizeRight: { readIndex, outputBuffer, icuInputBuffer, icuOutputBuffer in
          _foreignNormalize(
            readIndex: readIndex,
            endIndex: other.range.upperBound,
            guts: other._guts,
            outputBuffer: &outputBuffer,
            icuInputBuffer: &icuInputBuffer,
            icuOutputBuffer: &icuOutputBuffer)
        })
    }
  }
  
  
  @inline(__always) //Avoid unecessary overhead from the closures.
  internal func _normalizedCompareImpl(
    left_outputBuffer: UnsafeMutableBufferPointer<UInt8>,
    left_icuInputBuffer: UnsafeMutableBufferPointer<UInt16>,
    left_icuOutputBuffer: UnsafeMutableBufferPointer<UInt16>,
    right_outputBuffer: UnsafeMutableBufferPointer<UInt8>,
    right_icuInputBuffer: UnsafeMutableBufferPointer<UInt16>,
    right_icuOutputBuffer: UnsafeMutableBufferPointer<UInt16>,
    left_range: Range<String.Index>,
    right_range: Range<String.Index>,
    expecting: _StringComparisonResult,
    normalizeLeft: (
      _ readIndex: String.Index,
      _ outputBuffer: inout UnsafeMutableBufferPointer<UInt8>,
      _ icuInputBuffer: inout UnsafeMutableBufferPointer<UInt16>,
      _ icuOutputBuffer: inout UnsafeMutableBufferPointer<UInt16>) -> NormalizationResult,
    normalizeRight: (
      _ readIndex: String.Index,
      _ outputBuffer: inout UnsafeMutableBufferPointer<UInt8>,
      _ icuInputBuffer: inout UnsafeMutableBufferPointer<UInt16>,
      _ icuOutputBuffer: inout UnsafeMutableBufferPointer<UInt16>) -> NormalizationResult
  ) -> Bool {
    var left_outputBuffer = left_outputBuffer
    var left_icuInputBuffer = left_icuInputBuffer
    var left_icuOutputBuffer = left_icuOutputBuffer
    var right_outputBuffer = right_outputBuffer
    var right_icuInputBuffer = right_icuInputBuffer
    var right_icuOutputBuffer = right_icuOutputBuffer
  
    var leftNextReadPosition = left_range.lowerBound
    var rightNextReadPosition = right_range.lowerBound
    var leftOutputBufferIndex = 0
    var rightOutputBufferIndex = 0
    var leftOutputBufferCount = 0
    var rightOutputBufferCount = 0
    let leftEndIndex = left_range.upperBound
    let rightEndIndex = right_range.upperBound
  
    var hasLeftBufferOwnership = false
    var hasRightBufferOwnership = false
    
    if left_range.isEmpty && right_range.isEmpty {
      return expecting == .equal
    }
    if left_range.isEmpty {
      return expecting == .less
    }
    if right_range.isEmpty {
      return false
    }
  
    defer {
      if hasLeftBufferOwnership {
        left_outputBuffer.deallocate()
        left_icuInputBuffer.deallocate()
        left_icuOutputBuffer.deallocate()
      }
      if hasRightBufferOwnership {
        right_outputBuffer.deallocate()
        right_icuInputBuffer.deallocate()
        right_icuOutputBuffer.deallocate()
      }
    }
  
    repeat {
      if leftOutputBufferIndex == leftOutputBufferCount {
        let result = normalizeLeft(
          leftNextReadPosition,
          &left_outputBuffer,
          &left_icuInputBuffer,
          &left_icuOutputBuffer)
        _internalInvariant(result.nextReadPosition != leftNextReadPosition)
        leftOutputBufferCount = result.amountFilled
        leftOutputBufferIndex = 0
        leftNextReadPosition = result.nextReadPosition
        if result.allocatedBuffers {
          _internalInvariant(!hasLeftBufferOwnership)
          hasLeftBufferOwnership = true
        }
      }
      if rightOutputBufferIndex == rightOutputBufferCount {
        let result = normalizeRight(
          rightNextReadPosition,
          &right_outputBuffer,
          &right_icuInputBuffer,
          &right_icuOutputBuffer)
        _internalInvariant(result.nextReadPosition != rightNextReadPosition)
        rightOutputBufferCount = result.amountFilled
        rightOutputBufferIndex = 0
        rightNextReadPosition = result.nextReadPosition
        if result.allocatedBuffers {
          _internalInvariant(!hasRightBufferOwnership)
          hasRightBufferOwnership = true
        }
      }
      while leftOutputBufferIndex < leftOutputBufferCount && rightOutputBufferIndex < rightOutputBufferCount {
        let leftCU = left_outputBuffer[leftOutputBufferIndex]
        let rightCU = right_outputBuffer[rightOutputBufferIndex]
        if leftCU == rightCU {
          leftOutputBufferIndex += 1
          rightOutputBufferIndex += 1
          continue
        } else if leftCU < rightCU {
          return expecting == .less
        } else {
          return false
        }
      }
    } while (leftNextReadPosition < leftEndIndex
    || leftOutputBufferIndex < leftOutputBufferCount)
    && (rightNextReadPosition < rightEndIndex
    || rightOutputBufferIndex < rightOutputBufferCount)
    
  
    //At least one of them ran out of code units, whichever it was is the "smaller" string
    if leftNextReadPosition < leftEndIndex 
    || leftOutputBufferIndex < leftOutputBufferCount {
      return false
    } else if rightNextReadPosition < rightEndIndex
    || rightOutputBufferIndex < rightOutputBufferCount {
      return expecting == .less
    } else {
      //They both ran out
      return expecting == .equal
    }
  }
}
