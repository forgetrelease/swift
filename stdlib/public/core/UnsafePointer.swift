//===--- UnsafePointer.swift ----------------------------------*- swift -*-===//
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

/// A pointer for accessing  data of a
/// specific type.
///
/// You use instances of the `UnsafePointer` type to access data of a
/// specific type in memory. The type of data that a pointer can access is the
/// pointer's `Pointee` type. `UnsafePointer` provides no automated
/// memory management or alignment guarantees. You are responsible for
/// handling the life cycle of any memory you work with through unsafe
/// pointers to avoid leaks or undefined behavior.
///
/// Memory that you manually manage can be either *untyped* or *bound* to a
/// specific type. You use the `UnsafePointer` type to access and
/// manage memory that has been bound to a specific type.
///
/// Understanding a Pointer's Memory State
/// ======================================
///
/// The memory referenced by an `UnsafePointer` instance can be in
/// one of several states. Many pointer operations must only be applied to
/// pointers with memory in a specific state---you must keep track of the
/// state of the memory you are working with and understand the changes to
/// that state that different operations perform. Memory can be untyped and
/// uninitialized, bound to a type and uninitialized, or bound to a type and
/// initialized to a value. Finally, memory that was allocated previously may
/// have been deallocated, leaving existing pointers referencing unallocated
/// memory.
///
/// Uninitialized Memory
/// --------------------
///
/// Memory that has just been allocated through a typed pointer or has been
/// deinitialized is in an *uninitialized* state. Uninitialized memory must be
/// initialized before it can be accessed for reading.
///
/// Initialized Memory
/// ------------------
///
/// *Initialized* memory has a value that can be read using a pointer's
/// `pointee` property or through subscript notation. In the following
/// example, `ptr` is a pointer to memory initialized with a value of `23`:
///
///     let ptr: UnsafePointer<Int> = ...
///     // ptr.pointee == 23
///     // ptr[0] == 23
///
/// Accessing a Pointer's Memory as a Different Type
/// ================================================
///
/// When you access memory through an `UnsafePointer` instance, the
/// `Pointee` type must be consistent with the bound type of the memory. If
/// you do need to access memory that is bound to one type as a different
/// type, Swift's pointer types provide type-safe ways to temporarily or
/// permanently change the bound type of the memory, or to load typed
/// instances directly from raw memory.
///
/// An `UnsafePointer<UInt8>` instance allocated with eight bytes of
/// memory, `uint8Pointer`, will be used for the examples below.
///
///     let uint8Pointer: UnsafePointer<UInt8> = fetchEightBytes()
///
/// When you only need to temporarily access a pointer's memory as a different
/// type, use the `withMemoryRebound(to:capacity:)` method. For example, you
/// can use this method to call an API that expects a pointer to a different
/// type that is layout compatible with your pointer's `Pointee`. The following
/// code temporarily rebinds the memory that `uint8Pointer` references from
/// `UInt8` to `Int8` to call the imported C `strlen` function.
///
///     // Imported from C
///     func strlen(_ __s: UnsafePointer<Int8>!) -> UInt
///
///     let length = uint8Pointer.withMemoryRebound(to: Int8.self, capacity: 8) {
///         return strlen($0)
///     }
///     // length == 7
///
/// When you need to permanently rebind memory to a different type, first
/// obtain a raw pointer to the memory and then call the
/// `bindMemory(to:capacity:)` method on the raw pointer. The following
/// example binds the memory referenced by `uint8Pointer` to one instance of
/// the `UInt64` type:
///
///     let uint64Pointer = UnsafeRawPointer(uint8Pointer)
///                               .bindMemory(to: UInt64.self, capacity: 1)
///
/// After rebinding the memory referenced by `uint8Pointer` to `UInt64`,
/// accessing that pointer's referenced memory as a `UInt8` instance is
/// undefined.
///
///     var fullInteger = uint64Pointer.pointee          // OK
///     var firstByte = uint8Pointer.pointee             // undefined
///
/// Alternatively, you can access the same memory as a different type without
/// rebinding through untyped memory access, so long as the bound type and the
/// destination type are trivial types. Convert your pointer to an
/// `UnsafeRawPointer` instance and then use the raw pointer's
/// `load(fromByteOffset:as:)` method to read values.
///
///     let rawPointer = UnsafeRawPointer(uint64Pointer)
///     fullInteger = rawPointer.load(as: UInt64.self)   // OK
///     firstByte = rawPointer.load(as: UInt8.self)      // OK
///
/// Performing Typed Pointer Arithmetic
/// ===================================
///
/// Pointer arithmetic with a typed pointer is counted in strides of the
/// pointer's `Pointee` type. When you add to or subtract from an `UnsafePointer`
/// instance, the result is a new pointer of the same type, offset by that
/// number of instances of the `Pointee` type.
///
///     // 'intPointer' points to memory initialized with [10, 20, 30, 40]
///     let intPointer: UnsafePointer<Int> = ...
///
///     // Load the first value in memory
///     let x = intPointer.pointee
///     // x == 10
///
///     // Load the third value in memory
///     let offsetPointer = intPointer + 2
///     let y = offsetPointer.pointee
///     // y == 30
///
/// You can also use subscript notation to access the value in memory at a
/// specific offset.
///
///     let z = intPointer[2]
///     // z == 30
///
/// Implicit Casting and Bridging
/// =============================
///
/// When calling a function or method with an `UnsafePointer` parameter, you can pass
/// an instance of that specific pointer type, pass an instance of a
/// compatible pointer type, or use Swift's implicit bridging to pass a
/// compatible pointer.
///
/// For example, the `printInt(atAddress:)` function in the following code
/// sample expects an `UnsafePointer<Int>` instance as its first parameter:
///
///     func printInt(atAddress p: UnsafePointer<Int>) {
///         print(p.pointee)
///     }
///
/// As is typical in Swift, you can call the `printInt(atAddress:)` function
/// with an `UnsafePointer` instance. This example passes `intPointer`, a pointer to
/// an `Int` value, to `print(address:)`.
///
///     printInt(atAddress: intPointer)
///     // Prints "42"
///
/// Because a mutable typed pointer can be implicitly cast to an immutable
/// pointer with the same `Pointee` type when passed as a parameter, you can
/// also call `printInt(atAddress:)` with an `UnsafeMutablePointer` instance.
///
///     let mutableIntPointer = UnsafeMutablePointer(mutating: intPointer)
///     printInt(atAddress: mutableIntPointer)
///     // Prints "42"
///
/// Alternatively, you can use Swift's *implicit bridging* to pass a pointer to
/// an instance or to the elements of an array. The following example passes a
/// pointer to the `value` variable by using inout syntax:
///
///     var value: Int = 23
///     printInt(atAddress: &value)
///     // Prints "23"
///
/// An immutable pointer to the elements of an array is implicitly created when
/// you pass the array as an argument. This example uses implicit bridging to
/// pass a pointer to the elements of `numbers` when calling
/// `printInt(atAddress:)`.
///
///     let numbers = [5, 10, 15, 20]
///     printInt(atAddress: numbers)
///     // Prints "5"
///
/// You can also use inout syntax to pass a mutable pointer to the elements of
/// an array. Because `printInt(atAddress:)` requires an immutable pointer,
/// although this is syntactically valid, it isn't necessary.
///
///     var mutableNumbers = numbers
///     printInt(atAddress: &mutableNumbers)
///
/// No matter which way you call `printInt(atAddress:)`, Swift's type safety
/// guarantees that you can only pass a pointer to the type required by the
/// function---in this case, a pointer to an `Int`.
///
/// - Important: The pointer created through implicit bridging of an instance
///   or of an array's elements is only valid during the execution of the
///   called function. Escaping the pointer to use after the execution of the
///   function is undefined behavior. In particular, do not use implicit
///   bridging when calling an `UnsafePointer` initializer.
///
///       var number = 5
///       let numberPointer = UnsafePointer<Int>(&number)
///       // Accessing 'numberPointer' is undefined behavior.
@frozen // unsafe-performance
public struct UnsafePointer<Pointee>: _Pointer {

