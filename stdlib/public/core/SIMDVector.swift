//===--- SIMDVector.swift -------------------------------------*- swift -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

infix operator .==: ComparisonPrecedence
infix operator .!=: ComparisonPrecedence
infix operator .<: ComparisonPrecedence
infix operator .<=: ComparisonPrecedence
infix operator .>: ComparisonPrecedence
infix operator .>=: ComparisonPrecedence

infix operator .&: LogicalConjunctionPrecedence
infix operator .^: LogicalDisjunctionPrecedence
infix operator .|: LogicalDisjunctionPrecedence
infix operator .&=: AssignmentPrecedence
infix operator .^=: AssignmentPrecedence
infix operator .|=: AssignmentPrecedence
prefix operator .!

/// A type that can function as storage for a SIMD vector type.
///
/// The `SIMDStorage` protocol defines a storage layout and provides
/// elementwise accesses. Computational operations are defined on the `SIMD`
/// protocol, which refines this protocol, and on the concrete types that
/// conform to `SIMD`.
public protocol SIMDStorage {
  /// The type of scalars in the vector space.
  associatedtype Scalar: Codable, Hashable
  
  /// The number of scalars, or elements, in the vector.
  var scalarCount: Int { get }
  
  /// Creates a vector with zero in all lanes.
  init()
  
  /// Accesses the element at the specified index.
  ///
  /// - Parameter index: The index of the element to access. `index` must be in
  ///   the range `0..<scalarCount`.
  subscript(index: Int) -> Scalar { get set }
}

extension SIMDStorage {
  /// The number of scalars, or elements, in a vector of this type.
  @_alwaysEmitIntoClient
  public static var scalarCount: Int {
    // Wouldn't it make more sense to define the instance var in terms of the
    // static var? Yes, probably, but by doing it this way we make the static
    // var backdeployable.
    return Self().scalarCount
  }
}

/// A type that can be used as an element in a SIMD vector.
public protocol SIMDScalar {
  associatedtype SIMDMaskScalar: SIMDScalar & FixedWidthInteger & SignedInteger
  associatedtype SIMD2Storage: SIMDStorage where SIMD2Storage.Scalar == Self
  associatedtype SIMD4Storage: SIMDStorage where SIMD4Storage.Scalar == Self
  associatedtype SIMD8Storage: SIMDStorage where SIMD8Storage.Scalar == Self
  associatedtype SIMD16Storage: SIMDStorage where SIMD16Storage.Scalar == Self
  associatedtype SIMD32Storage: SIMDStorage where SIMD32Storage.Scalar == Self
  associatedtype SIMD64Storage: SIMDStorage where SIMD64Storage.Scalar == Self
}

/// A SIMD vector of a fixed number of elements.
public protocol SIMD: SIMDStorage,
                      Codable,
                      Hashable,
                      CustomStringConvertible,
                      ExpressibleByArrayLiteral {
  /// The mask type resulting from pointwise comparisons of this vector type.
  associatedtype MaskStorage: SIMD
    where MaskStorage.Scalar: FixedWidthInteger & SignedInteger
}

extension SIMD {
  /// The valid indices for subscripting the vector.
  @_transparent
  public var indices: Range<Int> {
    return 0 ..< scalarCount
  }
  
  /// A vector with the specified value in all lanes.
  @_transparent
  public init(repeating value: Scalar) {
    self.init()
    for i in indices { self[i] = value }
  }
  
