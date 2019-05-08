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

//
// StringGuts is a parameterization over String's representations. It provides
// functionality and guidance for efficiently working with Strings.
//
@_fixed_layout
public // SPI(corelibs-foundation)
struct _StringGuts {
  @usableFromInline
  internal var _object: _StringObject

  @inlinable @inline(__always)
  internal init(_ object: _StringObject) {
    self._object = object
    _invariantCheck()
  }

  // Empty string
  @inlinable @inline(__always)
  init() {
    self.init(_StringObject(empty: ()))
  }
}

// Raw
extension _StringGuts {
  @inlinable @inline(__always)
  internal var rawBits: _StringObject.RawBitPattern { _object.rawBits }
}

// Creation
extension _StringGuts {
  @inlinable @inline(__always)
  internal init(_ smol: _SmallString) {
    self.init(_StringObject(smol))
  }

  @inlinable @inline(__always)
  internal init(_ bufPtr: UnsafeBufferPointer<UInt8>, isASCII: Bool) {
    self.init(_StringObject(immortal: bufPtr, isASCII: isASCII))
  }

  @inline(__always)
  internal init(_ storage: __StringStorage) {
    self.init(_StringObject(storage))
  }

  internal init(_ storage: __SharedStringStorage) {
    self.init(_StringObject(storage))
  }

  internal init(
    cocoa: AnyObject, providesFastUTF8: Bool, isASCII: Bool, length: Int
  ) {
    self.init(_StringObject(
      cocoa: cocoa,
      providesFastUTF8: providesFastUTF8,
      isASCII: isASCII,
      length: length))
  }
}

// Queries
extension _StringGuts {
  // The number of code units
  @inlinable @inline(__always)
  internal var count: Int { _object.count }

  @inlinable @inline(__always)
  internal var isEmpty: Bool { count == 0 }

  @inlinable @inline(__always)
  internal var isSmall: Bool { _object.isSmall }

  @inline(__always)
  internal var isSmallASCII: Bool { _object.isSmall && _object.smallIsASCII }

  @inlinable @inline(__always)
  internal var asSmall: _SmallString { _SmallString(_object) }

  @inlinable @inline(__always)
  internal var isASCII: Bool  { _object.isASCII }

  @inlinable @inline(__always)
  internal var isFastASCII: Bool  { isFastUTF8 && _object.isASCII }

  @inline(__always)
  internal var isNFC: Bool { _object.isNFC }

  @inline(__always)
  internal var isNFCFastUTF8: Bool {
    // TODO(String micro-performance): Consider a dedicated bit for this
    _object.isNFC && isFastUTF8
  }

  internal var hasNativeStorage: Bool { _object.hasNativeStorage }

  internal var hasSharedStorage: Bool { _object.hasSharedStorage }

  internal var hasBreadcrumbs: Bool { hasNativeStorage || hasSharedStorage }
}

//
extension _StringGuts {
  // Whether we can provide fast access to contiguous UTF-8 code units
  @_transparent
  @inlinable
  internal var isFastUTF8: Bool { _fastPath(_object.providesFastUTF8) }

  // A String which does not provide fast access to contiguous UTF-8 code units
  @inlinable @inline(__always)
  internal var isForeign: Bool { _slowPath(_object.isForeign) }

  @inlinable @inline(__always)
  internal func withFastUTF8<R>(
    _ f: (UnsafeBufferPointer<UInt8>) throws -> R
  ) rethrows -> R {
    _internalInvariant(isFastUTF8)

    if self.isSmall { return try _SmallString(_object).withUTF8(f) }

    defer { _fixLifetime(self) }
    return try f(_object.fastUTF8)
  }

  @inlinable @inline(__always)
  internal func withFastUTF8<R>(
    range: Range<Int>,
    _ f: (UnsafeBufferPointer<UInt8>) throws -> R
  ) rethrows -> R {
    try self.withFastUTF8 { wholeUTF8 in
      try f(UnsafeBufferPointer(rebasing: wholeUTF8[range]))
    }
  }

  @inlinable @inline(__always)
  internal func withFastCChar<R>(
    _ f: (UnsafeBufferPointer<CChar>) throws -> R
  ) rethrows -> R {
    try self.withFastUTF8 { utf8 in
      let ptr = utf8.baseAddress._unsafelyUnwrappedUnchecked._asCChar
      return try f(UnsafeBufferPointer(start: ptr, count: utf8.count))
    }
  }
}

