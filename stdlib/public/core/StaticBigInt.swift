//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// An immutable arbitrary-precision signed integer.
///
/// `StaticBigInt` is primarily intended to be used as the associated type of an
/// `ExpressibleByIntegerLiteral` conformance.
///
///     extension UInt256: ExpressibleByIntegerLiteral {
///         public init(integerLiteral value: StaticBigInt) {
///             precondition(
///                 value.signum() >= 0 && value.bitWidth <= 1 + Self.bitWidth,
///                 "integer overflow: '\(value)' as '\(Self.self)'"
///             )
///             self.words = Words()
///             for wordIndex in 0..<Words.count {
///                 self.words[wordIndex] = value[wordIndex]
///             }
///         }
///     }
@available(SwiftStdlib 5.8, *)
@frozen
public struct StaticBigInt:
  _ExpressibleByBuiltinIntegerLiteral,
  ExpressibleByIntegerLiteral,
  Sendable
{
  @available(SwiftStdlib 5.8, *)
  @usableFromInline
  internal let _value: Builtin.IntLiteral

  @available(SwiftStdlib 5.8, *)
  @inlinable
  public init(_builtinIntegerLiteral value: Builtin.IntLiteral) {
    _value = value
  }
}

//===----------------------------------------------------------------------===//
// MARK: - Binary Representation
//===----------------------------------------------------------------------===//

@available(SwiftStdlib 5.8, *)
extension StaticBigInt {

  /// Indicates the value's sign.
  ///
  /// - Returns: `-1` if the value is less than zero, `0` if it is equal to
  ///   zero, or `+1` if it is greater than zero.
  @available(SwiftStdlib 5.8, *)
  @inlinable
  public func signum() -> Int {
    _isNegative ? -1 : (bitWidth == 1) ? 0 : +1
  }

  @available(SwiftStdlib 5.8, *)
  @inlinable
  internal var _isNegative: Bool {
#if compiler(>=5.8) && $BuiltinIntLiteralAccessors
    Bool(Builtin.isNegative_IntLiteral(_value))
#else
    fatalError("Swift compiler is incompatible with this SDK version")
#endif
  }

  /// Returns the minimal number of bits in this value's binary representation,
  /// including the sign bit, and excluding the sign extension.
  ///
  /// The following examples show the least significant byte of each value's
  /// binary representation, separated (by an underscore) into excluded and
  /// included bits. Negative values are in two's complement.
  ///
  /// * `-4` (`0b11111_100`) is 3 bits.
  /// * `-3` (`0b11111_101`) is 3 bits.
  /// * `-2` (`0b111111_10`) is 2 bits.
  /// * `-1` (`0b1111111_1`) is 1 bit.
  /// * `+0` (`0b0000000_0`) is 1 bit.
  /// * `+1` (`0b000000_01`) is 2 bits.
  /// * `+2` (`0b00000_010`) is 3 bits.
  /// * `+3` (`0b00000_011`) is 3 bits.
  @available(SwiftStdlib 5.8, *)
  @inlinable
  public var bitWidth: Int {
#if compiler(>=5.8) && $BuiltinIntLiteralAccessors
    Int(Builtin.bitWidth_IntLiteral(_value))
#else
    fatalError("Swift compiler is incompatible with this SDK version")
#endif
  }

  /// Returns a 32-bit or 64-bit word of this value's binary representation.
  ///
  /// The words are ordered from least significant to most significant, with
  /// an infinite sign extension. Negative values are in two's complement.
  ///
  ///     let negative: StaticBigInt = -0x0011223344556677_8899AABBCCDDEEFF
  ///     negative.signum()  //-> -1
  ///     negative.bitWidth  //-> 118
  ///     negative[0]        //-> 0x7766554433221101
  ///     negative[1]        //-> 0xFFEEDDCCBBAA9988
  ///     negative[2]        //-> 0xFFFFFFFFFFFFFFFF
  ///
  ///     let positive: StaticBigInt =  0x0011223344556677_8899AABBCCDDEEFF
  ///     positive.signum()  //-> +1
  ///     positive.bitWidth  //-> 118
  ///     positive[0]        //-> 0x8899AABBCCDDEEFF
  ///     positive[1]        //-> 0x0011223344556677
  ///     positive[2]        //-> 0x0000000000000000
  ///
  /// - Parameter wordIndex: A nonnegative zero-based offset.
  @available(SwiftStdlib 5.8, *)
  @inlinable
  public subscript(_ wordIndex: Int) -> UInt {
    _precondition(wordIndex >= 0, "Negative word index")
    let bitIndex = wordIndex.multipliedReportingOverflow(by: UInt.bitWidth)
    guard !bitIndex.overflow, bitIndex.partialValue < bitWidth else {
      return _isNegative ? ~0 : 0
    }
#if compiler(>=5.8) && $BuiltinIntLiteralAccessors
    return UInt(
      Builtin.wordAtIndex_IntLiteral(_value, wordIndex._builtinWordValue)
    )
#else
    fatalError("Swift compiler is incompatible with this SDK version")
#endif
  }