  /// Returns a Boolean value indicating whether two vectors are equal.
  @_transparent
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    var result = true
    for i in lhs.indices { result = result && lhs[i] == rhs[i] }
    return result
  }
  
  /// Hashes the elements of the vector using the given hasher.
  @inlinable
  public func hash(into hasher: inout Hasher) {
    for i in indices { hasher.combine(self[i]) }
  }
  
  /// Encodes the scalars of this vector into the given encoder in an unkeyed
  /// container.
  ///
  /// This function throws an error if any values are invalid for the given
  /// encoder's format.
  ///
  /// - Parameter encoder: The encoder to write data to.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    for i in indices {
      try container.encode(self[i])
    }
  }
  
  /// Creates a new vector by decoding scalars from the given decoder.
  ///
  /// This initializer throws an error if reading from the decoder fails, or
  /// if the data read is corrupted or otherwise invalid.
  ///
  /// - Parameter decoder: The decoder to read data from.
  public init(from decoder: Decoder) throws {
    self.init()
    var container = try decoder.unkeyedContainer()
    guard container.count == scalarCount else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Expected vector with exactly \(scalarCount) elements."
        )
      )
    }
    for i in indices {
      self[i] = try container.decode(Scalar.self)
    }
  }
  
  /// A textual description of the vector.
  public var description: String {
    get {
      return "\(Self.self)(" + indices.map({"\(self[$0])"}).joined(separator: ", ") + ")"
    }
  }
  
  /// Returns a vector mask with the result of a pointwise equality comparison.
  @_transparent
  public static func .==(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    var result = SIMDMask<MaskStorage>()
    for i in result.indices { result[i] = lhs[i] == rhs[i] }
    return result
  }
  
  /// Returns a vector mask with the result of a pointwise inequality
  /// comparison.
  @_transparent
  public static func .!=(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    var result = SIMDMask<MaskStorage>()
    for i in result.indices { result[i] = lhs[i] != rhs[i] }
    return result
  }
  
  /// Replaces elements of this vector with elements of `other` in the lanes
  /// where `mask` is `true`.
  @_transparent
  public mutating func replace(with other: Self, where mask: SIMDMask<MaskStorage>) {
    for i in indices { self[i] = mask[i] ? other[i] : self[i] }
  }
  
  /// Creates a vector from the specified elements.
  ///
  /// - Parameter scalars: The elements to use in the vector. `scalars` must
  ///   have the same number of elements as the vector type.
  @inlinable
  public init(arrayLiteral scalars: Scalar...) {
    self.init(scalars)
  }
  
  /// Creates a vector from the given sequence.
  ///
  /// - Precondition: `scalars` must have the same number of elements as the
  ///   vector type.
  ///
  /// - Parameter scalars: The elements to use in the vector.
  @inlinable
  public init<S: Sequence>(_ scalars: S) where S.Element == Scalar {
    self.init()
    var index = 0
    for scalar in scalars {
      if index == scalarCount {
        _preconditionFailure("Too many elements in sequence.")
      }
      self[index] = scalar
      index += 1
    }
    if index < scalarCount {
      _preconditionFailure("Not enough elements in sequence.")
    }
  }
  
  /// Extracts the scalars at specified indices to form a SIMD2.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD2<Index>) -> SIMD2<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD2<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD3.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD3<Index>) -> SIMD3<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD3<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD4.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD4<Index>) -> SIMD4<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD4<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD8.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD8<Index>) -> SIMD8<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD8<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD16.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD16<Index>) -> SIMD16<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD16<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD32.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD32<Index>) -> SIMD32<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD32<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
  
  /// Extracts the scalars at specified indices to form a SIMD64.
  ///
  /// The elements of the index vector are wrapped modulo the count of elements
  /// in this vector. Because of this, the index is always in-range and no trap
  /// can occur.
  @_alwaysEmitIntoClient
  public subscript<Index>(index: SIMD64<Index>) -> SIMD64<Scalar>
  where Index: FixedWidthInteger {
    var result = SIMD64<Scalar>()
    for i in result.indices {
      result[i] = self[Int(index[i]) % scalarCount]
    }
    return result
  }
}

//  Implementations of comparison operations. These should eventually all
//  be replaced with @_semantics to lower directly to vector IR nodes.
extension SIMD where Scalar: Comparable {
  /// Returns a vector mask with the result of a pointwise less than
  /// comparison.
  @_transparent
  public static func .<(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    var result = SIMDMask<MaskStorage>()
    for i in result.indices { result[i] = lhs[i] < rhs[i] }
    return result
  }
  
  /// Returns a vector mask with the result of a pointwise less than or equal
  /// comparison.
  @_transparent
  public static func .<=(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    var result = SIMDMask<MaskStorage>()
    for i in result.indices { result[i] = lhs[i] <= rhs[i] }
    return result
  }
  
  /// The least element in the vector.
  @_alwaysEmitIntoClient
  public func min() -> Scalar {
    return indices.reduce(into: self[0]) { $0 = Swift.min($0, self[$1]) }
  }
  
  /// The greatest element in the vector.
  @_alwaysEmitIntoClient
  public func max() -> Scalar {
    return indices.reduce(into: self[0]) { $0 = Swift.max($0, self[$1]) }
  }
}

//  These operations should never need @_semantics; they should be trivial
//  wrappers around the core operations defined above.
extension SIMD {
  /// Returns a vector mask with the result of a pointwise equality comparison.
  @_transparent
  public static func .==(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .== rhs
  }

  /// Returns a vector mask with the result of a pointwise inequality comparison.
  @_transparent
  public static func .!=(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .!= rhs
  }

  /// Returns a vector mask with the result of a pointwise equality comparison.
  @_transparent
  public static func .==(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .== Self(repeating: rhs)
  }

  /// Returns a vector mask with the result of a pointwise inequality comparison.
  @_transparent
  public static func .!=(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .!= Self(repeating: rhs)
  }
  
  /// Replaces elements of this vector with `other` in the lanes where `mask`
  /// is `true`.
  @_transparent
  public mutating func replace(with other: Scalar, where mask: SIMDMask<MaskStorage>) {
    replace(with: Self(repeating: other), where: mask)
  }
  
  /// Returns a copy of this vector, with elements replaced by elements of
  /// `other` in the lanes where `mask` is `true`.
  @_transparent
  public func replacing(with other: Self, where mask: SIMDMask<MaskStorage>) -> Self {
    var result = self
    result.replace(with: other, where: mask)
    return result
  }
  