  /// A type that represents the distance between two pointers.
  public typealias Distance = Int

  /// The underlying raw (untyped) pointer.
  public let _rawValue: Builtin.RawPointer

  /// Creates an `UnsafePointer` from a builtin raw pointer.
  @_transparent
  public init(_ _rawValue: Builtin.RawPointer) {
    self._rawValue = _rawValue
  }

  /// Deallocates the memory block previously allocated at this pointer.
  ///
  /// This pointer must be a pointer to the start of a previously allocated memory 
  /// block. The memory must not be initialized or `Pointee` must be a trivial type.
  @inlinable
  public func deallocate() {
    // Passing zero alignment to the runtime forces "aligned
    // deallocation". Since allocation via `UnsafeMutable[Raw][Buffer]Pointer`
    // always uses the "aligned allocation" path, this ensures that the
    // runtime's allocation and deallocation paths are compatible.
    Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
  }

  /// Accesses the instance referenced by this pointer.
  ///
  /// When reading from the `pointee` property, the instance referenced by
  /// this pointer must already be initialized.
  @inlinable // unsafe-performance
  public var pointee: Pointee {
    @_transparent unsafeAddress {
      return self
    }
  }

  /// Executes the given closure while temporarily binding the specified number
  /// of instances to the given type.
  ///
  /// Use this method when you have a pointer to memory bound to one type and
  /// you need to access that memory as instances of another type. Accessing
  /// memory as a type `T` requires that the memory be bound to that type. A
  /// memory location may only be bound to one type at a time, so accessing
  /// the same memory as an unrelated type without first rebinding the memory
  /// is undefined.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized.
  ///
  /// The following example temporarily rebinds the memory of a `UInt64`
  /// pointer to `Int64`, then accesses a property on the signed integer.
  ///
  ///     let uint64Pointer: UnsafePointer<UInt64> = fetchValue()
  ///     let isNegative = uint64Pointer.withMemoryRebound(to: Int64.self) { ptr in
  ///         return ptr.pointee < 0
  ///     }
  ///
  /// Because this pointer's memory is no longer bound to its `Pointee` type
  /// while the `body` closure executes, do not access memory using the
  /// original pointer from within `body`. Instead, use the `body` closure's
  /// pointer argument to access the values in memory as instances of type
  /// `T`.
  ///
  /// After executing `body`, this method rebinds memory back to the original
  /// `Pointee` type.
  ///
  /// - Note: Only use this method to rebind the pointer's memory to a type
  ///   with the same size and stride as the currently bound `Pointee` type.
  ///   To bind a region of memory to a type that is a different size, convert
  ///   the pointer to a raw pointer and use the `bindMemory(to:capacity:)`
  ///   method.
  ///
  /// - Parameters:
  ///   - type: The type to temporarily bind the memory referenced by this
  ///     pointer. The type `T` must be the same size and be layout compatible
  ///     with the pointer's `Pointee` type.
  ///   - count: The number of instances of `Pointee` to bind to `type`.
  ///   - body: A closure that takes a  typed pointer to the
  ///     same memory as this pointer, only bound to type `T`. The closure's
  ///     pointer argument is valid only for the duration of the closure's
  ///     execution. If `body` has a return value, that value is also used as
  ///     the return value for the `withMemoryRebound(to:capacity:_:)` method.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  @inlinable
  public func withMemoryRebound<T, Result>(to type: T.Type, capacity count: Int,
    _ body: (UnsafePointer<T>) throws -> Result
  ) rethrows -> Result {
    Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
    defer {
      Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
    }
    return try body(UnsafePointer<T>(_rawValue))
  }

