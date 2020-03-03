//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Provides atomic operations on an unmanaged object reference that is stored
/// at a stable memory location.
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@frozen
public struct UnsafeAtomicUnmanaged<Instance: AnyObject> {
  public typealias Value = Unmanaged<Instance>?

  @usableFromInline
  internal let _ptr: UnsafeMutableRawPointer

  @_transparent // Debug performance
  public init(at address: UnsafeMutablePointer<Value>) {
    self._ptr = UnsafeMutableRawPointer(address)
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeAtomicUnmanaged {
  @inlinable
  public var address: UnsafeMutablePointer<Value> {
    _ptr.assumingMemoryBound(to: Value.self)
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeAtomicUnmanaged {
  /// Atomically loads and returns the current value,
  /// with the specified memory ordering.
  @_transparent @_alwaysEmitIntoClient
  public func load(ordering: AtomicLoadOrdering) -> Value {
    let value = _ptr._atomicLoadWord(ordering: ordering)
    guard let p = UnsafeRawPointer(bitPattern: value) else { return nil }
    return Unmanaged.fromOpaque(p)
  }
}


@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeAtomicUnmanaged {
  /// Atomically sets the current value to `desired`,
  /// with the specified memory ordering.
  @_transparent @_alwaysEmitIntoClient
  public func store(
    _ desired: Value,
    ordering: AtomicStoreOrdering
  ) {
    let desiredWord = UInt(bitPattern: desired?.toOpaque())
    _ptr._atomicStoreWord(desiredWord, ordering: ordering)
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeAtomicUnmanaged {
  /// Atomically sets the current value to `desired` and returns the previous
  /// value, with the specified memory ordering.
  ///
  /// - Returns: The original value.
  @_transparent @_alwaysEmitIntoClient
  public func exchange(
    _ desired: Value,
    ordering: AtomicUpdateOrdering
  ) -> Value {
    let desiredWord = UInt(bitPattern: desired?.toOpaque())
    let resultWord = _ptr._atomicExchangeWord(desiredWord, ordering: ordering)
    guard let r = UnsafeRawPointer(bitPattern: resultWord) else { return nil }
    return Unmanaged.fromOpaque(r)
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension UnsafeAtomicUnmanaged {
  /// Perform an atomic compare and exchange operation with
  /// with the specified memory ordering.
  ///
  /// This operation is equivalent to the following pseudocode:
  ///
  /// ```
  /// atomic(self, ordering: ordering) { value in
  ///   guard value == expected else { return (false, value) }
  ///   value = desired
  ///   return (true, expected)
  /// }
  /// ```
  ///
  /// This method implements a "strong" compare and exchange operation
  /// that does not permit spurious failures.
  @_transparent @_alwaysEmitIntoClient
  public func compareExchange(
    expected: Value,
    desired: Value,
    ordering: AtomicUpdateOrdering
  ) -> (exchanged: Bool, original: Value) {
    let desiredWord = UInt(bitPattern: desired?.toOpaque())
    let expectedWord = UInt(bitPattern: expected?.toOpaque())
    let (success, originalWord) = _ptr._atomicCompareThenExchangeWord(
      expected: expectedWord,
      desired: desiredWord,
      ordering: ordering)
    let original: Value
    if let p = UnsafeRawPointer(bitPattern: originalWord) {
      original = Unmanaged.fromOpaque(p)
    } else {
      original = nil
    }
    return (success, original)
  }
}