  /// Returns a copy of this vector, with elements `other` in the lanes where
  /// `mask` is `true`.
  @_transparent
  public func replacing(with other: Scalar, where mask: SIMDMask<MaskStorage>) -> Self {
    return replacing(with: Self(repeating: other), where: mask)
  }
}

extension SIMD where Scalar: Comparable {
  /// Returns a vector mask with the result of a pointwise greater than or
  /// equal comparison.
  @_transparent
  public static func .>=(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    return rhs .<= lhs
  }

  /// Returns a vector mask with the result of a pointwise greater than
  /// comparison.
  @_transparent
  public static func .>(lhs: Self, rhs: Self) -> SIMDMask<MaskStorage> {
    return rhs .< lhs
  }

  /// Returns a vector mask with the result of a pointwise less than comparison.
  @_transparent
  public static func .<(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .< rhs
  }

  /// Returns a vector mask with the result of a pointwise less than or equal
  /// comparison.
  @_transparent
  public static func .<=(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .<= rhs
  }

  /// Returns a vector mask with the result of a pointwise greater than or
  /// equal comparison.
  @_transparent
  public static func .>=(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .>= rhs
  }

  /// Returns a vector mask with the result of a pointwise greater than
  /// comparison.
  @_transparent
  public static func .>(lhs: Scalar, rhs: Self) -> SIMDMask<MaskStorage> {
    return Self(repeating: lhs) .> rhs
  }

  /// Returns a vector mask with the result of a pointwise less than comparison.
  @_transparent
  public static func .<(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .< Self(repeating: rhs)
  }

  /// Returns a vector mask with the result of a pointwise less than or equal
  /// comparison.
  @_transparent
  public static func .<=(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .<= Self(repeating: rhs)
  }
  
  /// Returns a vector mask with the result of a pointwise greater than or
  /// equal comparison.
  @_transparent
  public static func .>=(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .>= Self(repeating: rhs)
  }
  
  /// Returns a vector mask with the result of a pointwise greater than
  /// comparison.
  @_transparent
  public static func .>(lhs: Self, rhs: Scalar) -> SIMDMask<MaskStorage> {
    return lhs .> Self(repeating: rhs)
  }
  
  @_alwaysEmitIntoClient
  public mutating func clamp(lowerBound: Self, upperBound: Self) {
    self = self.clamped(lowerBound: lowerBound, upperBound: upperBound)
  }

  @_alwaysEmitIntoClient
  public func clamped(lowerBound: Self, upperBound: Self) -> Self {
    return pointwiseMin(upperBound, pointwiseMax(lowerBound, self))
  }
}

extension SIMD where Scalar: FixedWidthInteger {
  /// A vector with zero in all lanes.
  @_transparent
  public static var zero: Self {
    return Self()
  }
  
