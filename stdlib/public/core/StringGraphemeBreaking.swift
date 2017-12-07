//===----------------------------------------------------------------------===//
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

import SwiftShims

/// CR and LF are common special cases in grapheme breaking logic
@_inlineable // FIXME(sil-serialize-all)
@_versioned
internal var _CR: UInt8 { return 0x0d }
@_inlineable // FIXME(sil-serialize-all)
@_versioned
internal var _LF: UInt8 { return 0x0a }

extension _StringVariant {
  // NOTE: Because this function is inlineable, it should contain only the fast
  // paths of grapheme breaking that we have high confidence won't change.
  /// Returns the length of the first extended grapheme cluster in UTF-16
  /// code units.
  @_versioned
  @_inlineable
  internal
  func measureFirstExtendedGraphemeCluster() -> Int {
    // No more graphemes at end of string.
    if count == 0 { return 0 }

    // If there is a single code unit left, the grapheme length must be 1.
    if count == 1 { return 1 }

    if isASCII {
      _onFastPath() // Please agressively inline
      // The only multi-scalar ASCII grapheme cluster is CR/LF.
      if _slowPath(self[0] == _CR && self[1] == _LF) {
        return 2
      }
      return 1
    }

    if _fastPath(
      UTF16._quickCheckGraphemeBreakBetween(self[0], self[1])) {
      return 1
    }
    return self._measureFirstExtendedGraphemeClusterSlow()
  }

  // NOTE: Because this function is inlineable, it should contain only the fast
  // paths of grapheme breaking that we have high confidence won't change.
  //
  /// Returns the length of the last extended grapheme cluster in UTF-16
  /// code units.
  @_versioned
  @_inlineable
  internal
  func measureLastExtendedGraphemeCluster() -> Int {
    let count = self.count
    // No more graphemes at end of string.
    if count == 0 { return 0 }

    // If there is a single code unit left, the grapheme length must be 1.
    if count == 1 { return 1 }

    if isASCII {
      _onFastPath() // Please agressively inline
      // The only multi-scalar ASCII grapheme cluster is CR/LF.
      if _slowPath(self[count-1] == _LF && self[count-2] == _CR) {
        return 2
      }
      return 1
    }

    if _fastPath(
      UTF16._quickCheckGraphemeBreakBetween(self[count - 2], self[count - 1])) {
      return 1
    }
    return self._measureLastExtendedGraphemeClusterSlow()
  }
}

extension _UnmanagedString {
  @inline(never)
  @_versioned
  internal func _measureFirstExtendedGraphemeClusterSlow() -> Int {
    // ASCII case handled entirely on fast path.
    // FIXME: Have separate implementations for ASCII & UTF-16 views.
    _sanityCheck(CodeUnit.self == UInt16.self)
    return UTF16._measureFirstExtendedGraphemeCluster(
      in: UnsafeBufferPointer(
        start: rawStart.assumingMemoryBound(to: UInt16.self),
        count: count))
  }

  @inline(never)
  @_versioned
  internal func _measureLastExtendedGraphemeClusterSlow() -> Int {
    // ASCII case handled entirely on fast path.
    // FIXME: Have separate implementations for ASCII & UTF-16 views.
    _sanityCheck(CodeUnit.self == UInt16.self)
    return UTF16._measureLastExtendedGraphemeCluster(
      in: UnsafeBufferPointer(
        start: rawStart.assumingMemoryBound(to: UInt16.self),
        count: count))
  }
}

extension _UnmanagedOpaqueString {
  @inline(never)
  @_versioned
  internal func _measureFirstExtendedGraphemeClusterSlow() -> Int {
    _sanityCheck(count >= 2, "should have at least two code units")

    // Pull out some code units into a fixed array and try to perform grapheme
    // breaking on that.
    var shortBuffer = _FixedArray16<UInt16>(allZeros:())
    let maxShortCount = shortBuffer.count
    let shortCount = Swift.min(maxShortCount, count)
    shortBuffer.withUnsafeMutableBufferPointer { buffer in
      self.prefix(shortCount)._copy(into: buffer)
    }
    let shortLength = shortBuffer.withUnsafeBufferPointer { buffer in
      UTF16._measureFirstExtendedGraphemeCluster(
        in: UnsafeBufferPointer(rebasing: buffer.prefix(shortCount)))
    }
    if _fastPath(shortLength < maxShortCount) {
      return shortLength
    }

    // Nuclear option: copy out the rest of the string into a contiguous buffer.
    let longStart = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
    defer { longStart.deallocate(capacity: count) }
    self._copy(into: UnsafeMutableBufferPointer(start: longStart, count: count))
    return UTF16._measureFirstExtendedGraphemeCluster(
      in: UnsafeBufferPointer(start: longStart, count: count))
  }

  @inline(never)
  @_versioned
  internal func _measureLastExtendedGraphemeClusterSlow() -> Int {
    _sanityCheck(count >= 2, "should have at least two code units")

    // Pull out some code units into a fixed array and try to perform grapheme
    // breaking on that.
    var shortBuffer = _FixedArray16<UInt16>(allZeros:())
    let maxShortCount = shortBuffer.count
    let shortCount = Swift.min(maxShortCount, count)
    shortBuffer.withUnsafeMutableBufferPointer { buffer in
      self.suffix(shortCount)._copy(into: buffer)
    }
    let shortLength = shortBuffer.withUnsafeBufferPointer { buffer in
      UTF16._measureLastExtendedGraphemeCluster(
        in: UnsafeBufferPointer(rebasing: buffer.suffix(shortCount)))
    }
    if _fastPath(shortLength < maxShortCount) {
      return shortLength
    }

    // Nuclear option: copy out the rest of the string into a contiguous buffer.
    let longStart = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
    defer { longStart.deallocate(capacity: count) }
    self._copy(into: UnsafeMutableBufferPointer(start: longStart, count: count))
    return UTF16._measureLastExtendedGraphemeCluster(
      in: UnsafeBufferPointer(start: longStart, count: count))
  }
}

