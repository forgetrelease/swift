//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Swift

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public protocol AtomicProtocol {
  associatedtype AtomicStorage

  /// Convert `value` to its atomic storage representation. Note that the act of
  /// conversion may have side effects (such as retaining a strong reference),
  /// so the returned value must be used to initialize exactly one atomic
  /// storage location.
  ///
  /// Each call to `prepareAtomicStorage(for:)` must be paired with call to
  /// `disposeAtomicStorage(at:)` to undo these potential side effects.
  ///
  /// Between initialization and the call to `disposeAtomicStorage`, the
  /// memory location must only be accessed through the atomic operations
  /// exposed by this type.
  ///
  /// For example, here is how these methods can be used to create a temporary
  /// atomic variable for the duration of a closure call:
  ///
  ///     extension AtomicProtocol {
  ///        mutating func withTemporaryAtomicValue(
  ///           _ body: (UnsafePointerToAtomic<Self>) -> Void
  ///        ) {
  ///           let storage =
  ///              UnsafeMutablePointer<AtomicStorage>.allocate(capacity: 1)
  ///           storage.initialize(to: Self.prepareAtomicStorage(for: self)
  ///           defer {
  ///              Self.disposeAtomicStorage(at: storage)
  ///              storage.deallocate()
  ///           }
  ///           let tmp = UnsafePointerToAtomic<Self>(at: storage)
  ///           body(tmp)
  ///           self = tmp.load(ordering: .relaxed)
  ///        }
  ///     }
  ///
  ///     42.withTemporaryAtomicValue { atomic in
  ///        print(atomic.load(ordering: .relaxed) // Prints 42
  ///     }
  ///
  /// - Parameter value: The value to convert.
  /// - Returns: The atomic storage representation of `value`.
  static func prepareAtomicStorage(for value: __owned Self) -> AtomicStorage

  /// Deinitialize atomic storage at the specified memory location.
  ///
  /// The specified address must have been previously initialized with a value
  /// returned from `prepareAtomicStorage(for:)`, and after initialization, it
  /// must have only been accessed using the atomic operations provided.
  ///
  /// - Parameter storage: A storage value previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  static func disposeAtomicStorage(_ storage: __owned AtomicStorage) -> Self

  /// Atomically loads and returns the value referenced by the given pointer,
  /// applying the specified memory ordering.
  ///
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: The current value referenced by `pointer`.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicLoad(
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicLoadOrdering
  ) -> Self

  /// Atomically sets the value referenced by `pointer` to `desired`,
  /// applying the specified memory ordering.
  ///
  /// - Parameter desired: The desired new value.
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicStore(
    _ desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicStoreOrdering
  )

  /// Atomically sets the value referenced by `pointer` to `desired` and returns
  /// the original value, applying the specified memory ordering.
  ///
  /// - Parameter desired: The desired new value.
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: The original value.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicExchange(
    _ desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering
  ) -> Self

  /// Perform an atomic compare and exchange operation on the value referenced
  /// by `pointer`, applying the specified memory ordering.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// This method implements a "strong" compare and exchange operation
  /// that does not permit spurious failures.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering
  ) -> (exchanged: Bool, original: Self)

  /// Perform an atomic compare and exchange operation on the value referenced
  /// by `pointer`, applying the specified success/failure memory orderings.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// The `ordering` argument specifies the memory ordering to use when the
  /// operation manages to update the current value, while `failureOrdering`
  /// will be used when the operation leaves the value intact.
  ///
  /// This method implements a "strong" compare and exchange operation
  /// that does not permit spurious failures.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Self)

  /// Perform an atomic weak compare and exchange operation on the value
  /// referenced by `pointer`, applying the specified success/failure memory
  /// orderings. This compare-exchange variant is allowed to spuriously fail; it
  /// is designed to be called in a loop until it indicates a successful
  /// exchange has happened.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// (In this weak form, transient conditions may cause the `original ==
  /// expected` check to sometimes return false when the two values are in fact
  /// the same.)
  ///
  /// The `ordering` argument specifies the memory ordering to use when the
  /// operation manages to update the current value, while `failureOrdering`
  /// will be used when the operation leaves the value intact.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter pointer: A memory location previously initialized with a value
  ///   returned by `prepareAtomicStorage(for:)`.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  static func atomicWeakCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Self)
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension AtomicProtocol where AtomicStorage == Self {
  @inlinable
  public static func prepareAtomicStorage(
    for value: __owned Self
  ) -> AtomicStorage {
    return value
  }

  @inlinable
  public static func disposeAtomicStorage(
    _ storage: __owned AtomicStorage
  ) -> Self {
    return storage
  }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension AtomicProtocol where
  Self: RawRepresentable,
  RawValue: AtomicProtocol,
  AtomicStorage == RawValue.AtomicStorage
{
  @inlinable
  public static func prepareAtomicStorage(
    for value: __owned Self
  ) -> RawValue.AtomicStorage {
    return RawValue.prepareAtomicStorage(for: value.rawValue)
  }

  @inlinable
  public static func disposeAtomicStorage(
    _ storage: __owned AtomicStorage
  ) -> Self {
    return Self(rawValue: RawValue.disposeAtomicStorage(storage))!
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicLoad(
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicLoadOrdering
  ) -> Self {
    let raw = RawValue.atomicLoad(at: pointer, ordering: ordering)
    return Self(rawValue: raw)!
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicStore(
    _ desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicStoreOrdering
  ) {
    RawValue.atomicStore(
      desired.rawValue,
      at: pointer,
      ordering: ordering)
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicExchange(
    _ desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering
  ) -> Self {
    let raw = RawValue.atomicExchange(
      desired.rawValue,
      at: pointer,
      ordering: ordering)
    return Self(rawValue: raw)!
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering
  ) -> (exchanged: Bool, original: Self) {
    let (exchanged, raw) = RawValue.atomicCompareExchange(
      expected: expected.rawValue,
      desired: desired.rawValue,
      at: pointer,
      ordering: ordering)
    return (exchanged, Self(rawValue: raw)!)
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Self) {
    let (exchanged, raw) = RawValue.atomicCompareExchange(
      expected: expected.rawValue,
      desired: desired.rawValue,
      at: pointer,
      ordering: ordering,
      failureOrdering: failureOrdering)
    return (exchanged, Self(rawValue: raw)!)
  }

  @_semantics("atomics.requires_constant_orderings")
  @_transparent @_alwaysEmitIntoClient
  public static func atomicWeakCompareExchange(
    expected: Self,
    desired: __owned Self,
    at pointer: UnsafeMutablePointer<AtomicStorage>,
    ordering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Self) {
    let (exchanged, raw) = RawValue.atomicWeakCompareExchange(
      expected: expected.rawValue,
      desired: desired.rawValue,
      at: pointer,
      ordering: ordering,
      failureOrdering: failureOrdering)
    return (exchanged, Self(rawValue: raw)!)
  }
}
