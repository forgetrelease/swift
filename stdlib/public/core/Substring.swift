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

extension String {
  // FIXME(strings): at least temporarily remove it to see where it was applied
  /// Creates a new string from the given substring.
  ///
  /// - Parameter substring: A substring to convert to a standalone `String`
  ///   instance.
  ///
  /// - Complexity: O(*n*), where *n* is the length of `substring`.
  public init(_ substring: Substring) {
    let wholeGuts = substring._wholeString._guts
    self.init(wholeGuts._extractSlice(substring._encodedOffsetRange))
  }
}

/// A slice of a string.
///
/// When you create a slice of a string, a `Substring` instance is the result.
/// Operating on substrings is fast and efficient because a substring shares
/// its storage with the original string. The `Substring` type presents the
/// same interface as `String`, so you can avoid or defer any copying of the
/// string's contents.
///
/// The following example creates a `greeting` string, and then finds the
/// substring of the first sentence:
///
///     let greeting = "Hi there! It's nice to meet you! 👋"
///     let endOfSentence = greeting.firstIndex(of: "!")!
///     let firstSentence = greeting[...endOfSentence]
///     // firstSentence == "Hi there!"
///
/// You can perform many string operations on a substring. Here, we find the
/// length of the first sentence and create an uppercase version.
///
///     print("'\(firstSentence)' is \(firstSentence.count) characters long.")
///     // Prints "'Hi there!' is 9 characters long."
///
///     let shoutingSentence = firstSentence.uppercased()
///     // shoutingSentence == "HI THERE!"
///
/// Converting a Substring to a String
/// ==================================
///
/// This example defines a `rawData` string with some unstructured data, and
/// then uses the string's `prefix(while:)` method to create a substring of
/// the numeric prefix:
///
///     let rawInput = "126 a.b 22219 zzzzzz"
///     let numericPrefix = rawInput.prefix(while: { "0"..."9" ~= $0 })
///     // numericPrefix is the substring "126"
///
/// When you need to store a substring or pass it to a function that requires a
/// `String` instance, you can convert it to a `String` by using the
/// `String(_:)` initializer. Calling this initializer copies the contents of
/// the substring to a new string.
///
///     func parseAndAddOne(_ s: String) -> Int {
///         return Int(s, radix: 10)! + 1
///     }
///     _ = parseAndAddOne(numericPrefix)
///     // error: cannot convert value...
///     let incrementedPrefix = parseAndAddOne(String(numericPrefix))
///     // incrementedPrefix == 127
///
/// Alternatively, you can convert the function that takes a `String` to one
/// that is generic over the `StringProtocol` protocol. The following code
/// declares a generic version of the `parseAndAddOne(_:)` function:
///
///     func genericParseAndAddOne<S: StringProtocol>(_ s: S) -> Int {
///         return Int(s, radix: 10)! + 1
///     }
///     let genericallyIncremented = genericParseAndAddOne(numericPrefix)
///     // genericallyIncremented == 127
///
/// You can call this generic function with an instance of either `String` or
/// `Substring`.
///
/// - Important: Don't store substrings longer than you need them to perform a
///   specific operation. A substring holds a reference to the entire storage
///   of the string it comes from, not just to the portion it presents, even
///   when there is no other reference to the original string. Storing
///   substrings may, therefore, prolong the lifetime of string data that is
///   no longer otherwise accessible, which can appear to be memory leakage.
@_fixed_layout // FIXME(sil-serialize-all)
public struct Substring : StringProtocol {
  public typealias Index = String.Index
  public typealias SubSequence = Substring

  @usableFromInline // FIXME(sil-serialize-all)
  internal var _slice: Slice<String>

  /// Creates an empty substring.
  @inlinable // FIXME(sil-serialize-all)
  public init() {
    _slice = Slice()
  }

  @inlinable // FIXME(sil-serialize-all)
  internal init(_slice: Slice<String>) {
    self._slice = _slice
  }