  /// A vector with one in all lanes.
  @_alwaysEmitIntoClient
  public static var one: Self {
    return Self(repeating: 1)
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes, using the given generator as a source for randomness.
  @inlinable
  public static func random<T: RandomNumberGenerator>(
    in range: Range<Scalar>,
    using generator: inout T
  ) -> Self {
    var result = Self()
    for i in result.indices {
      result[i] = Scalar.random(in: range, using: &generator)
    }
    return result
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes.
  @inlinable
  public static func random(in range: Range<Scalar>) -> Self {
    var g = SystemRandomNumberGenerator()
    return Self.random(in: range, using: &g)
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes, using the given generator as a source for randomness.
  @inlinable
  public static func random<T: RandomNumberGenerator>(
    in range: ClosedRange<Scalar>,
    using generator: inout T
  ) -> Self {
    var result = Self()
    for i in result.indices {
      result[i] = Scalar.random(in: range, using: &generator)
    }
    return result
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes.
  @inlinable
  public static func random(in range: ClosedRange<Scalar>) -> Self {
    var g = SystemRandomNumberGenerator()
    return Self.random(in: range, using: &g)
  }
}

extension SIMD where Scalar: FloatingPoint {
  /// A vector with zero in all lanes.
  @_transparent
  public static var zero: Self {
    return Self()
  }
  
  /// A vector with one in all lanes.
  @_alwaysEmitIntoClient
  public static var one: Self {
    return Self(repeating: 1)
  }
  
  @_alwaysEmitIntoClient
  public mutating func clamp(lowerBound: Self, upperBound: Self) {
    self = self.clamped(lowerBound: lowerBound, upperBound: upperBound)
  }

  @_alwaysEmitIntoClient
  public func clamped(lowerBound: Self, upperBound: Self) -> Self {
    return pointwiseMin(upperBound, pointwiseMax(lowerBound, self))
  }
}

extension SIMD
where Scalar: BinaryFloatingPoint, Scalar.RawSignificand: FixedWidthInteger {
  /// Returns a vector with random values from within the specified range in
  /// all lanes, using the given generator as a source for randomness.
  @inlinable
  public static func random<T: RandomNumberGenerator>(
    in range: Range<Scalar>,
    using generator: inout T
  ) -> Self {
    var result = Self()
    for i in result.indices {
      result[i] = Scalar.random(in: range, using: &generator)
    }
    return result
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes.
  @inlinable
  public static func random(in range: Range<Scalar>) -> Self {
    var g = SystemRandomNumberGenerator()
    return Self.random(in: range, using: &g)
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes, using the given generator as a source for randomness.
  @inlinable
  public static func random<T: RandomNumberGenerator>(
    in range: ClosedRange<Scalar>,
    using generator: inout T
  ) -> Self {
    var result = Self()
    for i in result.indices {
      result[i] = Scalar.random(in: range, using: &generator)
    }
    return result
  }
  
  /// Returns a vector with random values from within the specified range in
  /// all lanes.
  @inlinable
  public static func random(in range: ClosedRange<Scalar>) -> Self {
    var g = SystemRandomNumberGenerator()
    return Self.random(in: range, using: &g)
  }
}

@frozen
public struct SIMDMask<Storage>: SIMD
                  where Storage: SIMD,
                 Storage.Scalar: FixedWidthInteger & SignedInteger {
  
  public var _storage: Storage
  
  public typealias MaskStorage = Storage
  
  public typealias Scalar = Bool
  
  @_transparent
  public var scalarCount: Int {
    return _storage.scalarCount
  }
  
  @_transparent
  public init() {
    _storage = Storage()
  }
  
  @_transparent
  public init(_ _storage: Storage) {
    self._storage = _storage
  }
  
  public subscript(index: Int) -> Bool {
    @_transparent
    get {
      _precondition(indices.contains(index))
      return _storage[index] < 0
    }
    @_transparent
    set {
      _precondition(indices.contains(index))
      _storage[index] = newValue ? -1 : 0
    }
  }
}

extension SIMDMask {
  /// Returns a vector mask with `true` or `false` randomly assigned in each
  /// lane, using the given generator as a source for randomness.
  @inlinable
  public static func random<T: RandomNumberGenerator>(using generator: inout T) -> SIMDMask {
    var result = SIMDMask()
    for i in result.indices { result[i] = Bool.random(using: &generator) }
    return result
  }
  
  /// Returns a vector mask with `true` or `false` randomly assigned in each
  /// lane.
  @inlinable
  public static func random() -> SIMDMask {
    var g = SystemRandomNumberGenerator()
    return SIMDMask.random(using: &g)
  }
}

//  Implementations of integer operations. These should eventually all
//  be replaced with @_semantics to lower directly to vector IR nodes.
extension SIMD where Scalar: FixedWidthInteger {
  @_transparent
  public var leadingZeroBitCount: Self {
    var result = Self()
    for i in indices { result[i] = Scalar(self[i].leadingZeroBitCount) }
    return result
  }
  
  @_transparent
  public var trailingZeroBitCount: Self {
    var result = Self()
    for i in indices { result[i] = Scalar(self[i].trailingZeroBitCount) }
    return result
  }
  
  @_transparent
  public var nonzeroBitCount: Self {
    var result = Self()
    for i in indices { result[i] = Scalar(self[i].nonzeroBitCount) }
    return result
  }
  
  @_transparent
  public static prefix func ~(rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = ~rhs[i] }
    return result
  }
  
  @_transparent
  public static func &(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] & rhs[i] }
    return result
  }
  
  @_transparent
  public static func ^(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] ^ rhs[i] }
    return result
  }
  
  @_transparent
  public static func |(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] | rhs[i] }
    return result
  }
  
  @_transparent
  public static func &<<(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] &<< rhs[i] }
    return result
  }
  
  @_transparent
  public static func &>>(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] &>> rhs[i] }
    return result
  }
  
  @_transparent
  public static func &+(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] &+ rhs[i] }
    return result
  }
  
  @_transparent
  public static func &-(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] &- rhs[i] }
    return result
  }
  
  @_transparent
  public static func &*(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] &* rhs[i] }
    return result
  }
  
  @_transparent
  public static func /(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] / rhs[i] }
    return result
  }
  
  @_transparent
  public static func %(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] % rhs[i] }
    return result
  }
  
  /// Returns the sum of the scalars in the vector, computed with wrapping
  /// addition.
  ///
  /// Equivalent to indices.reduce(into: 0) { $0 &+= self[$1] }.
  @_alwaysEmitIntoClient
  public func wrappedSum() -> Scalar {
    return indices.reduce(into: 0) { $0 &+= self[$1] }
  }
}