  /// Accesses the pointee at the specified offset from this pointer.
  ///
  ///
  /// For a pointer `p`, the memory at `p + i` must be initialized.
  ///
  /// - Parameter i: The offset from this pointer at which to access an
  ///   instance, measured in strides of the pointer's `Pointee` type.
  @inlinable
  public subscript(i: Int) -> Pointee {
    @_transparent
    unsafeAddress {
      return self + i
    }
  }

  @inlinable // unsafe-performance
  internal static var _max: UnsafePointer {
    return UnsafePointer(
      bitPattern: 0 as Int &- MemoryLayout<Pointee>.stride
    )._unsafelyUnwrappedUnchecked
  }
}


/// A pointer for accessing and manipulating data of a
/// specific type.
///
/// You use instances of the `UnsafeMutablePointer` type to access data of a
/// specific type in memory. The type of data that a pointer can access is the
/// pointer's `Pointee` type. `UnsafeMutablePointer` provides no automated
/// memory management or alignment guarantees. You are responsible for
/// handling the life cycle of any memory you work with through unsafe
/// pointers to avoid leaks or undefined behavior.
///
/// Memory that you manually manage can be either *untyped* or *bound* to a
/// specific type. You use the `UnsafeMutablePointer` type to access and
/// manage memory that has been bound to a specific type.
///
/// Understanding a Pointer's Memory State
/// ======================================
///
/// The memory referenced by an `UnsafeMutablePointer` instance can be in
/// one of several states. Many pointer operations must only be applied to
/// pointers with memory in a specific state---you must keep track of the
/// state of the memory you are working with and understand the changes to
/// that state that different operations perform. Memory can be untyped and
/// uninitialized, bound to a type and uninitialized, or bound to a type and
/// initialized to a value. Finally, memory that was allocated previously may
/// have been deallocated, leaving existing pointers referencing unallocated
/// memory.
///
/// Uninitialized Memory
/// --------------------
///
/// Memory that has just been allocated through a typed pointer or has been
/// deinitialized is in an *uninitialized* state. Uninitialized memory must be
/// initialized before it can be accessed for reading.
///
/// You can use methods like `initialize(to:count:)`, `initialize(from:count:)`,
/// and `moveInitialize(from:count:)` to initialize the memory referenced by a
/// pointer with a value or series of values.
///
/// Initialized Memory
/// ------------------
///
/// *Initialized* memory has a value that can be read using a pointer's
/// `pointee` property or through subscript notation. In the following
/// example, `ptr` is a pointer to memory initialized with a value of `23`:
///
///     let ptr: UnsafeMutablePointer<Int> = ...
///     // ptr.pointee == 23
///     // ptr[0] == 23
///
/// Accessing a Pointer's Memory as a Different Type
/// ================================================
///
/// When you access memory through an `UnsafeMutablePointer` instance, the
/// `Pointee` type must be consistent with the bound type of the memory. If
/// you do need to access memory that is bound to one type as a different
/// type, Swift's pointer types provide type-safe ways to temporarily or
/// permanently change the bound type of the memory, or to load typed
/// instances directly from raw memory.
///
/// An `UnsafeMutablePointer<UInt8>` instance allocated with eight bytes of
/// memory, `uint8Pointer`, will be used for the examples below.
///
///     var bytes: [UInt8] = [39, 77, 111, 111, 102, 33, 39, 0]
///     let uint8Pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
///     uint8Pointer.initialize(from: &bytes, count: 8)
///
/// When you only need to temporarily access a pointer's memory as a different
/// type, use the `withMemoryRebound(to:capacity:)` method. For example, you
/// can use this method to call an API that expects a pointer to a different
/// type that is layout compatible with your pointer's `Pointee`. The following
/// code temporarily rebinds the memory that `uint8Pointer` references from
/// `UInt8` to `Int8` to call the imported C `strlen` function.
///
///     // Imported from C
///     func strlen(_ __s: UnsafePointer<Int8>!) -> UInt
///
///     let length = uint8Pointer.withMemoryRebound(to: Int8.self, capacity: 8) {
///         return strlen($0)
///     }
///     // length == 7
///
/// When you need to permanently rebind memory to a different type, first
/// obtain a raw pointer to the memory and then call the
/// `bindMemory(to:capacity:)` method on the raw pointer. The following
/// example binds the memory referenced by `uint8Pointer` to one instance of
/// the `UInt64` type:
///
///     let uint64Pointer = UnsafeMutableRawPointer(uint8Pointer)
///                               .bindMemory(to: UInt64.self, capacity: 1)
///
/// After rebinding the memory referenced by `uint8Pointer` to `UInt64`,
/// accessing that pointer's referenced memory as a `UInt8` instance is
/// undefined.
///
///     var fullInteger = uint64Pointer.pointee          // OK
///     var firstByte = uint8Pointer.pointee             // undefined
///
/// Alternatively, you can access the same memory as a different type without
/// rebinding through untyped memory access, so long as the bound type and the
/// destination type are trivial types. Convert your pointer to an
/// `UnsafeMutableRawPointer` instance and then use the raw pointer's
/// `load(fromByteOffset:as:)` and `storeBytes(of:toByteOffset:as:)` methods
/// to read and write values.
///
///     let rawPointer = UnsafeMutableRawPointer(uint64Pointer)
///     fullInteger = rawPointer.load(as: UInt64.self)   // OK
///     firstByte = rawPointer.load(as: UInt8.self)      // OK
///
/// Performing Typed Pointer Arithmetic
/// ===================================
///
/// Pointer arithmetic with a typed pointer is counted in strides of the
/// pointer's `Pointee` type. When you add to or subtract from an `UnsafeMutablePointer`
/// instance, the result is a new pointer of the same type, offset by that
/// number of instances of the `Pointee` type.
///
///     // 'intPointer' points to memory initialized with [10, 20, 30, 40]
///     let intPointer: UnsafeMutablePointer<Int> = ...
///
///     // Load the first value in memory
///     let x = intPointer.pointee
///     // x == 10
///
///     // Load the third value in memory
///     let offsetPointer = intPointer + 2
///     let y = offsetPointer.pointee
///     // y == 30
///
/// You can also use subscript notation to access the value in memory at a
/// specific offset.
///
///     let z = intPointer[2]
///     // z == 30
///
/// Implicit Casting and Bridging
/// =============================
///
/// When calling a function or method with an `UnsafeMutablePointer` parameter, you can pass
/// an instance of that specific pointer type or use Swift's implicit bridging
/// to pass a compatible pointer.
///
/// For example, the `printInt(atAddress:)` function in the following code
/// sample expects an `UnsafeMutablePointer<Int>` instance as its first parameter:
///
///     func printInt(atAddress p: UnsafeMutablePointer<Int>) {
///         print(p.pointee)
///     }
///
/// As is typical in Swift, you can call the `printInt(atAddress:)` function
/// with an `UnsafeMutablePointer` instance. This example passes `intPointer`, a mutable
/// pointer to an `Int` value, to `print(address:)`.
///
///     printInt(atAddress: intPointer)
///     // Prints "42"
///
/// Alternatively, you can use Swift's *implicit bridging* to pass a pointer to
/// an instance or to the elements of an array. The following example passes a
/// pointer to the `value` variable by using inout syntax:
///
///     var value: Int = 23
///     printInt(atAddress: &value)
///     // Prints "23"
///
/// A mutable pointer to the elements of an array is implicitly created when
/// you pass the array using inout syntax. This example uses implicit bridging
/// to pass a pointer to the elements of `numbers` when calling
/// `printInt(atAddress:)`.
///
///     var numbers = [5, 10, 15, 20]
///     printInt(atAddress: &numbers)
///     // Prints "5"
///
/// No matter which way you call `printInt(atAddress:)`, Swift's type safety
/// guarantees that you can only pass a pointer to the type required by the
/// function---in this case, a pointer to an `Int`.
///
/// - Important: The pointer created through implicit bridging of an instance
///   or of an array's elements is only valid during the execution of the
///   called function. Escaping the pointer to use after the execution of the
///   function is undefined behavior. In particular, do not use implicit
///   bridging when calling an `UnsafeMutablePointer` initializer.
///
///       var number = 5
///       let numberPointer = UnsafeMutablePointer<Int>(&number)
///       // Accessing 'numberPointer' is undefined behavior.
@frozen // unsafe-performance
public struct UnsafeMutablePointer<Pointee>: _Pointer {

