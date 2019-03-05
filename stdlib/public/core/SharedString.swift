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

extension String {
  /// Creates a `String` whose backing store is shared with the UTF-8 data
  /// referenced by the given buffer pointer.
  ///
  /// The `owner` argument should manage the lifetime of the shared buffer and
  /// its deinitializer is responsible for deallocating `buffer`. The `String`
  /// instance created by this initializer retains `owner` so that deallocation
  /// occurs after the string is no longer in use. The buffer _must not_ be
  /// deallocated while there are any strings sharing it.
  ///
  /// This initializer does not try to repair ill-formed UTF-8 code unit
  /// sequences. If any are found, the result of the initializer is `nil`.
  ///
  /// - Parameters:
  ///   - buffer: An `UnsafeBufferPointer` containing the UTF-8 bytes that
  ///     should be shared with the created `String`.
  ///   - owner: An optional object that owns the memory referenced by `buffer`
  ///     and is responsible for deallocating it.
  public init?(
    sharingContent buffer: UnsafeBufferPointer<UInt8>,
    owner: AnyObject?
  ) {
    guard let baseAddress = buffer.baseAddress,
      case .success(let extraInfo) = validateUTF8(buffer)
    else {
      return nil
    }
    let storage = __SharedStringStorage(
      immortal: baseAddress,
      countAndFlags: _StringObject.CountAndFlags(
        sharedCount: buffer.count,
        isASCII: extraInfo.isASCII))
    storage._owner = owner
    self.init(String(_StringGuts(storage)))
  }

  /// Creates a `String` whose backing store is shared with the UTF-8 data in
  /// the given array.
  ///
  /// The new `String` instance shares ownership of the array's underlying
  /// storage, guaranteeing that the `String` remains valid even if the `array`
  /// is released.
  ///
  /// This initializer does not try to repair ill-formed UTF-8 code unit
  /// sequences. If any are found, the result of the initializer is `nil`.
  ///
  /// - Parameter array: An `Array` containing the UTF-8 bytes that should be
  ///   shared with the created `String`.
  public init?(sharing array: [UInt8]) {
    guard case (let owner, let rawPtr?) = array._cPointerArgs() else {
      self = ""
      return
    }
    let baseAddress = rawPtr.assumingMemoryBound(to: UInt8.self)
    let buffer = UnsafeBufferPointer(start: baseAddress, count: array.count)
    self.init(sharingContent: buffer, owner: owner)
  }
}

extension Substring {
  /// Calls the given closure, passing it a `String` whose contents are equal to
  /// the substring but which shares the substring's storage instead of copying
  /// it.
  ///
  /// The `String` value passed into the closure is only valid durings its
  /// execution.
  ///
  /// - Parameter body: A closure with a `String` parameter that shares the
  ///   storage of the substring. If `body` has a return value, that value is
  ///   also used as the return value for the `withSharedString(_:)` method. The
  ///   argument is valid only for the duration of the closure's execution.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  public func withSharedString<Result>(
    _ body: (String) throws -> Result
  ) rethrows -> Result {
    guard _wholeGuts.isFastUTF8 else {
      // TODO: What's the right way to get the pointer for a non-fast-UTF-8
      // string here?
      return try body(String(self))
    }

    return try _wholeGuts.withFastUTF8 { utf8 in
      let storage = __SharedStringStorage(
        immortal: utf8.baseAddress! + self._offsetRange.lowerBound,
        countAndFlags: _StringObject.CountAndFlags(
          sharedCount: self._offsetRange.count,
          isASCII: _wholeGuts.isASCII))
      let str = String(_StringGuts(storage))
      return try body(str)
    }
  }
}