//  Implementations of floating-point operations. These should eventually all
//  be replaced with @_semantics to lower directly to vector IR nodes.
extension SIMD where Scalar : FloatingPoint {
  @_transparent
  public static func +(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] + rhs[i] }
    return result
  }
  
  @_transparent
  public static func -(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] - rhs[i] }
    return result
  }
  
  @_transparent
  public static func *(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] * rhs[i] }
    return result
  }
  
  @_transparent
  public static func /(lhs: Self, rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = lhs[i] / rhs[i] }
    return result
  }
  
  @_transparent
  public func addingProduct(_ lhs: Self, _ rhs: Self) -> Self {
    var result = Self()
    for i in result.indices { result[i] = self[i].addingProduct(lhs[i], rhs[i]) }
    return result
  }
  
  @_transparent
  public func squareRoot( ) -> Self {
    var result = Self()
    for i in result.indices { result[i] = self[i].squareRoot() }
    return result
  }
  
  @_transparent
  public func rounded(_ rule: FloatingPointRoundingRule) -> Self {
    var result = Self()
    for i in result.indices { result[i] = self[i].rounded(rule) }
    return result
  }
  
  /// Returns the least scalar in the vector.
  @_alwaysEmitIntoClient
  public func min() -> Scalar {
    return indices.reduce(into: self[0]) { $0 = Scalar.minimum($0, self[$1]) }
  }
  
  /// Returns the greatest scalar in the vector.
  @_alwaysEmitIntoClient
  public func max() -> Scalar {
    return indices.reduce(into: self[0]) { $0 = Scalar.maximum($0, self[$1]) }
  }
  
  /// Returns the sum of the scalars in the vector.
  // SWIFT_ENABLE_TENSORFLOW
  // FIXME: TF-545 we want the sum() func to be marked as
  // `@_alwaysEmitIntoClient` like before when we define the VJP
  @inlinable
  public func sum() -> Scalar {
    // Implementation note: this eventually be defined to lower to either
    // llvm.experimental.vector.reduce.fadd or an explicit tree-sum. Open-
    // coding the tree sum is problematic, we probably need to define a
    // Swift Builtin to support it.
    return indices.reduce(into: 0) { $0 += self[$1] }
  }
}

extension SIMDMask {
  @_transparent
  public static prefix func .!(rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(~rhs._storage)
  }
  
  @_transparent
  public static func .&(lhs: SIMDMask, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(lhs._storage & rhs._storage)
  }
  
  @_transparent
  public static func .^(lhs: SIMDMask, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(lhs._storage ^ rhs._storage)
  }
  
  @_transparent
  public static func .|(lhs: SIMDMask, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(lhs._storage | rhs._storage)
  }
}

//  These operations should never need @_semantics; they should be trivial
//  wrappers around the core operations defined above.
extension SIMD where Scalar: FixedWidthInteger {
  
