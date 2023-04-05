//===--- _SwiftCxxInteroperability.h - C++ Interop support ------*- C++ -*-===//
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
//
//  Defines types and support functions required by C++ bindings generated
//  by the Swift compiler that allow C++ code to call Swift APIs.
//
//===----------------------------------------------------------------------===//
#ifndef SWIFT_CXX_INTEROPERABILITY_H
#define SWIFT_CXX_INTEROPERABILITY_H

#ifdef __cplusplus

#include <cstdint>
#include <stdlib.h>
#if defined(_WIN32)
#include <malloc.h>
#endif
#if !defined(SWIFT_CALL)
# define SWIFT_CALL __attribute__((swiftcall))
#endif

#if __has_attribute(transparent_stepping)
#define SWIFT_INLINE_THUNK_ATTRIBUTES                                          \
  __attribute__((transparent_stepping))
#elif __has_attribute(always_inline) && __has_attribute(nodebug)
 #define SWIFT_INLINE_THUNK_ATTRIBUTES                                          \
   __attribute__((always_inline)) __attribute__((nodebug))
#else
#define SWIFT_INLINE_THUNK_ATTRIBUTES
#endif

#if defined(DEBUG) && __has_attribute(used)
// Additional 'used' attribute is used in debug mode to make inline thunks
// accessible to LLDB.
#define SWIFT_INLINE_THUNK_USED_ATTRIBUTE __attribute__((used))
#else
#define SWIFT_INLINE_THUNK_USED_ATTRIBUTE
#endif

/// The `SWIFT_INLINE_THUNK` macro is applied on the inline function thunks in
/// the header that represents a C/C++ Swift module interface generated by the
/// Swift compiler.
#define SWIFT_INLINE_THUNK                                                     \
  inline SWIFT_INLINE_THUNK_ATTRIBUTES SWIFT_INLINE_THUNK_USED_ATTRIBUTE

/// The `SWIFT_INLINE_PRIVATE_HELPER` macro is applied on the helper / utility
/// functions in the header that represents a C/C++ Swift module interface
/// generated by the Swift compiler.
#define SWIFT_INLINE_PRIVATE_HELPER inline SWIFT_INLINE_THUNK_ATTRIBUTES

/// The `SWIFT_SYMBOL_MODULE` and `SWIFT_SYMBOL_MODULE_USR` macros apply
/// `external_source_symbol` Clang attributes to C++ declarations that represent
/// Swift declarations. This allows Clang to index them as external
/// declarations, using the specified Swift USR values.
#if __has_attribute(external_source_symbol)
#define SWIFT_SYMBOL_MODULE(moduleValue)                                       \
  __attribute__((external_source_symbol(                                       \
      language = "Swift", defined_in = moduleValue, generated_declaration)))
#if __has_attribute(external_source_symbol) > 1
#define SWIFT_SYMBOL_MODULE_USR(moduleValue, usrValue)                         \
  __attribute__((                                                              \
      external_source_symbol(language = "Swift", defined_in = moduleValue,     \
                             generated_declaration, USR = usrValue)))
#else
#define SWIFT_SYMBOL_MODULE_USR(moduleValue, usrValue)                         \
  __attribute__((external_source_symbol(                                       \
      language = "Swift", defined_in = moduleValue, generated_declaration)))
#endif
#else
#define SWIFT_SYMBOL_MODULE_USR(moduleValue, usrValue)
#define SWIFT_SYMBOL_MODULE(moduleValue)
#endif

#if __has_attribute(swift_private)
#define SWIFT_PRIVATE_ATTR __attribute__((swift_private))
#else
#define SWIFT_PRIVATE_ATTR
#endif

namespace swift SWIFT_PRIVATE_ATTR {
namespace _impl {

extern "C" void *_Nonnull swift_retain(void *_Nonnull) noexcept;

extern "C" void swift_release(void *_Nonnull) noexcept;

SWIFT_INLINE_THUNK void *_Nonnull opaqueAlloc(size_t size,
                                              size_t align) noexcept {
#if defined(_WIN32)
  void *r = _aligned_malloc(size, align);
#else
  if (align < sizeof(void *))
    align = sizeof(void *);
  void *r = nullptr;
  int res = posix_memalign(&r, align, size);
  (void)res;
#endif
  return r;
}

SWIFT_INLINE_THUNK void opaqueFree(void *_Nonnull p) noexcept {
#if defined(_WIN32)
  _aligned_free(p);
#else
  free(p);
#endif
}

/// Base class for a container for an opaque Swift value, like resilient struct.
class OpaqueStorage {
public:
  SWIFT_INLINE_THUNK OpaqueStorage() noexcept : storage(nullptr) {}
  SWIFT_INLINE_THUNK OpaqueStorage(size_t size, size_t alignment) noexcept
      : storage(reinterpret_cast<char *>(opaqueAlloc(size, alignment))) {}
  SWIFT_INLINE_THUNK OpaqueStorage(OpaqueStorage &&other) noexcept
      : storage(other.storage) {
    other.storage = nullptr;
  }
  OpaqueStorage(const OpaqueStorage &) noexcept = delete;