extension Unicode.UTF16 {
  /// Fast check for a (stable) grapheme break between two UInt16 code units
  @_inlineable // Safe to inline
  @_versioned
  internal static func _quickCheckGraphemeBreakBetween(
    _ lhs: UInt16, _ rhs: UInt16
  ) -> Bool {
    // With the exception of CR-LF, there is always a grapheme break between two
    // sub-0x300 code units
    if lhs < 0x300 && rhs < 0x300 {
      return lhs != UInt16(_CR) && rhs != UInt16(_LF)
    }
    return _internalExtraCheckGraphemeBreakBetween(lhs, rhs)
  }

  @inline(never) // @inline(resilient_only)
  @_versioned
  internal static func _internalExtraCheckGraphemeBreakBetween(
    _ lhs: UInt16, _ rhs: UInt16
  ) -> Bool {
    _sanityCheck(
      lhs != _CR || rhs != _LF,
      "CR-LF special case handled by _quickCheckGraphemeBreakBetween")

    // Whether the given scalar, when it appears paired with another scalar
    // satisfying this property, has a grapheme break between it and the other
    // scalar.
    func hasBreakWhenPaired(_ x: UInt16) -> Bool {
      // TODO: This doesn't generate optimal code, tune/re-write at a lower
      // level.
      //
      // NOTE: Order of case ranges affects codegen, and thus performance. All
      // things being equal, keep existing order below.
      switch x {
      // Unified CJK Han ideographs, common and some supplemental, amongst
      // others:
      //   0x3400-0xA4CF
      case 0x3400...0xa4cf: return true

      // Repeat sub-300 check, this is beneficial for common cases of Latin
      // characters embedded within non-Latin script (e.g. newlines, spaces,
      // proper nouns and/or jargon, punctuation).
      //
      // NOTE: CR-LF special case has already been checked.
      case 0x0000...0x02ff: return true

      // Non-combining kana:
      //   0x3041-0x3096
      //   0x30A1-0x30FA
      case 0x3041...0x3096: return true
      case 0x30a1...0x30fa: return true

      // Non-combining modern (and some archaic) Cyrillic:
      //   0x0400-0x0482 (first half of Cyrillic block)
      case 0x0400...0x0482: return true

      // Modern Arabic, excluding extenders and prependers:
      //   0x061D-0x064A
      case 0x061d...0x064a: return true

      // Precomposed Hangul syllables:
      //   0xAC00–0xD7AF
      case 0xac00...0xd7af: return true

      // Common general use punctuation, excluding extenders:
      //   0x2010-0x2029
      case 0x2010...0x2029: return true

      // CJK punctuation characters, excluding extenders:
      //   0x3000-0x3029
      case 0x3000...0x3029: return true

      default: return false
      }
    }
    return hasBreakWhenPaired(lhs) && hasBreakWhenPaired(rhs)
  }

  // NOT @_versioned
  internal static func _measureFirstExtendedGraphemeCluster(
    in buffer: UnsafeBufferPointer<CodeUnit>
  ) -> Int {
    // ICU can only handle 32-bit offsets; don't feed it more than that.
    // https://bugs.swift.org/browse/SR-6544
    let count: Int32
    if _fastPath(buffer.count <= Int(Int32.max)) {
      count = Int32(truncatingIfNeeded: buffer.count)
    } else {
      count = Int32.max
    }
    let iterator = _ThreadLocalStorage.getUBreakIterator(
      start: buffer.baseAddress!,
      count: count)
    let offset = __swift_stdlib_ubrk_following(iterator, 0)
    // ubrk_following returns -1 (UBRK_DONE) when it hits the end of the buffer.
    if _fastPath(offset != -1) {
      // The offset into our buffer is the distance.
      _sanityCheck(offset > 0, "zero-sized grapheme?")
      return Int(offset)
    }
    return Int(count)
  }

  // NOT @_versioned
  internal static func _measureLastExtendedGraphemeCluster(
    in buffer: UnsafeBufferPointer<CodeUnit>
  ) -> Int {
    // ICU can only handle 32-bit offsets; don't feed it more than that.
    // https://bugs.swift.org/browse/SR-6544
    let count: Int32
    let start: UnsafePointer<CodeUnit>
    if _fastPath(buffer.count <= Int(Int32.max)) {
      count = Int32(truncatingIfNeeded: buffer.count)
      start = buffer.baseAddress!
    } else {
      count = Int32.max
      start = buffer.baseAddress! + buffer.count - Int(Int32.max)
    }
    let iterator = _ThreadLocalStorage.getUBreakIterator(
      start: start,
      count: count)

    let offset = __swift_stdlib_ubrk_preceding(iterator, count)
    // ubrk_following returns -1 (UBRK_DONE) when it hits the end of the buffer.
    if _fastPath(offset != -1) {
      // The offset into our buffer is the distance.
      _sanityCheck(offset < count, "zero-sized grapheme?")
      return Int(count - offset)
    }
    return Int(count)
  }
}