  @_transparent
  public static func &(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) & rhs
  }
  
  @_transparent
  public static func ^(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) ^ rhs
  }
  
  @_transparent
  public static func |(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) | rhs
  }
  
  @_transparent
  public static func &<<(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) &<< rhs
  }
  
  @_transparent
  public static func &>>(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) &>> rhs
  }
  
  @_transparent
  public static func &+(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) &+ rhs
  }
  
  @_transparent
  public static func &-(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) &- rhs
  }
  
  @_transparent
  public static func &*(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) &* rhs
  }
  
  @_transparent
  public static func /(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) / rhs
  }
  
  @_transparent
  public static func %(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) % rhs
  }
  
  @_transparent
  public static func &(lhs: Self, rhs: Scalar) -> Self {
    return lhs & Self(repeating: rhs)
  }
  
  @_transparent
  public static func ^(lhs: Self, rhs: Scalar) -> Self {
    return lhs ^ Self(repeating: rhs)
  }
  
  @_transparent
  public static func |(lhs: Self, rhs: Scalar) -> Self {
    return lhs | Self(repeating: rhs)
  }
  
  @_transparent
  public static func &<<(lhs: Self, rhs: Scalar) -> Self {
    return lhs &<< Self(repeating: rhs)
  }
  
  @_transparent
  public static func &>>(lhs: Self, rhs: Scalar) -> Self {
    return lhs &>> Self(repeating: rhs)
  }
  
  @_transparent
  public static func &+(lhs: Self, rhs: Scalar) -> Self {
    return lhs &+ Self(repeating: rhs)
  }
  
  @_transparent
  public static func &-(lhs: Self, rhs: Scalar) -> Self {
    return lhs &- Self(repeating: rhs)
  }
  
  @_transparent
  public static func &*(lhs: Self, rhs: Scalar) -> Self {
    return lhs &* Self(repeating: rhs)
  }
  
  @_transparent
  public static func /(lhs: Self, rhs: Scalar) -> Self {
    return lhs / Self(repeating: rhs)
  }
  
  @_transparent
  public static func %(lhs: Self, rhs: Scalar) -> Self {
    return lhs % Self(repeating: rhs)
  }
  
  @_transparent
  public static func &=(lhs: inout Self, rhs: Self) {
    lhs = lhs & rhs
  }
  
  @_transparent
  public static func ^=(lhs: inout Self, rhs: Self) {
    lhs = lhs ^ rhs
  }
  
  @_transparent
  public static func |=(lhs: inout Self, rhs: Self) {
    lhs = lhs | rhs
  }
  
  @_transparent
  public static func &<<=(lhs: inout Self, rhs: Self) {
    lhs = lhs &<< rhs
  }
  
  @_transparent
  public static func &>>=(lhs: inout Self, rhs: Self) {
    lhs = lhs &>> rhs
  }
  
  @_transparent
  public static func &+=(lhs: inout Self, rhs: Self) {
    lhs = lhs &+ rhs
  }
  
  @_transparent
  public static func &-=(lhs: inout Self, rhs: Self) {
    lhs = lhs &- rhs
  }
  
  @_transparent
  public static func &*=(lhs: inout Self, rhs: Self) {
    lhs = lhs &* rhs
  }
  
  @_transparent
  public static func /=(lhs: inout Self, rhs: Self) {
    lhs = lhs / rhs
  }
  
  @_transparent
  public static func %=(lhs: inout Self, rhs: Self) {
    lhs = lhs % rhs
  }
  
  @_transparent
  public static func &=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs & rhs
  }
  
  @_transparent
  public static func ^=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs ^ rhs
  }
  
  @_transparent
  public static func |=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs | rhs
  }
  
  @_transparent
  public static func &<<=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs &<< rhs
  }
  
  @_transparent
  public static func &>>=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs &>> rhs
  }
  
  @_transparent
  public static func &+=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs &+ rhs
  }
  
  @_transparent
  public static func &-=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs &- rhs
  }
  
  @_transparent
  public static func &*=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs &* rhs
  }
  
  @_transparent
  public static func /=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs / rhs
  }
  
  @_transparent
  public static func %=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs % rhs
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&+' instead")
  public static func +(lhs: Self, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&-' instead")
  public static func -(lhs: Self, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&*' instead")
  public static func *(lhs: Self, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&+' instead")
  public static func +(lhs: Self, rhs: Scalar) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&-' instead")
  public static func -(lhs: Self, rhs: Scalar) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&*' instead")
  public static func *(lhs: Self, rhs: Scalar) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&+' instead")
  public static func +(lhs: Scalar, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&-' instead")
  public static func -(lhs: Scalar, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&*' instead")
  public static func *(lhs: Scalar, rhs: Self) -> Self {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&+=' instead")
  public static func +=(lhs: inout Self, rhs: Self) {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&-=' instead")
  public static func -=(lhs: inout Self, rhs: Self) {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&*=' instead")
  public static func *=(lhs: inout Self, rhs: Self) {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&+=' instead")
  public static func +=(lhs: inout Self, rhs: Scalar) {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&-=' instead")
  public static func -=(lhs: inout Self, rhs: Scalar) {
    fatalError()
  }
  
  @available(*, unavailable, message: "integer vector types do not support checked arithmetic; use the wrapping operator '&*=' instead")
  public static func *=(lhs: inout Self, rhs: Scalar) {
    fatalError()
  }
}

extension SIMD where Scalar: FloatingPoint {
  
  @_transparent
  public static prefix func -(rhs: Self) -> Self {
    return 0 - rhs
  }
  
  @_transparent
  public static func +(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) + rhs
  }
  
  @_transparent
  public static func -(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) - rhs
  }
  
  @_transparent
  public static func *(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) * rhs
  }
  
  @_transparent
  public static func /(lhs: Scalar, rhs: Self) -> Self {
    return Self(repeating: lhs) / rhs
  }
  
  @_transparent
  public static func +(lhs: Self, rhs: Scalar) -> Self {
    return lhs + Self(repeating: rhs)
  }
  
  @_transparent
  public static func -(lhs: Self, rhs: Scalar) -> Self {
    return lhs - Self(repeating: rhs)
  }
  
  @_transparent
  public static func *(lhs: Self, rhs: Scalar) -> Self {
    return lhs * Self(repeating: rhs)
  }
  
  @_transparent
  public static func /(lhs: Self, rhs: Scalar) -> Self {
    return lhs / Self(repeating: rhs)
  }
  
  @_transparent
  public static func *=(lhs: inout Self, rhs: Self) {
    lhs = lhs * rhs
  }
  
  @_transparent
  public static func /=(lhs: inout Self, rhs: Self) {
    lhs = lhs / rhs
  }
  
  @_transparent
  public static func +=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs + rhs
  }
  
  @_transparent
  public static func -=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs - rhs
  }
  
  @_transparent
  public static func *=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs * rhs
  }
  
  @_transparent
  public static func /=(lhs: inout Self, rhs: Scalar) {
    lhs = lhs / rhs
  }
  
  @_transparent
  public func addingProduct(_ lhs: Scalar, _ rhs: Self) -> Self {
    return self.addingProduct(Self(repeating: lhs), rhs)
  }
  
  @_transparent
  public func addingProduct(_ lhs: Self, _ rhs: Scalar) -> Self {
    return self.addingProduct(lhs, Self(repeating: rhs))
  }
  
  @_transparent
  public mutating func addProduct(_ lhs: Self, _ rhs: Self) {
    self = self.addingProduct(lhs, rhs)
  }
  
  @_transparent
  public mutating func addProduct(_ lhs: Scalar, _ rhs: Self) {
    self = self.addingProduct(lhs, rhs)
  }
  
  @_transparent
  public mutating func addProduct(_ lhs: Self, _ rhs: Scalar) {
    self = self.addingProduct(lhs, rhs)
  }
  
  @_transparent
  public mutating func formSquareRoot( ) {
    self = self.squareRoot()
  }
  
  @_transparent
  public mutating func round(_ rule: FloatingPointRoundingRule) {
    self = self.rounded(rule)
  }
}

extension SIMDMask {
  @_transparent
  public static func .&(lhs: Bool, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(repeating: lhs) .& rhs
  }
  
  @_transparent
  public static func .^(lhs: Bool, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(repeating: lhs) .^ rhs
  }
  
  @_transparent
  public static func .|(lhs: Bool, rhs: SIMDMask) -> SIMDMask {
    return SIMDMask(repeating: lhs) .| rhs
  }
  
  @_transparent
  public static func .&(lhs: SIMDMask, rhs: Bool) -> SIMDMask {
    return lhs .& SIMDMask(repeating: rhs)
  }
  
  @_transparent
  public static func .^(lhs: SIMDMask, rhs: Bool) -> SIMDMask {
    return lhs .^ SIMDMask(repeating: rhs)
  }
  
  @_transparent
  public static func .|(lhs: SIMDMask, rhs: Bool) -> SIMDMask {
    return lhs .| SIMDMask(repeating: rhs)
  }
  
  @_transparent
  public static func .&=(lhs: inout SIMDMask, rhs: SIMDMask) {
    lhs = lhs .& rhs
  }
  
  @_transparent
  public static func .^=(lhs: inout SIMDMask, rhs: SIMDMask) {
    lhs = lhs .^ rhs
  }
  
  @_transparent
  public static func .|=(lhs: inout SIMDMask, rhs: SIMDMask) {
    lhs = lhs .| rhs
  }
  
  @_transparent
  public static func .&=(lhs: inout SIMDMask, rhs: Bool) {
    lhs = lhs .& rhs
  }
  
  @_transparent
  public static func .^=(lhs: inout SIMDMask, rhs: Bool) {
    lhs = lhs .^ rhs
  }
  
  @_transparent
  public static func .|=(lhs: inout SIMDMask, rhs: Bool) {
    lhs = lhs .| rhs
  }
}

/// True if any lane of mask is true.
@_alwaysEmitIntoClient
public func any<Storage>(_ mask: SIMDMask<Storage>) -> Bool {
  return mask._storage.min() < 0
}

/// True if every lane of mask is true.
@_alwaysEmitIntoClient
public func all<Storage>(_ mask: SIMDMask<Storage>) -> Bool {
  return mask._storage.max() < 0
}

/// The lanewise minimum of two vectors.
///
/// Each element of the result is the minimum of the corresponding elements
/// of the inputs.
@_alwaysEmitIntoClient
public func pointwiseMin<T>(_ a: T, _ b: T) -> T
where T: SIMD, T.Scalar: Comparable {
  var result = T()
  for i in result.indices {
    result[i] = min(a[i], b[i])
  }
  return result
}

/// The lanewise maximum of two vectors.
///
/// Each element of the result is the minimum of the corresponding elements
/// of the inputs.
@_alwaysEmitIntoClient
public func pointwiseMax<T>(_ a: T, _ b: T) -> T
where T: SIMD, T.Scalar: Comparable {
  var result = T()
  for i in result.indices {
    result[i] = max(a[i], b[i])
  }
  return result
}


/// The lanewise minimum of two vectors.
///
/// Each element of the result is the minimum of the corresponding elements
/// of the inputs.
@_alwaysEmitIntoClient
public func pointwiseMin<T>(_ a: T, _ b: T) -> T
where T: SIMD, T.Scalar: FloatingPoint {
  var result = T()
  for i in result.indices {
    result[i] = T.Scalar.minimum(a[i], b[i])
  }
  return result
}

/// The lanewise maximum of two vectors.
///
/// Each element of the result is the maximum of the corresponding elements
/// of the inputs.
@_alwaysEmitIntoClient
public func pointwiseMax<T>(_ a: T, _ b: T) -> T
where T: SIMD, T.Scalar: FloatingPoint {
  var result = T()
  for i in result.indices {
    result[i] = T.Scalar.maximum(a[i], b[i])
  }
  return result
}

// Break the ambiguity between AdditiveArithmetic and SIMD for += and -=
extension SIMD where Self: AdditiveArithmetic, Self.Scalar: FloatingPoint {
  @_alwaysEmitIntoClient
  public static func +=(lhs: inout Self, rhs: Self) {
    lhs = lhs + rhs
  }

  @_alwaysEmitIntoClient
  public static func -=(lhs: inout Self, rhs: Self) {
    lhs = lhs - rhs
  }
}

// SWIFT_ENABLE_TENSORFLOW
extension SIMD
  where Self : Differentiable,
        TangentVector : SIMD,
        Scalar : BinaryFloatingPoint,
        TangentVector.Scalar : BinaryFloatingPoint {
  @inlinable
  @derivative(of: +)
  static func _vjpAdd(lhs: Self, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, TangentVector)) {
    return (lhs + rhs, { v in
      return (v, v)
    })
  }
  
  @inlinable
  @derivative(of: -)
  static func _vjpSubtract(lhs: Self, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, TangentVector)) {
    return (lhs - rhs, { v in
      return (v, -v)
    })
  }
  
  @inlinable
  @derivative(of: -)
  static func _vjpNegate(rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector)) {
    return (-rhs, { v in
      return -v
    })
  }
}