  SWIFT_INLINE_THUNK ~OpaqueStorage() noexcept {
    if (storage) {
      opaqueFree(static_cast<char *_Nonnull>(storage));
    }
  }

  SWIFT_INLINE_THUNK void operator=(OpaqueStorage &&other) noexcept {
    auto temp = storage;
    storage = other.storage;
    other.storage = temp;
  }
  void operator=(const OpaqueStorage &) noexcept = delete;

  SWIFT_INLINE_THUNK char *_Nonnull getOpaquePointer() noexcept {
    return static_cast<char *_Nonnull>(storage);
  }
  SWIFT_INLINE_THUNK const char *_Nonnull getOpaquePointer() const noexcept {
    return static_cast<char *_Nonnull>(storage);
  }

private:
  char *_Nullable storage;
};

/// Base class for a Swift reference counted class value.
class RefCountedClass {
public:
  SWIFT_INLINE_THUNK ~RefCountedClass() { swift_release(_opaquePointer); }
  SWIFT_INLINE_THUNK RefCountedClass(const RefCountedClass &other) noexcept
      : _opaquePointer(other._opaquePointer) {
    swift_retain(_opaquePointer);
  }
  SWIFT_INLINE_THUNK RefCountedClass &
  operator=(const RefCountedClass &other) noexcept {
    swift_retain(other._opaquePointer);
    swift_release(_opaquePointer);
    _opaquePointer = other._opaquePointer;
    return *this;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-noreturn"
  // FIXME: implement 'move'?
  SWIFT_INLINE_THUNK RefCountedClass(RefCountedClass &&) noexcept { abort(); }
#pragma clang diagnostic pop

protected:
  SWIFT_INLINE_THUNK RefCountedClass(void *_Nonnull ptr) noexcept
      : _opaquePointer(ptr) {}

private:
  void *_Nonnull _opaquePointer;
  friend class _impl_RefCountedClass;
};

class _impl_RefCountedClass {
public:
  static SWIFT_INLINE_THUNK void *_Nonnull getOpaquePointer(
      const RefCountedClass &object) {
    return object._opaquePointer;
  }
  static SWIFT_INLINE_THUNK void *_Nonnull &
  getOpaquePointerRef(RefCountedClass &object) {
    return object._opaquePointer;
  }
  static SWIFT_INLINE_THUNK void *_Nonnull copyOpaquePointer(
      const RefCountedClass &object) {
    swift_retain(object._opaquePointer);
    return object._opaquePointer;
  }
};

} // namespace _impl

/// Swift's Int type.
using Int = ptrdiff_t;

/// Swift's UInt type.
using UInt = size_t;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc++17-extensions"

/// True if the given type is a Swift type that can be used in a generic context
/// in Swift.
template <class T>
static inline const constexpr bool isUsableInGenericContext = false;

/// Returns the type metadata for the given Swift type T.
template <class T> struct TypeMetadataTrait {
  static SWIFT_INLINE_THUNK void *_Nonnull getTypeMetadata();
};

namespace _impl {

/// Type trait that returns the `_impl::_impl_<T>` class type for the given
/// class T.
template <class T> struct implClassFor {
  // using type = ...;
};

/// True if the given type is a Swift value type.
template <class T> static inline const constexpr bool isValueType = false;

/// True if the given type is a Swift value type with opaque layout that can be
/// boxed.
template <class T> static inline const constexpr bool isOpaqueLayout = false;

/// True if the given type is a C++ record that was bridged to Swift, giving
/// Swift ability to work with it in a generic context.
template <class T>
static inline const constexpr bool isSwiftBridgedCxxRecord = false;

/// Returns the opaque pointer to the given value.
template <class T>
SWIFT_INLINE_THUNK const void *_Nonnull getOpaquePointer(const T &value) {
  if constexpr (isOpaqueLayout<T>)
    return reinterpret_cast<const OpaqueStorage &>(value).getOpaquePointer();
  return reinterpret_cast<const void *>(&value);
}

template <class T>
SWIFT_INLINE_THUNK void *_Nonnull getOpaquePointer(T &value) {
  if constexpr (isOpaqueLayout<T>)
    return reinterpret_cast<OpaqueStorage &>(value).getOpaquePointer();
  return reinterpret_cast<void *>(&value);
}

} // namespace _impl

#pragma clang diagnostic pop

} // namespace swift SWIFT_PRIVATE_ATTR
#endif

#endif // SWIFT_CXX_INTEROPERABILITY_H