  /// Returns this value's binary representation, as an infinite sequence of
  /// fixed-width elements.
  ///
  /// The elements are ordered from least significant to most significant, with
  /// an infinite sign extension. Negative values are in two's complement.
  ///
  ///     let value: StaticBigInt = 0x0011223344556677_8899AABBCCDDEEFF
  ///     value.signum()  //-> +1
  ///     value.bitWidth  //-> 118
  ///
  ///     value.sequence(of: UInt8.self).prefix(24).elementsEqual(
  ///         [0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88,
  ///          0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00,
  ///          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  ///     ) //-> true
  ///
  ///     value.sequence(of: UInt16.self).prefix(12).elementsEqual(
  ///         [0xEEFF, 0xCCDD, 0xAABB, 0x8899,
  ///          0x6677, 0x4455, 0x2233, 0x0011,
  ///          0x0000, 0x0000, 0x0000, 0x0000]
  ///     ) //-> true
  ///
  ///     value.sequence(of: UInt32.self).prefix(6).elementsEqual(
  ///         [0xCCDDEEFF, 0x8899AABB,
  ///          0x44556677, 0x00112233,
  ///          0x00000000, 0x00000000]
  ///     ) //-> true
  ///
  ///     value.sequence(of: UInt64.self).prefix(3).elementsEqual(
  ///         [0x8899AABBCCDDEEFF,
  ///          0x0011223344556677,
  ///          0x0000000000000000]
  ///     ) //-> true
  ///
  /// - Parameter elementType: A fixed-width unsigned integer type.
  /// - Returns: An infinite multi-pass sequence.
  @available(SwiftStdlib 5.8, *)
  @backDeployed(before: SwiftStdlib 9999)
  @warn_unqualified_access
  public func sequence<Element>(
    of elementType: Element.Type
  ) -> some Sequence<Element> where
    Element: _ExpressibleByBuiltinIntegerLiteral,
    Element: FixedWidthInteger,
    Element: UnsignedInteger
  {
    typealias State = (bitIndex: Int, word: UInt)
    let state: State = (0, 0)
    let next: (inout State) -> Element?
    let signExtension: Element = _isNegative ? ~0 : 0
    if Element.bitWidth.isMultiple(of: UInt.bitWidth) {
      // Specialize for a multi-word element type.
      next = { [bitWidth, signExtension] state in
        guard state.bitIndex < bitWidth else { return signExtension }
        var result: Element = 0
        for _ in stride(from: 0, to: Element.bitWidth, by: UInt.bitWidth) {
          let wordIndex = state.bitIndex >> UInt.bitWidth.trailingZeroBitCount
          state.word = self[wordIndex]
          result |= Element(_truncatingBits: state.word) &<< state.bitIndex
          state.bitIndex += UInt.bitWidth
        }
        return result
      }
    } else if UInt.bitWidth.isMultiple(of: Element.bitWidth) {
      // Specialize for a multi-element word type.
      next = { [bitWidth, signExtension] state in
        guard state.bitIndex < bitWidth else { return signExtension }
        if state.bitIndex.isMultiple(of: UInt.bitWidth) {
          let wordIndex = state.bitIndex >> UInt.bitWidth.trailingZeroBitCount
          state.word = self[wordIndex]
        }
        let result = Element(_truncatingBits: state.word &>> state.bitIndex)
        state.bitIndex += Element.bitWidth
        return result
      }
    } else {
      fatalError("Unsupported element type")
    }
    return Swift.sequence(state: state, next: next)
  }
}

//===----------------------------------------------------------------------===//
// MARK: - Textual Representation
//===----------------------------------------------------------------------===//

@available(SwiftStdlib 5.8, *)
extension StaticBigInt: CustomDebugStringConvertible {

  @available(SwiftStdlib 5.8, *)
  public var debugDescription: String {
    let isNegative = _isNegative
    let indicator = isNegative ? "-0x" : "+0x"

    // Equivalent to `ceil(bitWidthExcludingSignBit / fourBitsPerHexDigit)`.
    // Underestimated for `-(16 ** y)` values (e.g. "-0x1", "-0x10", "-0x100").
    let capacity = indicator.utf8.count + (((bitWidth - 1) + 3) / 4)
    var result = String(unsafeUninitializedCapacity: capacity) { utf8 in

      // Pre-initialize with zeros, ignoring extra capacity.
      var utf8 = utf8.prefix(capacity)
      utf8.initialize(repeating: UInt8(ascii: "0"))

      // Use a 32-bit element type, to generate small hexadecimal strings.
      typealias Element = UInt32
      let hexDigitsPerElement = Element.bitWidth / 4
      _internalInvariant(hexDigitsPerElement <= _SmallString.capacity)

      // Lazily compute the magnitude, starting with the least significant bits.
      var overflow = isNegative
      for var element in self.sequence(of: Element.self) {
        if isNegative {
          element = ~element
          if overflow {
            (element, overflow) = element.addingReportingOverflow(1)
          }
        }

        // Overwrite trailing zeros with hexadecimal digits.
        let hexDigits = String(element, radix: 16, uppercase: true).utf8
        _ = utf8.suffix(hexDigits.count).update(fromContentsOf: hexDigits)
        utf8 = utf8.dropLast(hexDigitsPerElement)
        guard !utf8.isEmpty else { break }
      }
      return capacity
    }

    // Overwrite leading zeros with the "±0x" indicator.
    if let upToIndex = result.firstIndex(where: { $0 != "0" }) {
      result.replaceSubrange(..<upToIndex, with: indicator)
    } else {
      result = "+0x0"
    }
    return result
  }
}

#if SWIFT_ENABLE_REFLECTION
@available(SwiftStdlib 5.8, *)
extension StaticBigInt: CustomReflectable {

  @available(SwiftStdlib 5.8, *)
  public var customMirror: Mirror {
    Mirror(self, unlabeledChildren: EmptyCollection<Void>())
  }
}
#endif
