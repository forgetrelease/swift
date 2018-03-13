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

extension _StringVariant {
  @_versioned
  func _repeated(_ count: Int) -> _SwiftStringStorage<CodeUnit> {
    _sanityCheck(count > 0)
    let c = self.count
    let storage = _copyToNativeStorage(
      of: CodeUnit.self,
      unusedCapacity: (count - 1) * c)
    var p = storage.start + c
    for _ in 1 ..< count {
      p.initialize(from: storage.start, count: c)
      p += c
    }
    _sanityCheck(p == storage.start + count * c)
    storage.count = p - storage.start
    return storage
  }
}

extension String {
  /// Creates a new string representing the given string repeated the specified
  /// number of times.
  ///
  /// For example, you can use this initializer to create a string with ten
  /// `"ab"` strings in a row.
  ///
  ///     let s = String(repeating: "ab", count: 10)
  ///     print(s)
  ///     // Prints "abababababababababab"
  ///
  /// - Parameters:
  ///   - repeatedValue: The string to repeat.
  ///   - count: The number of times to repeat `repeatedValue` in the resulting
  ///     string.
  @_inlineable // FIXME(sil-serialize-all)
  public init(repeating repeatedValue: String, count: Int) {
    if count == 0 {
      self = ""
    } else if count == 1 {
      self = repeatedValue
    } else {
      precondition(count > 0, "Negative count not allowed")
      defer { _fixLifetime(repeatedValue) }
      if _slowPath(repeatedValue._guts._isOpaque) {
        let opaque = repeatedValue._guts._asOpaque()
        self.init(_StringGuts(opaque._repeated(count)))
      } else if repeatedValue._guts.isASCII {
        let ascii = repeatedValue._guts._unmanagedASCIIView
        self.init(_StringGuts(ascii._repeated(count)))
      } else {
        let utf16 = repeatedValue._guts._unmanagedUTF16View
        self.init(_StringGuts(utf16._repeated(count)))
      }
    }
  }

  /// A Boolean value indicating whether a string has no characters.
  @_inlineable // FIXME(sil-serialize-all)
  public var isEmpty: Bool {
    return _guts.count == 0
  }
}

extension String {
  @_inlineable // FIXME(sil-serialize-all)
  public init(_ _c: Unicode.Scalar) {
    self = String._fromWellFormedCodeUnitSequence(
      UTF32.self,
      input: repeatElement(_c.value, count: 1))
  }
}


// TODO: since this is generally useful, make public via evolution proposal.
extension BidirectionalCollection {
  @_inlineable
  @_versioned
  internal func _ends<Suffix: BidirectionalCollection>(
    with suffix: Suffix, by areEquivalent: (Element,Element) -> Bool
  ) -> Bool where Suffix.Element == Element {
    var (i,j) = (self.endIndex,suffix.endIndex)
    while i != self.startIndex, j != suffix.startIndex {
      self.formIndex(before: &i)
      suffix.formIndex(before: &j)
      if !areEquivalent(self[i],suffix[j]) { return false }
    } 
    return j == suffix.startIndex
  }
}

extension BidirectionalCollection where Element: Equatable {
  @_inlineable
  @_versioned
  internal func _ends<Suffix: BidirectionalCollection>(
    with suffix: Suffix
  ) -> Bool where Suffix.Element == Element {
      return _ends(with: suffix, by: ==)
  }
}


extension StringProtocol {
  /// Returns a Boolean value indicating whether the string begins with the
  /// specified prefix.
  ///
  /// The comparison is both case sensitive and Unicode safe. The
  /// case-sensitive comparison will only match strings whose corresponding
  /// characters have the same case.
  ///
  ///     let cafe = "Café du Monde"
  ///
  ///     // Case sensitive
  ///     print(cafe.hasPrefix("café"))
  ///     // Prints "false"
  ///
  /// The Unicode-safe comparison matches Unicode scalar values rather than the
  /// code points used to compose them. The example below uses two strings
  /// with different forms of the `"é"` character---the first uses the composed
  /// form and the second uses the decomposed form.
  ///
  ///     // Unicode safe
  ///     let composedCafe = "Café"
  ///     let decomposedCafe = "Cafe\u{0301}"
  ///
  ///     print(cafe.hasPrefix(composedCafe))
  ///     // Prints "true"
  ///     print(cafe.hasPrefix(decomposedCafe))
  ///     // Prints "true"
  ///
  /// - Parameter prefix: A possible prefix to test against this string.
  /// - Returns: `true` if the string begins with `prefix`; otherwise, `false`.
  @_inlineable
  public func hasPrefix<Prefix: StringProtocol>(_ prefix: Prefix) -> Bool {
    return self.starts(with: prefix)
  }