  /// A type that represents the distance between two pointers.
  public typealias Distance = Int

  /// The underlying raw (untyped) pointer.
  public let _rawValue: Builtin.RawPointer

  /// Creates an `UnsafeMutablePointer` from a builtin raw pointer.
  @_transparent
  public init(_ _rawValue: Builtin.RawPointer) {
    self._rawValue = _rawValue
  }

  /// Creates a mutable typed pointer referencing the same memory as the given
  /// immutable pointer.
  ///
  /// - Parameter other: The immutable pointer to convert.
  @_transparent
  public init(mutating other: UnsafePointer<Pointee>) {
    self._rawValue = other._rawValue
  }

  /// Creates a mutable typed pointer referencing the same memory as the given
  /// immutable pointer.
  ///
  /// - Parameter other: The immutable pointer to convert. If `other` is `nil`,
  ///   the result is `nil`.
  @_transparent
  public init?(mutating other: UnsafePointer<Pointee>?) {
    guard let unwrapped = other else { return nil }
    self.init(mutating: unwrapped)
  }
  
  /// Creates an immutable typed pointer referencing the same memory as the		
  /// given mutable pointer.		
  ///		
  /// - Parameter other: The pointer to convert.		
  @_transparent		
  public init(_ other: UnsafeMutablePointer<Pointee>) {
   self._rawValue = other._rawValue		
  }		