extension SIMD
  where Self : Differentiable,
        TangentVector : SIMD,
        Scalar : BinaryFloatingPoint,
        Self.TangentVector == Self {
  @inlinable
  @derivative(of: *)
  static func _vjpMultiply(lhs: Self, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, TangentVector)) {
    return (lhs * rhs, { v in
      return (v * rhs, v * lhs)
    })
  }
  
  @inlinable
  @derivative(of: /)
  static func _vjpDivide(lhs: Self, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, TangentVector)) {
    return (lhs / rhs, { v in
      (v / rhs, -lhs / (rhs * rhs) * v)
    })
  }
}

extension SIMD
  where Self : Differentiable,
        TangentVector : SIMD,
        Scalar : BinaryFloatingPoint & Differentiable,
        Scalar.TangentVector : BinaryFloatingPoint,
        TangentVector.Scalar == Scalar.TangentVector {
  @inlinable
  @derivative(of: +)
  static func _vjpAdd(lhs: Scalar, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (Scalar.TangentVector, TangentVector)) {
    return (lhs + rhs, { v in
      return (v.sum(), v)
    })
  }

  @inlinable
  @derivative(of: -)
  static func _vjpSubtract(lhs: Scalar, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (Scalar.TangentVector, TangentVector)) {
    return (lhs - rhs, { v in
      return (v.sum(), -v)
    })
  }

  @inlinable
  @derivative(of: +)
  static func _vjpAdd(lhs: Self, rhs: Scalar)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, Scalar.TangentVector)) {
    return (lhs + rhs, { v in
      return (v, v.sum())
    })
  }

  @inlinable
  @derivative(of: -)
  static func _vjpSubtract(lhs: Self, rhs: Scalar)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, Scalar.TangentVector)) {
    return (lhs - rhs, { v in
      return (v, -v.sum())
    })
  }
}