  /// Returns a Boolean value indicating whether the string ends with the
  /// specified suffix.
  ///
  /// The comparison is both case sensitive and Unicode safe. The
  /// case-sensitive comparison will only match strings whose corresponding
  /// characters have the same case.
  ///
  ///     let plans = "Let's meet at the café"
  ///
  ///     // Case sensitive
  ///     print(plans.hasSuffix("Café"))
  ///     // Prints "false"
  ///
  /// The Unicode-safe comparison matches Unicode scalar values rather than the
  /// code points used to compose them. The example below uses two strings
  /// with different forms of the `"é"` character---the first uses the composed
  /// form and the second uses the decomposed form.
  ///
  ///     // Unicode safe
  ///     let composedCafe = "café"
  ///     let decomposedCafe = "cafe\u{0301}"
  ///
  ///     print(plans.hasSuffix(composedCafe))
  ///     // Prints "true"
  ///     print(plans.hasSuffix(decomposedCafe))
  ///     // Prints "true"
  ///
  /// - Parameter suffix: A possible suffix to test against this string.
  /// - Returns: `true` if the string ends with `suffix`; otherwise, `false`.
  @_inlineable
  public func hasSuffix<Suffix: StringProtocol>(_ suffix: Suffix) -> Bool {
    return self._ends(with: suffix)
  }
}

extension String {
  @_inlineable // FIXME(sil-serialize-all)
  public func hasPrefix(_ prefix: String) -> Bool {
    let prefixCount = prefix._guts.count
    if prefixCount == 0 { return true }

    if _fastPath(!self._guts._isOpaque && !prefix._guts._isOpaque) {
      if self._guts.isASCII && prefix._guts.isASCII {
        let result: Bool
        let selfASCII = self._guts._unmanagedASCIIView
        let prefixASCII = prefix._guts._unmanagedASCIIView
        if prefixASCII.count > selfASCII.count {
          // Prefix is longer than self.
          result = false
        } else {
          result = (0 as CInt) == _stdlib_memcmp(
            selfASCII.rawStart,
            prefixASCII.rawStart,
            prefixASCII.count)
        }
        _fixLifetime(self)
        _fixLifetime(prefix)
        return result
      }
      else {
        
      }
    }

    return self.starts(with: prefix)
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func hasSuffix(_ suffix: String) -> Bool {
    let suffixCount = suffix._guts.count
    if suffixCount == 0 { return true }

    if _fastPath(!self._guts._isOpaque && !suffix._guts._isOpaque) {
      if self._guts.isASCII && suffix._guts.isASCII {
        let result: Bool
        let selfASCII = self._guts._unmanagedASCIIView
        let suffixASCII = suffix._guts._unmanagedASCIIView
        if suffixASCII.count > self._guts.count {
          // Suffix is longer than self.
          result = false
        } else {
          result = (0 as CInt) == _stdlib_memcmp(
            selfASCII.rawStart + (selfASCII.count - suffixASCII.count),
            suffixASCII.rawStart,
            suffixASCII.count)
        }
        _fixLifetime(self)
        _fixLifetime(suffix)
        return result
      }
    }

    return self._ends(with: suffix)
  }
}

// Conversions to string from other types.
extension String {
  /// Creates a string representing the given value in base 10, or some other
  /// specified base.
  ///
  /// The following example converts the maximal `Int` value to a string and
  /// prints its length:
  ///
  ///     let max = String(Int.max)
  ///     print("\(max) has \(max.count) digits.")
  ///     // Prints "9223372036854775807 has 19 digits."
  ///
  /// Numerals greater than 9 are represented as Roman letters. These letters
  /// start with `"A"` if `uppercase` is `true`; otherwise, with `"a"`.
  ///
  ///     let v = 999_999
  ///     print(String(v, radix: 2))
  ///     // Prints "11110100001000111111"
  ///
  ///     print(String(v, radix: 16))
  ///     // Prints "f423f"
  ///     print(String(v, radix: 16, uppercase: true))
  ///     // Prints "F423F"
  ///
  /// - Parameters:
  ///   - value: The value to convert to a string.
  ///   - radix: The base to use for the string representation. `radix` must be
  ///     at least 2 and at most 36. The default is 10.
  ///   - uppercase: Pass `true` to use uppercase letters to represent numerals
  ///     greater than 9, or `false` to use lowercase letters. The default is
  ///     `false`.
  @_inlineable // FIXME(sil-serialize-all)
  public init<T : BinaryInteger>(
    _ value: T, radix: Int = 10, uppercase: Bool = false
  ) {
    self = value._description(radix: radix, uppercase: uppercase)
  }
}