  /// Creates an immutable typed pointer referencing the same memory as the		
  /// given mutable pointer.		
  ///		
  /// - Parameter other: The pointer to convert. If `other` is `nil`, the		
  ///   result is `nil`.		
  @_transparent		
  public init?(_ other: UnsafeMutablePointer<Pointee>?) {
   guard let unwrapped = other else { return nil }		
   self.init(unwrapped)		
  }		
  

  /// Allocates uninitialized memory for the specified number of instances of
  /// type `Pointee`.
  ///
  /// The resulting pointer references a region of memory that is bound to
  /// `Pointee` and is `count * MemoryLayout<Pointee>.stride` bytes in size.
  ///
  /// The following example allocates enough new memory to store four `Int`
  /// instances and then initializes that memory with the elements of a range.
  ///
  ///     let intPointer = UnsafeMutablePointer<Int>.allocate(capacity: 4)
  ///     for i in 0..<4 {
  ///         (intPointer + i).initialize(to: i)
  ///     }
  ///     print(intPointer.pointee)
  ///     // Prints "0"
  ///
  /// When you allocate memory, always remember to deallocate once you're
  /// finished.
  ///
  ///     intPointer.deallocate()
  ///
  /// - Parameter count: The amount of memory to allocate, counted in instances
  ///   of `Pointee`.
  @inlinable
  public static func allocate(capacity count: Int)
    -> UnsafeMutablePointer<Pointee> {
    let size = MemoryLayout<Pointee>.stride * count
    // For any alignment <= _minAllocationAlignment, force alignment = 0.
    // This forces the runtime's "aligned" allocation path so that
    // deallocation does not require the original alignment.
    //
    // The runtime guarantees:
    //
    // align == 0 || align > _minAllocationAlignment:
    //   Runtime uses "aligned allocation".
    //
    // 0 < align <= _minAllocationAlignment:
    //   Runtime may use either malloc or "aligned allocation".
    var align = Builtin.alignof(Pointee.self)
    if Int(align) <= _minAllocationAlignment() {
      align = (0)._builtinWordValue
    }
    let rawPtr = Builtin.allocRaw(size._builtinWordValue, align)
    Builtin.bindMemory(rawPtr, count._builtinWordValue, Pointee.self)
    return UnsafeMutablePointer(rawPtr)
  }