extension SIMD
  where Self : Differentiable,
        TangentVector : SIMD,
        Scalar : BinaryFloatingPoint & Differentiable,
        Self.TangentVector == Self,
        Scalar.TangentVector == Scalar {
  @inlinable
  @derivative(of: *)
  static func _vjpMultiply(lhs: Self, rhs: Scalar)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, Scalar.TangentVector)) {
    return (lhs * rhs, { v in
      return (v * rhs, (v * lhs).sum())
    })
  }
  
  @inlinable
  @derivative(of: /)
  static func _vjpDivide(lhs: Self, rhs: Scalar)
    -> (value: Self, pullback: (TangentVector) -> (TangentVector, Scalar.TangentVector)) {
    return (lhs / rhs, { v in
      (v / rhs, (-lhs / (rhs * rhs) * v).sum())
    })
  }
  
  @inlinable
  @derivative(of: *)
  static func _vjpMultiply(lhs: Scalar, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (Scalar.TangentVector, TangentVector)) {
    return (lhs * rhs, { v in
      return ((v * rhs).sum(), v * lhs)
    })
  }
  
  @inlinable
  @derivative(of: /)
  static func _vjpDivide(lhs: Scalar, rhs: Self)
    -> (value: Self, pullback: (TangentVector) -> (Scalar.TangentVector, TangentVector)) {
    return (lhs / rhs, { v in
      ((v / rhs).sum(), -lhs / (rhs * rhs) * v)
    })
  }
}

extension SIMD
  where Self : Differentiable,
        TangentVector : SIMD,
        Scalar : BinaryFloatingPoint & Differentiable,
        Scalar.TangentVector : BinaryFloatingPoint,
        TangentVector == Self {
  @inlinable
  @derivative(of: sum)
  func _vjpSum() -> (value: Scalar, pullback: (Scalar.TangentVector) -> TangentVector) {
    return (sum(), { v in Self(repeating: Scalar(v)) })
  }
}

extension SIMD
  where Self : Differentiable,
        Self.TangentVector : SIMD,
        Scalar : BinaryFloatingPoint & Differentiable,
        Self.TangentVector == Self,
        Scalar.TangentVector == Scalar {
  @usableFromInline
  @derivative(of: init(repeating:))
  static func _vjpInit(repeating value: Scalar)
    -> (value: Self, pullback: (TangentVector) -> Scalar.TangentVector) {
      return (Self(repeating: value), { v in v.sum() })
  }
}