// Internal invariants
extension _StringGuts {
  #if !INTERNAL_CHECKS_ENABLED
  @inlinable @inline(__always) internal func _invariantCheck() {}
  #else
  @usableFromInline @inline(never) @_effects(releasenone)
  internal func _invariantCheck() {
    #if arch(i386) || arch(arm)
    _internalInvariant(MemoryLayout<String>.size == 12, """
    the runtime is depending on this, update Reflection.mm and \
    this if you change it
    """)
    #else
    _internalInvariant(MemoryLayout<String>.size == 16, """
    the runtime is depending on this, update Reflection.mm and \
    this if you change it
    """)
    #endif
  }
  #endif // INTERNAL_CHECKS_ENABLED

  internal func _dump() { _object._dump() }
}

// C String interop
extension _StringGuts {
  @inlinable @inline(__always) // fast-path: already C-string compatible
  internal func withCString<Result>(
    _ body: (UnsafePointer<Int8>) throws -> Result
  ) rethrows -> Result {
    if _slowPath(!_object.isFastZeroTerminated) {
      return try _slowWithCString(body)
    }

    return try self.withFastCChar {
      return try body($0.baseAddress._unsafelyUnwrappedUnchecked)
    }
  }

  @inline(never) // slow-path
  @usableFromInline
  internal func _slowWithCString<Result>(
    _ body: (UnsafePointer<Int8>) throws -> Result
  ) rethrows -> Result {
    _internalInvariant(!_object.isFastZeroTerminated)
    return try String(self).utf8CString.withUnsafeBufferPointer {
      let ptr = $0.baseAddress._unsafelyUnwrappedUnchecked
      return try body(ptr)
    }
  }
}

extension _StringGuts {
  // Copy UTF-8 contents. Returns number written or nil if not enough space.
  // Contents of the buffer are unspecified if nil is returned.
  @inlinable
  internal func copyUTF8(into mbp: UnsafeMutableBufferPointer<UInt8>) -> Int? {
    let ptr = mbp.baseAddress._unsafelyUnwrappedUnchecked
    if _fastPath(self.isFastUTF8) {
      return self.withFastUTF8 { utf8 in
        guard utf8.count <= mbp.count else { return nil }

        let utf8Start = utf8.baseAddress._unsafelyUnwrappedUnchecked
        ptr.initialize(from: utf8Start, count: utf8.count)
        return utf8.count
      }
    }

    return _foreignCopyUTF8(into: mbp)
  }
  @_effects(releasenone)
  @usableFromInline @inline(never) // slow-path
  internal func _foreignCopyUTF8(
    into mbp: UnsafeMutableBufferPointer<UInt8>
  ) -> Int? {
    #if _runtime(_ObjC)
    // Currently, foreign  means NSString
    return _cocoaStringCopyUTF8(_object.cocoaObject, into: mbp)
    #else
    fatalError("No foreign strings on Linux in this version of Swift")
    #endif
  }

  @inline(__always)
  internal var utf8Count: Int {
    if _fastPath(self.isFastUTF8) { return count }
    return String(self).utf8.count
  }
}

// Index
extension _StringGuts {
  @usableFromInline
  internal typealias Index = String.Index

  @inlinable @inline(__always)
  internal var startIndex: String.Index { Index(_encodedOffset: 0) }
  @inlinable @inline(__always)
  internal var endIndex: String.Index { Index(_encodedOffset: self.count) }
}

// Old SPI(corelibs-foundation)
extension _StringGuts {
  @available(*, deprecated)
  public // SPI(corelibs-foundation)
  var _isContiguousASCII: Bool { !isSmall && isFastUTF8 && isASCII }

  @available(*, deprecated)
  public // SPI(corelibs-foundation)
  var _isContiguousUTF16: Bool { false }

  // FIXME: Remove. Still used by swift-corelibs-foundation
  @available(*, deprecated)
  public var startASCII: UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer(mutating: _object.fastUTF8.baseAddress!)
  }

  // FIXME: Remove. Still used by swift-corelibs-foundation
  @available(*, deprecated)
  public var startUTF16: UnsafeMutablePointer<UTF16.CodeUnit> {
    fatalError("Not contiguous UTF-16")
  }
}

@available(*, deprecated)
public // SPI(corelibs-foundation)
func _persistCString(_ p: UnsafePointer<CChar>?) -> [CChar]? {
  guard let s = p else { return nil }
  let count = Int(_swift_stdlib_strlen(s))
  var result = [CChar](repeating: 0, count: count + 1)
  for i in 0..<count {
    result[i] = s[i]
  }
  return result
}