  /// Deallocates the memory block previously allocated at this pointer.
  ///
  /// This pointer must be a pointer to the start of a previously allocated memory 
  /// block. The memory must not be initialized or `Pointee` must be a trivial type.
  @inlinable
  public func deallocate() {
    // Passing zero alignment to the runtime forces "aligned
    // deallocation". Since allocation via `UnsafeMutable[Raw][Buffer]Pointer`
    // always uses the "aligned allocation" path, this ensures that the
    // runtime's allocation and deallocation paths are compatible.
    Builtin.deallocRaw(_rawValue, (-1)._builtinWordValue, (0)._builtinWordValue)
  }

  /// Accesses the instance referenced by this pointer.
  ///
  /// When reading from the `pointee` property, the instance referenced by this
  /// pointer must already be initialized. When `pointee` is used as the left
  /// side of an assignment, the instance must be initialized or this
  /// pointer's `Pointee` type must be a trivial type.
  ///
  /// Do not assign an instance of a nontrivial type through `pointee` to
  /// uninitialized memory. Instead, use an initializing method, such as
  /// `initialize(to:count:)`.
  @inlinable // unsafe-performance
  public var pointee: Pointee {
    @_transparent unsafeAddress {
      return UnsafePointer(self)
    }
    @_transparent nonmutating unsafeMutableAddress {
      return self
    }
  }

  /// Initializes this pointer's memory with the specified number of
  /// consecutive copies of the given value.
  ///
  /// The destination memory must be uninitialized or the pointer's `Pointee`
  /// must be a trivial type. After a call to `initialize(repeating:count:)`, the
  /// memory referenced by this pointer is initialized.
  ///
  /// - Parameters:
  ///   - repeatedValue: The instance to initialize this pointer's memory with.
  ///   - count: The number of consecutive copies of `newValue` to initialize.
  ///     `count` must not be negative. 
  @inlinable
  public func initialize(repeating repeatedValue: Pointee, count: Int) {
    // FIXME: add tests (since the `count` has been added)
    _debugPrecondition(count >= 0,
      "UnsafeMutablePointer.initialize(repeating:count:): negative count")
    // Must not use `initializeFrom` with a `Collection` as that will introduce
    // a cycle.
    for offset in 0..<count {
      Builtin.initialize(repeatedValue, (self + offset)._rawValue)
    }
  }
  
  /// Initializes this pointer's memory with a single instance of the given value.
  ///
  /// The destination memory must be uninitialized or the pointer's `Pointee`
  /// must be a trivial type. After a call to `initialize(to:)`, the
  /// memory referenced by this pointer is initialized. Calling this method is 
  /// roughly equivalent to calling `initialize(repeating:count:)` with a 
  /// `count` of 1.
  ///
  /// - Parameters:
  ///   - value: The instance to initialize this pointer's pointee to.
  @inlinable
  public func initialize(to value: Pointee) {
    Builtin.initialize(value, self._rawValue)
  }

  /// Retrieves and returns the referenced instance, returning the pointer's
  /// memory to an uninitialized state.
  ///
  /// Calling the `move()` method on a pointer `p` that references memory of
  /// type `T` is equivalent to the following code, aside from any cost and
  /// incidental side effects of copying and destroying the value:
  ///
  ///     let value: T = {
  ///         defer { p.deinitialize(count: 1) }
  ///         return p.pointee
  ///     }()
  ///
  /// The memory referenced by this pointer must be initialized. After calling
  /// `move()`, the memory is uninitialized.
  ///
  /// - Returns: The instance referenced by this pointer.
  @inlinable
  public func move() -> Pointee {
    return Builtin.take(_rawValue)
  }

  /// Replaces this pointer's memory with the specified number of
  /// consecutive copies of the given value.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized or
  /// `Pointee` must be a trivial type. After calling
  /// `assign(repeating:count:)`, the region is initialized.
  ///
  /// - Parameters:
  ///   - repeatedValue: The instance to assign this pointer's memory to.
  ///   - count: The number of consecutive copies of `newValue` to assign.
  ///     `count` must not be negative. 
  @inlinable
  public func assign(repeating repeatedValue: Pointee, count: Int) {
    _debugPrecondition(count >= 0, "UnsafeMutablePointer.assign(repeating:count:) with negative count")
    for i in 0..<count {
      self[i] = repeatedValue
    }
  }
  