  @inlinable // FIXME(sil-serialize-all)
  internal init(_ guts: _StringGuts, _ offsetRange: Range<Int>) {
    self.init(
      _base: String(guts),
      Index(encodedOffset: offsetRange.lowerBound) ..<
        Index(encodedOffset: offsetRange.upperBound))
  }

  /// Creates a substring with the specified bounds within the given string.
  ///
  /// - Parameters:
  ///   - base: The string to create a substring of.
  ///   - bounds: The range of `base` to use for the substring. The lower and
  ///     upper bounds of `bounds` must be valid indices of `base`.
  @inlinable // FIXME(sil-serialize-all)
  public init(_base base: String, _ bounds: Range<Index>) {
    _slice = Slice(base: base, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  internal init<R: RangeExpression>(
    _base base: String, _ bounds: R
  ) where R.Bound == Index {
    self.init(_base: base, bounds.relative(to: base))
  }

  @inlinable // FIXME(sil-serialize-all)
  public var startIndex: Index { return _slice.startIndex }
  @inlinable // FIXME(sil-serialize-all)
  public var endIndex: Index { return _slice.endIndex }

  @inlinable // FIXME(sil-serialize-all)
  public func index(after i: Index) -> Index {
    _precondition(i < endIndex, "Cannot increment beyond endIndex")
    _precondition(i >= startIndex, "Cannot increment an invalid index")
    // FIXME(strings): slice types currently lack necessary bound checks
    return _slice.index(after: i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(before i: Index) -> Index {
    _precondition(i <= endIndex, "Cannot decrement an invalid index")
    _precondition(i > startIndex, "Cannot decrement beyond startIndex")
    // FIXME(strings): slice types currently lack necessary bound checks
    return _slice.index(before: i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    let result = _slice.index(i, offsetBy: n)
    // FIXME(strings): slice types currently lack necessary bound checks
    _precondition(
      (_slice._startIndex ... _slice.endIndex).contains(result),
      "Operation results in an invalid index")
    return result
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    let result = _slice.index(i, offsetBy: n, limitedBy: limit)
    // FIXME(strings): slice types currently lack necessary bound checks
    _precondition(result.map {
        (_slice._startIndex ... _slice.endIndex).contains($0)
      } ?? true,
      "Operation results in an invalid index")
    return result
  }

  @inlinable // FIXME(sil-serialize-all)
  public func distance(from start: Index, to end: Index) -> Int {
    return _slice.distance(from: start, to: end)
  }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(i: Index) -> Character {
    return _slice[i]
  }

  @inlinable // FIXME(sil-serialize-all)
  public mutating func replaceSubrange<C>(
    _ bounds: Range<Index>,
    with newElements: C
  ) where C : Collection, C.Iterator.Element == Iterator.Element {
    // FIXME(strings): slice types currently lack necessary bound checks
    _slice.replaceSubrange(bounds, with: newElements)
  }

  @inlinable // FIXME(sil-serialize-all)
  public mutating func replaceSubrange(
    _ bounds: Range<Index>, with newElements: Substring
  ) {
    replaceSubrange(bounds, with: newElements._slice)
  }

  /// Creates a string from the given Unicode code units in the specified
  /// encoding.
  ///
  /// - Parameters:
  ///   - codeUnits: A collection of code units encoded in the encoding
  ///     specified in `sourceEncoding`.
  ///   - sourceEncoding: The encoding in which `codeUnits` should be
  ///     interpreted.
  @inlinable // FIXME(sil-serialize-all)
  public init<C: Collection, Encoding: _UnicodeEncoding>(
    decoding codeUnits: C, as sourceEncoding: Encoding.Type
  ) where C.Iterator.Element == Encoding.CodeUnit {
    self.init(String(decoding: codeUnits, as: sourceEncoding))
  }

  /// Creates a string from the null-terminated, UTF-8 encoded sequence of
  /// bytes at the given pointer.
  ///
  /// - Parameter nullTerminatedUTF8: A pointer to a sequence of contiguous,
  ///   UTF-8 encoded bytes ending just before the first zero byte.
  @inlinable // FIXME(sil-serialize-all)
  public init(cString nullTerminatedUTF8: UnsafePointer<CChar>) {
    self.init(String(cString: nullTerminatedUTF8))
  }

  /// Creates a string from the null-terminated sequence of bytes at the given
  /// pointer.
  ///
  /// - Parameters:
  ///   - nullTerminatedCodeUnits: A pointer to a sequence of contiguous code
  ///     units in the encoding specified in `sourceEncoding`, ending just
  ///     before the first zero code unit.
  ///   - sourceEncoding: The encoding in which the code units should be
  ///     interpreted.
  @inlinable // FIXME(sil-serialize-all)
  public init<Encoding: _UnicodeEncoding>(
    decodingCString nullTerminatedCodeUnits: UnsafePointer<Encoding.CodeUnit>,
    as sourceEncoding: Encoding.Type
  ) {
    self.init(
      String(decodingCString: nullTerminatedCodeUnits, as: sourceEncoding))
  }

  /// Calls the given closure with a pointer to the contents of the string,
  /// represented as a null-terminated sequence of UTF-8 code units.
  ///
  /// The pointer passed as an argument to `body` is valid only during the
  /// execution of `withCString(_:)`. Do not store or return the pointer for
  /// later use.
  ///
  /// - Parameter body: A closure with a pointer parameter that points to a
  ///   null-terminated sequence of UTF-8 code units. If `body` has a return
  ///   value, that value is also used as the return value for the
  ///   `withCString(_:)` method. The pointer argument is valid only for the
  ///   duration of the method's execution.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  @inlinable // FIXME(sil-serialize-all)
  public func withCString<Result>(
    _ body: (UnsafePointer<CChar>) throws -> Result) rethrows -> Result {
    return try _wholeString._guts._withCSubstringAndLength(
      in: _encodedOffsetRange,
      encoding: UTF8.self) { p, length in
      try p.withMemoryRebound(to: CChar.self, capacity: length, body)
    }
  }

  /// Calls the given closure with a pointer to the contents of the string,
  /// represented as a null-terminated sequence of code units.
  ///
  /// The pointer passed as an argument to `body` is valid only during the
  /// execution of `withCString(encodedAs:_:)`. Do not store or return the
  /// pointer for later use.
  ///
  /// - Parameters:
  ///   - body: A closure with a pointer parameter that points to a
  ///     null-terminated sequence of code units. If `body` has a return
  ///     value, that value is also used as the return value for the
  ///     `withCString(encodedAs:_:)` method. The pointer argument is valid
  ///     only for the duration of the method's execution.
  ///   - targetEncoding: The encoding in which the code units should be
  ///     interpreted.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  @inlinable // FIXME(sil-serialize-all)
  public func withCString<Result, TargetEncoding: _UnicodeEncoding>(
    encodedAs targetEncoding: TargetEncoding.Type,
    _ body: (UnsafePointer<TargetEncoding.CodeUnit>) throws -> Result
  ) rethrows -> Result {
    return try _wholeString._guts._withCSubstring(
      in: _encodedOffsetRange,
      encoding: targetEncoding,
      body)
  }
}

extension Substring : _SwiftStringView {
  @inlinable // FIXME(sil-serialize-all)
  internal var _persistentContent: String {
    return String(self)
  }

  @inlinable // FIXME(sil-serialize-all)
  public // @testable
  var _ephemeralContent: String {
    return _persistentContent
  }

  @inlinable // FIXME(sil-serialize-all)
  public var _wholeString: String {
    return _slice._base
  }

  @inlinable // FIXME(sil-serialize-all)
  public var _encodedOffsetRange: Range<Int> {
    return startIndex.encodedOffset..<endIndex.encodedOffset
  }
}

extension Substring : CustomReflectable {
  public var customMirror: Mirror {
    return String(self).customMirror
  }
}

extension Substring : CustomStringConvertible {
  @inlinable // FIXME(sil-serialize-all)
  public var description: String {
    return String(self)
  }
}

extension Substring : CustomDebugStringConvertible {
  public var debugDescription: String {
    return String(self).debugDescription
  }
}

extension Substring : LosslessStringConvertible {
  @inlinable // FIXME(sil-serialize-all)
  public init(_ content: String) {
    self.init(_base: content, content.startIndex ..< content.endIndex)
  }
}


extension Substring {
  @_fixed_layout // FIXME(sil-serialize-all)
  public struct UTF8View {
    @usableFromInline // FIXME(sil-serialize-all)
    internal var _slice: Slice<String.UTF8View>
  }
}

extension Substring.UTF8View : BidirectionalCollection {
  public typealias Index = String.UTF8View.Index
  public typealias Indices = String.UTF8View.Indices
  public typealias Element = String.UTF8View.Element
  public typealias SubSequence = Substring.UTF8View

  /// Creates an instance that slices `base` at `_bounds`.
  @inlinable // FIXME(sil-serialize-all)
  internal init(_ base: String.UTF8View, _bounds: Range<Index>) {
    _slice = Slice(
      base: String(base._guts).utf8,
      bounds: _bounds)
  }

  /// The entire String onto whose slice this view is a projection.
  @inlinable // FIXME(sil-serialize-all)
  internal var _wholeString: String {
    return String(_slice._base._guts)
  }

  @inlinable // FIXME(sil-serialize-all)
  internal var _encodedOffsetRange: Range<Int> {
    return startIndex.encodedOffset..<endIndex.encodedOffset
  }

  //
  // Plumb slice operations through
  //
  @inlinable // FIXME(sil-serialize-all)
  public var startIndex: Index { return _slice.startIndex }

  @inlinable // FIXME(sil-serialize-all)
  public var endIndex: Index { return _slice.endIndex }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(index: Index) -> Element { return _slice[index] }

  @inlinable // FIXME(sil-serialize-all)
  public var indices: Indices { return _slice.indices }

  @inlinable // FIXME(sil-serialize-all)
  public func index(after i: Index) -> Index { return _slice.index(after: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(after i: inout Index) {
    _slice.formIndex(after: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    return _slice.index(i, offsetBy: n)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    return _slice.index(i, offsetBy: n, limitedBy: limit)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func distance(from start: Index, to end: Index) -> Int {
    return _slice.distance(from: start, to: end)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
    _slice._failEarlyRangeCheck(index, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(
    _ range: Range<Index>, bounds: Range<Index>
  ) {
    _slice._failEarlyRangeCheck(range, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(before i: Index) -> Index { return _slice.index(before: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(before i: inout Index) {
    _slice.formIndex(before: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(r: Range<Index>) -> Substring.UTF8View {
    // FIXME(strings): tests.
    _precondition(r.lowerBound >= startIndex && r.upperBound <= endIndex,
      "UTF8View index range out of bounds")
    return Substring.UTF8View(_wholeString.utf8, _bounds: r)
  }
}

extension Substring {
  @inlinable // FIXME(sil-serialize-all)
  public var utf8: UTF8View {
    get {
      return UTF8View(_wholeString.utf8, _bounds: startIndex..<endIndex)
    }
    set {
      self = Substring(newValue)
    }
  }

  /// Creates a Substring having the given content.
  ///
  /// - Complexity: O(1)
  @inlinable // FIXME(sil-serialize-all)
  public init(_ content: UTF8View) {
    self = content._wholeString[content.startIndex..<content.endIndex]
  }
}

extension String {
  /// Creates a String having the given content.
  ///
  /// If `codeUnits` is an ill-formed code unit sequence, the result is `nil`.
  ///
  /// - Complexity: O(N), where N is the length of the resulting `String`'s
  ///   UTF-16.
  @inlinable // FIXME(sil-serialize-all)
  public init?(_ codeUnits: Substring.UTF8View) {
    let wholeString = codeUnits._wholeString
    guard
      codeUnits.startIndex.samePosition(in: wholeString.unicodeScalars) != nil
      && codeUnits.endIndex.samePosition(in: wholeString.unicodeScalars) != nil
    else { return nil }
    self = String(Substring(codeUnits))
  }
}
extension Substring {
  @_fixed_layout // FIXME(sil-serialize-all)
  public struct UTF16View {
    @usableFromInline // FIXME(sil-serialize-all)
    internal var _slice: Slice<String.UTF16View>
  }
}

extension Substring.UTF16View : BidirectionalCollection {
  public typealias Index = String.UTF16View.Index
  public typealias Indices = String.UTF16View.Indices
  public typealias Element = String.UTF16View.Element
  public typealias SubSequence = Substring.UTF16View

  /// Creates an instance that slices `base` at `_bounds`.
  @inlinable // FIXME(sil-serialize-all)
  internal init(_ base: String.UTF16View, _bounds: Range<Index>) {
    _slice = Slice(
      base: String(base._guts).utf16,
      bounds: _bounds)
  }

  /// The entire String onto whose slice this view is a projection.
  @inlinable // FIXME(sil-serialize-all)
  internal var _wholeString: String {
    return String(_slice._base._guts)
  }

  @inlinable // FIXME(sil-serialize-all)
  internal var _encodedOffsetRange: Range<Int> {
    return startIndex.encodedOffset..<endIndex.encodedOffset
  }

  //
  // Plumb slice operations through
  //
  @inlinable // FIXME(sil-serialize-all)
  public var startIndex: Index { return _slice.startIndex }

  @inlinable // FIXME(sil-serialize-all)
  public var endIndex: Index { return _slice.endIndex }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(index: Index) -> Element { return _slice[index] }

  @inlinable // FIXME(sil-serialize-all)
  public var indices: Indices { return _slice.indices }

  @inlinable // FIXME(sil-serialize-all)
  public func index(after i: Index) -> Index { return _slice.index(after: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(after i: inout Index) {
    _slice.formIndex(after: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    return _slice.index(i, offsetBy: n)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    return _slice.index(i, offsetBy: n, limitedBy: limit)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func distance(from start: Index, to end: Index) -> Int {
    return _slice.distance(from: start, to: end)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
    _slice._failEarlyRangeCheck(index, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(
    _ range: Range<Index>, bounds: Range<Index>
  ) {
    _slice._failEarlyRangeCheck(range, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(before i: Index) -> Index { return _slice.index(before: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(before i: inout Index) {
    _slice.formIndex(before: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(r: Range<Index>) -> Substring.UTF16View {
    // FIXME(strings): tests.
    _precondition(r.lowerBound >= startIndex && r.upperBound <= endIndex,
      "UTF16View index range out of bounds")
    return Substring.UTF16View(_wholeString.utf16, _bounds: r)
  }
}

extension Substring {
  @inlinable // FIXME(sil-serialize-all)
  public var utf16: UTF16View {
    get {
      return UTF16View(_wholeString.utf16, _bounds: startIndex..<endIndex)
    }
    set {
      self = Substring(newValue)
    }
  }

  /// Creates a Substring having the given content.
  ///
  /// - Complexity: O(1)
  @inlinable // FIXME(sil-serialize-all)
  public init(_ content: UTF16View) {
    self = content._wholeString[content.startIndex..<content.endIndex]
  }
}

extension String {
  /// Creates a String having the given content.
  ///
  /// If `codeUnits` is an ill-formed code unit sequence, the result is `nil`.
  ///
  /// - Complexity: O(N), where N is the length of the resulting `String`'s
  ///   UTF-16.
  @inlinable // FIXME(sil-serialize-all)
  public init?(_ codeUnits: Substring.UTF16View) {
    let wholeString = codeUnits._wholeString
    guard
      codeUnits.startIndex.samePosition(in: wholeString.unicodeScalars) != nil
      && codeUnits.endIndex.samePosition(in: wholeString.unicodeScalars) != nil
    else { return nil }
    self = String(Substring(codeUnits))
  }
}
extension Substring {
  @_fixed_layout // FIXME(sil-serialize-all)
  public struct UnicodeScalarView {
    @usableFromInline // FIXME(sil-serialize-all)
    internal var _slice: Slice<String.UnicodeScalarView>
  }
}

extension Substring.UnicodeScalarView : BidirectionalCollection {
  public typealias Index = String.UnicodeScalarView.Index
  public typealias Indices = String.UnicodeScalarView.Indices
  public typealias Element = String.UnicodeScalarView.Element
  public typealias SubSequence = Substring.UnicodeScalarView

  /// Creates an instance that slices `base` at `_bounds`.
  @inlinable // FIXME(sil-serialize-all)
  internal init(_ base: String.UnicodeScalarView, _bounds: Range<Index>) {
    _slice = Slice(
      base: String(base._guts).unicodeScalars,
      bounds: _bounds)
  }

  /// The entire String onto whose slice this view is a projection.
  @inlinable // FIXME(sil-serialize-all)
  internal var _wholeString: String {
    return String(_slice._base._guts)
  }

  @inlinable // FIXME(sil-serialize-all)
  internal var _encodedOffsetRange: Range<Int> {
    return startIndex.encodedOffset..<endIndex.encodedOffset
  }

  //
  // Plumb slice operations through
  //
  @inlinable // FIXME(sil-serialize-all)
  public var startIndex: Index { return _slice.startIndex }

  @inlinable // FIXME(sil-serialize-all)
  public var endIndex: Index { return _slice.endIndex }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(index: Index) -> Element { return _slice[index] }

  @inlinable // FIXME(sil-serialize-all)
  public var indices: Indices { return _slice.indices }

  @inlinable // FIXME(sil-serialize-all)
  public func index(after i: Index) -> Index { return _slice.index(after: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(after i: inout Index) {
    _slice.formIndex(after: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    return _slice.index(i, offsetBy: n)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    return _slice.index(i, offsetBy: n, limitedBy: limit)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func distance(from start: Index, to end: Index) -> Int {
    return _slice.distance(from: start, to: end)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(_ index: Index, bounds: Range<Index>) {
    _slice._failEarlyRangeCheck(index, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func _failEarlyRangeCheck(
    _ range: Range<Index>, bounds: Range<Index>
  ) {
    _slice._failEarlyRangeCheck(range, bounds: bounds)
  }

  @inlinable // FIXME(sil-serialize-all)
  public func index(before i: Index) -> Index { return _slice.index(before: i) }

  @inlinable // FIXME(sil-serialize-all)
  public func formIndex(before i: inout Index) {
    _slice.formIndex(before: &i)
  }

  @inlinable // FIXME(sil-serialize-all)
  public subscript(r: Range<Index>) -> Substring.UnicodeScalarView {
    // FIXME(strings): tests.
    _precondition(r.lowerBound >= startIndex && r.upperBound <= endIndex,
      "UnicodeScalarView index range out of bounds")
    return Substring.UnicodeScalarView(_wholeString.unicodeScalars, _bounds: r)
  }
}

extension Substring {
  @inlinable // FIXME(sil-serialize-all)
  public var unicodeScalars: UnicodeScalarView {
    get {
      return UnicodeScalarView(_wholeString.unicodeScalars, _bounds: startIndex..<endIndex)
    }
    set {
      self = Substring(newValue)
    }
  }

  /// Creates a Substring having the given content.
  ///
  /// - Complexity: O(1)
  @inlinable // FIXME(sil-serialize-all)
  public init(_ content: UnicodeScalarView) {
    self = content._wholeString[content.startIndex..<content.endIndex]
  }
}

extension String {
  /// Creates a String having the given content.
  ///
  /// - Complexity: O(N), where N is the length of the resulting `String`'s
  ///   UTF-16.
  @inlinable // FIXME(sil-serialize-all)
  public init(_ content: Substring.UnicodeScalarView) {
    self = String(Substring(content))
  }
}

// FIXME: The other String views should be RangeReplaceable too.
extension Substring.UnicodeScalarView : RangeReplaceableCollection {
  @inlinable // FIXME(sil-serialize-all)
  public init() { _slice = Slice.init() }

  @inlinable // FIXME(sil-serialize-all)
  public mutating func replaceSubrange<C : Collection>(
    _ target: Range<Index>, with replacement: C
  ) where C.Element == Element {
    _slice.replaceSubrange(target, with: replacement)
  }
}

extension Substring : RangeReplaceableCollection {
  @inlinable // FIXME(sil-serialize-all)
  public init<S : Sequence>(_ elements: S)
  where S.Element == Character {
    let e0 = elements as? _SwiftStringView
    if _fastPath(e0 != nil), let e = e0 {
      self.init(e._wholeString._guts, e._encodedOffsetRange)
    } else {
      self.init(String(elements))
    }
  }

  @inlinable // FIXME(sil-serialize-all)
  public mutating func append<S : Sequence>(contentsOf elements: S)
  where S.Element == Character {
    var string = String(self)
    self = Substring() // Keep unique storage if possible
    string.append(contentsOf: elements)
    self = Substring(string)
  }
}

extension Substring {
  @inlinable // FIXME(sil-serialize-all)
  public func lowercased() -> String {
    return String(self).lowercased()
  }

  @inlinable // FIXME(sil-serialize-all)
  public func uppercased() -> String {
    return String(self).uppercased()
  }

  @inlinable // FIXME(sil-serialize-all)
  public func filter(
    _ isIncluded: (Element) throws -> Bool
  ) rethrows -> String {
    return try String(self.lazy.filter(isIncluded))
  }
}

extension Substring : TextOutputStream {
  @inlinable // FIXME(sil-serialize-all)
  public mutating func write(_ other: String) {
    append(contentsOf: other)
  }
}

extension Substring : TextOutputStreamable {
  @inlinable // FIXME(sil-serialize-all)
  public func write<Target : TextOutputStream>(to target: inout Target) {
    target.write(String(self))
  }
}

extension Substring : ExpressibleByUnicodeScalarLiteral {
  @inlinable // FIXME(sil-serialize-all)
  public init(unicodeScalarLiteral value: String) {
     self.init(_base: value, value.startIndex ..< value.endIndex)
  }
}
extension Substring : ExpressibleByExtendedGraphemeClusterLiteral {
  @inlinable // FIXME(sil-serialize-all)
  public init(extendedGraphemeClusterLiteral value: String) {
     self.init(_base: value, value.startIndex ..< value.endIndex)
  }
}

extension Substring : ExpressibleByStringLiteral {
  @inlinable // FIXME(sil-serialize-all)
  public init(stringLiteral value: DefaultStringInterpolation) {
    let str = value.make()
    self.init(_base: str, str.startIndex ..< str.endIndex)
  }
}

//===--- String/Substring Slicing Support ---------------------------------===//
/// In Swift 3.2, in the absence of type context,
///
///     someString[someString.startIndex..<someString.endIndex]
///
/// was deduced to be of type `String`.  Therefore have a more-specific
/// Swift-3-only `subscript` overload on `String` (and `Substring`) that
/// continues to produce `String`.
extension String {
  @inlinable // FIXME(sil-serialize-all)
  @available(swift, introduced: 4)
  public subscript(r: Range<Index>) -> Substring {
    _boundsCheck(r)
    return Substring(
      _slice: Slice(base: self, bounds: r))
  }
}

extension Substring {
  @inlinable // FIXME(sil-serialize-all)
  @available(swift, introduced: 4)
  public subscript(r: Range<Index>) -> Substring {
    return Substring(_slice: _slice[r])
  }
}