  /// Replaces this pointer's initialized memory with the specified number of
  /// instances from the given pointer's memory.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized or
  /// `Pointee` must be a trivial type. After calling
  /// `assign(from:count:)`, the region is initialized.
  ///
  /// - Note: Returns without performing work if `self` and `source` are equal.
  ///
  /// - Parameters:
  ///   - source: A pointer to at least `count` initialized instances of type
  ///     `Pointee`. The memory regions referenced by `source` and this
  ///     pointer may overlap.
  ///   - count: The number of instances to copy from the memory referenced by
  ///     `source` to this pointer's memory. `count` must not be negative.
  @inlinable
  public func assign(from source: UnsafePointer<Pointee>, count: Int) {
    _debugPrecondition(
      count >= 0, "UnsafeMutablePointer.assign with negative count")
    if UnsafePointer(self) < source || UnsafePointer(self) >= source + count {
      // assign forward from a disjoint or following overlapping range.
      Builtin.assignCopyArrayFrontToBack(
        Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
      // This builtin is equivalent to:
      // for i in 0..<count {
      //   self[i] = source[i]
      // }
    }
    else if UnsafePointer(self) != source {
      // assign backward from a non-following overlapping range.
      Builtin.assignCopyArrayBackToFront(
        Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
      // This builtin is equivalent to:
      // var i = count-1
      // while i >= 0 {
      //   self[i] = source[i]
      //   i -= 1
      // }
    }
  }

  /// Moves instances from initialized source memory into the uninitialized
  /// memory referenced by this pointer, leaving the source memory
  /// uninitialized and the memory referenced by this pointer initialized.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be uninitialized or
  /// `Pointee` must be a trivial type. After calling
  /// `moveInitialize(from:count:)`, the region is initialized and the memory
  /// region `source..<(source + count)` is uninitialized.
  ///
  /// - Parameters:
  ///   - source: A pointer to the values to copy. The memory region
  ///     `source..<(source + count)` must be initialized. The memory regions
  ///     referenced by `source` and this pointer may overlap.
  ///   - count: The number of instances to move from `source` to this
  ///     pointer's memory. `count` must not be negative.
  @inlinable
  public func moveInitialize(from source: UnsafeMutablePointer, count: Int) {
    _debugPrecondition(
      count >= 0, "UnsafeMutablePointer.moveInitialize with negative count")
    if self < source || self >= source + count {
      // initialize forward from a disjoint or following overlapping range.
      Builtin.takeArrayFrontToBack(
        Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
      // This builtin is equivalent to:
      // for i in 0..<count {
      //   (self + i).initialize(to: (source + i).move())
      // }
    }
    else {
      // initialize backward from a non-following overlapping range.
      Builtin.takeArrayBackToFront(
        Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
      // This builtin is equivalent to:
      // var src = source + count
      // var dst = self + count
      // while dst != self {
      //   (--dst).initialize(to: (--src).move())
      // }
    }
  }

  /// Initializes the memory referenced by this pointer with the values
  /// starting at the given pointer.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be uninitialized or
  /// `Pointee` must be a trivial type. After calling
  /// `initialize(from:count:)`, the region is initialized.
  ///
  /// - Parameters:
  ///   - source: A pointer to the values to copy. The memory region
  ///     `source..<(source + count)` must be initialized. The memory regions
  ///     referenced by `source` and this pointer must not overlap.
  ///   - count: The number of instances to move from `source` to this
  ///     pointer's memory. `count` must not be negative.
  @inlinable
  public func initialize(from source: UnsafePointer<Pointee>, count: Int) {
    _debugPrecondition(
      count >= 0, "UnsafeMutablePointer.initialize with negative count")
    _debugPrecondition(
      UnsafePointer(self) + count <= source ||
      source + count <= UnsafePointer(self),
      "UnsafeMutablePointer.initialize overlapping range")
    Builtin.copyArray(
      Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
    // This builtin is equivalent to:
    // for i in 0..<count {
    //   (self + i).initialize(to: source[i])
    // }
  }

  /// Replaces the memory referenced by this pointer with the values
  /// starting at the given pointer, leaving the source memory uninitialized.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized or
  /// `Pointee` must be a trivial type. After calling
  /// `moveAssign(from:count:)`, the region is initialized and the memory
  /// region `source..<(source + count)` is uninitialized.
  ///
  /// - Parameters:
  ///   - source: A pointer to the values to copy. The memory region
  ///     `source..<(source + count)` must be initialized. The memory regions
  ///     referenced by `source` and this pointer must not overlap.
  ///   - count: The number of instances to move from `source` to this
  ///     pointer's memory. `count` must not be negative.
  @inlinable
  public func moveAssign(from source: UnsafeMutablePointer, count: Int) {
    _debugPrecondition(
      count >= 0, "UnsafeMutablePointer.moveAssign(from:) with negative count")
    _debugPrecondition(
      self + count <= source || source + count <= self,
      "moveAssign overlapping range")
    Builtin.assignTakeArray(
      Pointee.self, self._rawValue, source._rawValue, count._builtinWordValue)
    // These builtins are equivalent to:
    // for i in 0..<count {
    //   self[i] = (source + i).move()
    // }
  }
  
  /// Deinitializes the specified number of values starting at this pointer.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized. After
  /// calling `deinitialize(count:)`, the memory is uninitialized, but still
  /// bound to the `Pointee` type.
  ///
  /// - Parameter count: The number of instances to deinitialize. `count` must
  ///   not be negative. 
  /// - Returns: A raw pointer to the same address as this pointer. The memory
  ///   referenced by the returned raw pointer is still bound to `Pointee`.
  @inlinable
  @discardableResult
  public func deinitialize(count: Int) -> UnsafeMutableRawPointer {
    _debugPrecondition(count >= 0, "UnsafeMutablePointer.deinitialize with negative count")
    // FIXME: optimization should be implemented, where if the `count` value
    // is 1, the `Builtin.destroy(Pointee.self, _rawValue)` gets called.
    Builtin.destroyArray(Pointee.self, _rawValue, count._builtinWordValue)
    return UnsafeMutableRawPointer(self)
  }

  /// Executes the given closure while temporarily binding the specified number
  /// of instances to the given type.
  ///
  /// Use this method when you have a pointer to memory bound to one type and
  /// you need to access that memory as instances of another type. Accessing
  /// memory as a type `T` requires that the memory be bound to that type. A
  /// memory location may only be bound to one type at a time, so accessing
  /// the same memory as an unrelated type without first rebinding the memory
  /// is undefined.
  ///
  /// The region of memory starting at this pointer and covering `count`
  /// instances of the pointer's `Pointee` type must be initialized.
  ///
  /// The following example temporarily rebinds the memory of a `UInt64`
  /// pointer to `Int64`, then accesses a property on the signed integer.
  ///
  ///     let uint64Pointer: UnsafeMutablePointer<UInt64> = fetchValue()
  ///     let isNegative = uint64Pointer.withMemoryRebound(to: Int64.self) { ptr in
  ///         return ptr.pointee < 0
  ///     }
  ///
  /// Because this pointer's memory is no longer bound to its `Pointee` type
  /// while the `body` closure executes, do not access memory using the
  /// original pointer from within `body`. Instead, use the `body` closure's
  /// pointer argument to access the values in memory as instances of type
  /// `T`.
  ///
  /// After executing `body`, this method rebinds memory back to the original
  /// `Pointee` type.
  ///
  /// - Note: Only use this method to rebind the pointer's memory to a type
  ///   with the same size and stride as the currently bound `Pointee` type.
  ///   To bind a region of memory to a type that is a different size, convert
  ///   the pointer to a raw pointer and use the `bindMemory(to:capacity:)`
  ///   method.
  ///
  /// - Parameters:
  ///   - type: The type to temporarily bind the memory referenced by this
  ///     pointer. The type `T` must be the same size and be layout compatible
  ///     with the pointer's `Pointee` type.
  ///   - count: The number of instances of `Pointee` to bind to `type`.
  ///   - body: A closure that takes a mutable typed pointer to the
  ///     same memory as this pointer, only bound to type `T`. The closure's
  ///     pointer argument is valid only for the duration of the closure's
  ///     execution. If `body` has a return value, that value is also used as
  ///     the return value for the `withMemoryRebound(to:capacity:_:)` method.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  @inlinable
  public func withMemoryRebound<T, Result>(to type: T.Type, capacity count: Int,
    _ body: (UnsafeMutablePointer<T>) throws -> Result
  ) rethrows -> Result {
    Builtin.bindMemory(_rawValue, count._builtinWordValue, T.self)
    defer {
      Builtin.bindMemory(_rawValue, count._builtinWordValue, Pointee.self)
    }
    return try body(UnsafeMutablePointer<T>(_rawValue))
  }

  /// Accesses the pointee at the specified offset from this pointer.
  ///
  /// For a pointer `p`, the memory at `p + i` must be initialized when reading
  /// the value by using the subscript. When the subscript is used as the left
  /// side of an assignment, the memory at `p + i` must be initialized or
  /// the pointer's `Pointee` type must be a trivial type.
  ///
  /// Do not assign an instance of a nontrivial type through the subscript to
  /// uninitialized memory. Instead, use an initializing method, such as
  /// `initialize(to:count:)`.
  ///
  /// - Parameter i: The offset from this pointer at which to access an
  ///   instance, measured in strides of the pointer's `Pointee` type.
  @inlinable
  public subscript(i: Int) -> Pointee {
    @_transparent
    unsafeAddress {
      return UnsafePointer(self + i)
    }
    @_transparent
    nonmutating unsafeMutableAddress {
      return self + i
    }
  }

  @inlinable // unsafe-performance
  internal static var _max: UnsafeMutablePointer {
    return UnsafeMutablePointer(
      bitPattern: 0 as Int &- MemoryLayout<Pointee>.stride
    )._unsafelyUnwrappedUnchecked
  }
}
