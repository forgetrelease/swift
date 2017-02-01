//===--- HeapObject.cpp - Swift Language ABI Allocation Support -----------===//
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
//
// Allocation ABI Shims While the Language is Bootstrapped
//
//===----------------------------------------------------------------------===//

#include "swift/Basic/Lazy.h"
#include "swift/Runtime/HeapObject.h"
#include "swift/Runtime/Heap.h"
#include "swift/Runtime/Metadata.h"
#include "swift/ABI/System.h"
#include "llvm/Support/MathExtras.h"
#include "MetadataCache.h"
#include "Private.h"
#include "swift/Runtime/Debug.h"
#include <algorithm>
#include <cassert>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include "../SwiftShims/RuntimeShims.h"
#if SWIFT_OBJC_INTEROP
# include <objc/NSObject.h>
# include <objc/runtime.h>
# include <objc/message.h>
# include <objc/objc.h>
#include "swift/Runtime/ObjCBridge.h"
#endif
#include "Leaks.h"

using namespace swift;

HeapObject *swift::swift_allocObject(HeapMetadata const *metadata,
                                     size_t requiredSize,
                                     size_t requiredAlignmentMask)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  return SWIFT_RT_ENTRY_REF(swift_allocObject)(metadata, requiredSize,
                                               requiredAlignmentMask);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
HeapObject *
SWIFT_RT_ENTRY_IMPL(swift_allocObject)(HeapMetadata const *metadata,
                                       size_t requiredSize,
                                       size_t requiredAlignmentMask)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  assert(isAlignmentMask(requiredAlignmentMask));
  auto object = reinterpret_cast<HeapObject *>(
      SWIFT_RT_ENTRY_CALL(swift_slowAlloc)(requiredSize,
                                           requiredAlignmentMask));
  // FIXME: this should be a placement new but that adds a null check
  object->metadata = metadata;
  object->refCount.init();
  object->weakRefCount.init();

  // If leak tracking is enabled, start tracking this object.
  SWIFT_LEAKS_START_TRACKING_OBJECT(object);

  return object;
}

HeapObject *
swift::swift_initStackObject(HeapMetadata const *metadata,
                             HeapObject *object) {
  object->metadata = metadata;
  object->refCount.init();
  object->weakRefCount.initForNotDeallocating();

  return object;

}

void
swift::swift_verifyEndOfLifetime(HeapObject *object) {
  if (object->refCount.getCount() != 0)
    swift::fatalError(/* flags = */ 0,
                      "fatal error: stack object escaped\n");
  
  if (object->weakRefCount.getCount() != 1)
    swift::fatalError(/* flags = */ 0,
                      "fatal error: weak/unowned reference to stack object\n");
}

/// \brief Allocate a reference-counted object on the heap that
/// occupies <size> bytes of maximally-aligned storage.  The object is
/// uninitialized except for its header.
SWIFT_RUNTIME_EXPORT
HeapObject* swift_bufferAllocate(
  HeapMetadata const* bufferType, size_t size, size_t alignMask)
{
  return swift::SWIFT_RT_ENTRY_CALL(swift_allocObject)(bufferType, size,
                                                       alignMask);
}

SWIFT_RUNTIME_EXPORT
intptr_t swift_bufferHeaderSize() { return sizeof(HeapObject); }

namespace {
/// Heap object destructor for a generic box allocated with swift_allocBox.
static void destroyGenericBox(HeapObject *o) {
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  // Destroy the object inside.
  auto *value = metadata->project(o);
  metadata->BoxedType->vw_destroy(value);

  // Deallocate the box.
  SWIFT_RT_ENTRY_CALL(swift_deallocObject) (o, metadata->getAllocSize(),
                                            metadata->getAllocAlignMask());
}

class BoxCacheEntry {
public:
  FullMetadata<GenericBoxHeapMetadata> Data;

  BoxCacheEntry(const Metadata *type)
    : Data{HeapMetadataHeader{{destroyGenericBox}, {/*vwtable*/ nullptr}},
           GenericBoxHeapMetadata{MetadataKind::HeapGenericLocalVariable,
                                  GenericBoxHeapMetadata::getHeaderOffset(type),
                                  type}} {
  }

  long getKeyIntValueForDump() {
    return reinterpret_cast<long>(Data.BoxedType);
  }

  int compareWithKey(const Metadata *type) const {
    return comparePointers(type, Data.BoxedType);
  }

  static size_t getExtraAllocationSize(const Metadata *key) {
    return 0;
  }
  size_t getExtraAllocationSize() const {
    return 0;
  }
};

} // end anonymous namespace

static SimpleGlobalCache<BoxCacheEntry> Boxes;

SWIFT_CC(swift)
BoxPair::Return swift::swift_allocBox(const Metadata *type) {
  return SWIFT_RT_ENTRY_REF(swift_allocBox)(type);
}

SWIFT_CC(swift) SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
BoxPair::Return SWIFT_RT_ENTRY_IMPL(swift_allocBox)(const Metadata *type) {
  // Get the heap metadata for the box.
  auto metadata = &Boxes.getOrInsert(type).first->Data;

  // Allocate and project the box.
  auto allocation = SWIFT_RT_ENTRY_CALL(swift_allocObject)(
      metadata, metadata->getAllocSize(), metadata->getAllocAlignMask());
  auto projection = metadata->project(allocation);

  return BoxPair{allocation, projection};
}

void swift::swift_deallocBox(HeapObject *o) {
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  SWIFT_RT_ENTRY_CALL(swift_deallocObject)(o, metadata->getAllocSize(),
                                           metadata->getAllocAlignMask());
}

OpaqueValue *swift::swift_projectBox(HeapObject *o) {
  // The compiler will use a nil reference as a way to avoid allocating memory
  // for boxes of empty type. The address of an empty value is always undefined,
  // so we can just return nil back in this case.
  if (!o)
    return reinterpret_cast<OpaqueValue*>(o);
  auto metadata = static_cast<const GenericBoxHeapMetadata *>(o->metadata);
  return metadata->project(o);
}

// Forward-declare this, but define it after swift_release.
extern "C" LLVM_LIBRARY_VISIBILITY void
_swift_release_dealloc(HeapObject *object) SWIFT_CC(RegisterPreservingCC_IMPL)
    __attribute__((__noinline__, __used__));

void swift::swift_retain(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  SWIFT_RT_ENTRY_REF(swift_retain)(object);
}

void swift::swift_nonatomic_retain(HeapObject *object) {
  SWIFT_RT_ENTRY_REF(swift_nonatomic_retain)(object);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_nonatomic_retain)(HeapObject *object) {
  _swift_nonatomic_retain_inlined(object);
}

void swift::swift_nonatomic_release(HeapObject *object) {
  return SWIFT_RT_ENTRY_REF(swift_nonatomic_release)(object);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_nonatomic_release)(HeapObject *object) {
  if (object  &&  object->refCount.decrementShouldDeallocateNonAtomic()) {
    // TODO: Use non-atomic _swift_release_dealloc?
    _swift_release_dealloc(object);
  }
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_retain)(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  _swift_retain_inlined(object);
}

void swift::swift_retain_n(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  SWIFT_RT_ENTRY_REF(swift_retain_n)(object, n);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_retain_n)(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object) {
    object->refCount.increment(n);
  }
}

void swift::swift_nonatomic_retain_n(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  SWIFT_RT_ENTRY_REF(swift_nonatomic_retain_n)(object, n);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_nonatomic_retain_n)(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object) {
    object->refCount.incrementNonAtomic(n);
  }
}

void swift::swift_release(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  SWIFT_RT_ENTRY_REF(swift_release)(object);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_release)(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object  &&  object->refCount.decrementShouldDeallocate()) {
    _swift_release_dealloc(object);
  }
}

void swift::swift_release_n(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  return SWIFT_RT_ENTRY_REF(swift_release_n)(object, n);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_release_n)(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementShouldDeallocateN(n)) {
    _swift_release_dealloc(object);
  }
}

void swift::swift_setDeallocating(HeapObject *object) {
  object->refCount.decrementFromOneAndDeallocateNonAtomic();
}

void swift::swift_nonatomic_release_n(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  return SWIFT_RT_ENTRY_REF(swift_nonatomic_release_n)(object, n);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
void SWIFT_RT_ENTRY_IMPL(swift_nonatomic_release_n)(HeapObject *object, uint32_t n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementShouldDeallocateNNonAtomic(n)) {
    _swift_release_dealloc(object);
  }
}

size_t swift::swift_retainCount(HeapObject *object) {
  return object->refCount.getCount();
}

size_t swift::swift_unownedRetainCount(HeapObject *object) {
  return object->weakRefCount.getCount();
}

void swift::swift_unownedRetain(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  object->weakRefCount.increment();
}

void swift::swift_unownedRelease(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  if (object->weakRefCount.decrementShouldDeallocate()) {
    // Only class objects can be weak-retained and weak-released.
    auto metadata = object->metadata;
    assert(metadata->isClassObject());
    auto classMetadata = static_cast<const ClassMetadata*>(metadata);
    assert(classMetadata->isTypeMetadata());
    SWIFT_RT_ENTRY_CALL(swift_slowDealloc)
        (object, classMetadata->getInstanceSize(),
         classMetadata->getInstanceAlignMask());
  }
}

void swift::swift_unownedRetain_n(HeapObject *object, int n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  object->weakRefCount.increment(n);
}

void swift::swift_unownedRelease_n(HeapObject *object, int n)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;

  if (object->weakRefCount.decrementShouldDeallocateN(n)) {
    // Only class objects can be weak-retained and weak-released.
    auto metadata = object->metadata;
    assert(metadata->isClassObject());
    auto classMetadata = static_cast<const ClassMetadata*>(metadata);
    assert(classMetadata->isTypeMetadata());
    SWIFT_RT_ENTRY_CALL(swift_slowDealloc)
        (object, classMetadata->getInstanceSize(),
         classMetadata->getInstanceAlignMask());
  }
}

HeapObject *swift::swift_tryPin(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  assert(object);

  // Try to set the flag.  If this succeeds, the caller will be
  // responsible for clearing it.
  if (object->refCount.tryIncrementAndPin()) {
    return object;
  }

  // If setting the flag failed, it's because it was already set.
  // Return nil so that the object will be deallocated later.
  return nullptr;
}

void swift::swift_unpin(HeapObject *object)
  SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementAndUnpinShouldDeallocate()) {
    _swift_release_dealloc(object);
  }
}

HeapObject *swift::swift_tryRetain(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  return SWIFT_RT_ENTRY_REF(swift_tryRetain)(object);
}

HeapObject *swift::swift_nonatomic_tryPin(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  assert(object);

  // Try to set the flag.  If this succeeds, the caller will be
  // responsible for clearing it.
  if (object->refCount.tryIncrementAndPinNonAtomic()) {
    return object;
  }

  // If setting the flag failed, it's because it was already set.
  // Return nil so that the object will be deallocated later.
  return nullptr;
}

void swift::swift_nonatomic_unpin(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (object && object->refCount.decrementAndUnpinShouldDeallocateNonAtomic()) {
    _swift_release_dealloc(object);
  }
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
HeapObject *SWIFT_RT_ENTRY_IMPL(swift_tryRetain)(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return nullptr;

  if (object->refCount.tryIncrement()) return object;
  else return nullptr;
}

SWIFT_RUNTIME_EXPORT
bool swift_isDeallocating(HeapObject *object) {
  return SWIFT_RT_ENTRY_REF(swift_isDeallocating)(object);
}

SWIFT_RT_ENTRY_IMPL_VISIBILITY
extern "C"
bool SWIFT_RT_ENTRY_IMPL(swift_isDeallocating)(HeapObject *object) {
  if (!object) return false;
  return object->refCount.isDeallocating();
}

void swift::swift_unownedRetainStrong(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (! object->refCount.tryIncrement())
    _swift_abortRetainUnowned(object);
}

void swift::swift_unownedRetainStrongAndRelease(HeapObject *object)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  if (!object)
    return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (! object->refCount.tryIncrement())
    _swift_abortRetainUnowned(object);

  // This should never cause a deallocation.
  bool dealloc = object->weakRefCount.decrementShouldDeallocate();
  assert(!dealloc && "retain-strong-and-release caused dealloc?");
  (void) dealloc;
}

void swift::swift_unownedCheck(HeapObject *object) {
  if (!object) return;
  assert(object->weakRefCount.getCount() &&
         "object is not currently weakly retained");

  if (object->refCount.isDeallocating())
    _swift_abortRetainUnowned(object);
}

// Declared extern "C" LLVM_LIBRARY_VISIBILITY above.
void _swift_release_dealloc(HeapObject *object)
  SWIFT_CC(RegisterPreservingCC_IMPL) {
  asFullMetadata(object->metadata)->destroy(object);
}

#if SWIFT_OBJC_INTEROP
/// Perform the root -dealloc operation for a class instance.
void swift::swift_rootObjCDealloc(HeapObject *self) {
  auto metadata = self->metadata;
  assert(metadata->isClassObject());
  auto classMetadata = static_cast<const ClassMetadata*>(metadata);
  assert(classMetadata->isTypeMetadata());
  swift_deallocClassInstance(self, classMetadata->getInstanceSize(),
                             classMetadata->getInstanceAlignMask());
}
#endif

void swift::swift_deallocClassInstance(HeapObject *object,
                                       size_t allocatedSize,
                                       size_t allocatedAlignMask) {
#if SWIFT_OBJC_INTEROP
  // We need to let the ObjC runtime clean up any associated objects or weak
  // references associated with this object.
  objc_destructInstance((id)object);
#endif
  SWIFT_RT_ENTRY_CALL(swift_deallocObject)
      (object, allocatedSize,
       allocatedAlignMask);
}

/// Variant of the above used in constructor failure paths.
SWIFT_RUNTIME_EXPORT
void swift_deallocPartialClassInstance(HeapObject *object,
                                       HeapMetadata const *metadata,
                                       size_t allocatedSize,
                                       size_t allocatedAlignMask) {
  if (!object)
    return;

  // Destroy ivars
  auto *classMetadata = _swift_getClassOfAllocated(object)->getClassObject();
  assert(classMetadata && "Not a class?");
  while (classMetadata != metadata) {
#if SWIFT_OBJC_INTEROP
    // If we have hit a pure Objective-C class, we won't see another ivar
    // destroyer.
    if (classMetadata->isPureObjC()) {
      // Set the class to the pure Objective-C superclass, so that when dealloc
      // runs, it starts at that superclass.
      object_setClass((id)object, (Class)classMetadata);

      // Release the object.
      objc_release((id)object);
      return;
    }
#endif

    if (auto fn = classMetadata->getIVarDestroyer())
      fn(object);

    classMetadata = classMetadata->SuperClass->getClassObject();
    assert(classMetadata && "Given metatype not a superclass of object type?");
  }

#if SWIFT_OBJC_INTEROP
  // If this class doesn't use Swift-native reference counting, use
  // objc_release instead.
  if (!usesNativeSwiftReferenceCounting(classMetadata)) {
    // Find the pure Objective-C superclass.
    while (!classMetadata->isPureObjC())
      classMetadata = classMetadata->SuperClass->getClassObject();

    // Set the class to the pure Objective-C superclass, so that when dealloc
    // runs, it starts at that superclass.
    object_setClass((id)object, (Class)classMetadata);

    // Release the object.
    objc_release((id)object);
    return;
  }
#endif

  // The strong reference count should be +1 -- tear down the object
  bool shouldDeallocate = object->refCount.decrementShouldDeallocate();
  assert(shouldDeallocate);
  (void) shouldDeallocate;
  swift_deallocClassInstance(object, allocatedSize, allocatedAlignMask);
}

#if !defined(__APPLE__) && defined(SWIFT_RUNTIME_CLOBBER_FREED_OBJECTS)
static inline void memset_pattern8(void *b, const void *pattern8, size_t len) {
  char *ptr = static_cast<char *>(b);
  while (len >= 8) {
    memcpy(ptr, pattern8, 8);
    ptr += 8;
    len -= 8;
  }
  memcpy(ptr, pattern8, len);
}
#endif

void swift::swift_deallocObject(HeapObject *object, size_t allocatedSize,
                                size_t allocatedAlignMask)
    SWIFT_CC(RegisterPreservingCC_IMPL) {
  assert(isAlignmentMask(allocatedAlignMask));
  assert(object->refCount.isDeallocating());
#ifdef SWIFT_RUNTIME_CLOBBER_FREED_OBJECTS
  memset_pattern8((uint8_t *)object + sizeof(HeapObject),
                  "\xAB\xAD\x1D\xEA\xF4\xEE\xD0\bB9",
                  allocatedSize - sizeof(HeapObject));
#endif

  // If we are tracking leaks, stop tracking this object.
  SWIFT_LEAKS_STOP_TRACKING_OBJECT(object);

  // Drop the initial weak retain of the object.
  //
  // If the outstanding weak retain count is 1 (i.e. only the initial
  // weak retain), we can immediately call swift_slowDealloc.  This is
  // useful both as a way to eliminate an unnecessary atomic
  // operation, and as a way to avoid calling swift_unownedRelease on an
  // object that might be a class object, which simplifies the logic
  // required in swift_unownedRelease for determining the size of the
  // object.
  //
  // If we see that there is an outstanding weak retain of the object,
  // we need to fall back on swift_release, because it's possible for
  // us to race against a weak retain or a weak release.  But if the
  // outstanding weak retain count is 1, then anyone attempting to
  // increase the weak reference count is inherently racing against
  // deallocation and thus in undefined-behavior territory.  And
  // we can even do this with a normal load!  Here's why:
  //
  // 1. There is an invariant that, if the strong reference count
  // is > 0, then the weak reference count is > 1.
  //
  // 2. The above lets us say simply that, in the absence of
  // races, once a reference count reaches 0, there are no points
  // which happen-after where the reference count is > 0.
  //
  // 3. To not race, a strong retain must happen-before a point
  // where the strong reference count is > 0, and a weak retain
  // must happen-before a point where the weak reference count
  // is > 0.
  //
  // 4. Changes to either the strong and weak reference counts occur
  // in a total order with respect to each other.  This can
  // potentially be done with a weaker memory ordering than
  // sequentially consistent if the architecture provides stronger
  // ordering for memory guaranteed to be co-allocated on a cache
  // line (which the reference count fields are).
  //
  // 5. This function happens-after a point where the strong
  // reference count was 0.
  //
  // 6. Therefore, if a normal load in this function sees a weak
  // reference count of 1, it cannot be racing with a weak retain
  // that is not racing with deallocation:
  //
  //   - A weak retain must happen-before a point where the weak
  //     reference count is > 0.
  //
  //   - This function logically decrements the weak reference
  //     count.  If it is possible for it to see a weak reference
  //     count of 1, then at the end of this function, the
  //     weak reference count will logically be 0.
  //
  //   - There can be no points after that point where the
  //     weak reference count will be > 0.
  //
  //   - Therefore either the weak retain must happen-before this
  //     function, or this function cannot see a weak reference
  //     count of 1, or there is a race.
  //
  // Note that it is okay for there to be a race involving a weak
  // *release* which happens after the strong reference count drops to
  // 0.  However, this is harmless: if our load fails to see the
  // release, we will fall back on swift_unownedRelease, which does an
  // atomic decrement (and has the ability to reconstruct
  // allocatedSize and allocatedAlignMask).
  if (object->weakRefCount.getCount() == 1) {
    SWIFT_RT_ENTRY_CALL(swift_slowDealloc)
         (object, allocatedSize,
          allocatedAlignMask);
  } else {
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
}

enum: uintptr_t {
  WR_NATIVE = 1<<(swift::heap_object_abi::ObjCReservedLowBits),
  WR_READING = 1<<(swift::heap_object_abi::ObjCReservedLowBits+1),

  WR_NATIVEMASK = WR_NATIVE | swift::heap_object_abi::ObjCReservedBitsMask,
};

static_assert(WR_READING < alignof(void*),
              "weakref lock bit mustn't interfere with real pointer bits");

enum: short {
  WR_SPINLIMIT = 64,
};

bool swift::isNativeSwiftWeakReference(WeakReference *ref) {
  return (ref->Value & WR_NATIVEMASK) == WR_NATIVE;
}

void swift::swift_weakInit(WeakReference *ref, HeapObject *value) {
  ref->Value = (uintptr_t)value | WR_NATIVE;
  SWIFT_RT_ENTRY_CALL(swift_unownedRetain)(value);
}

void swift::swift_weakAssign(WeakReference *ref, HeapObject *newValue) {
  SWIFT_RT_ENTRY_CALL(swift_unownedRetain)(newValue);
  auto oldValue = (HeapObject*) (ref->Value & ~WR_NATIVE);
  ref->Value = (uintptr_t)newValue | WR_NATIVE;
  SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(oldValue);
}

HeapObject *swift::swift_weakLoadStrong(WeakReference *ref) {
  if (ref->Value == (uintptr_t)nullptr) {
    return nullptr;
  }

  // ref might be visible to other threads
  auto ptr = __atomic_fetch_or(&ref->Value, WR_READING, __ATOMIC_RELAXED);
  while (ptr & WR_READING) {
    short c = 0;
    while (__atomic_load_n(&ref->Value, __ATOMIC_RELAXED) & WR_READING) {
      if (++c == WR_SPINLIMIT) {
        std::this_thread::yield();
        c -= 1;
      }
    }
    ptr = __atomic_fetch_or(&ref->Value, WR_READING, __ATOMIC_RELAXED);
  }

  auto object = (HeapObject*)(ptr & ~WR_NATIVE);
  if (object == nullptr) {
    __atomic_store_n(&ref->Value, (uintptr_t)nullptr, __ATOMIC_RELAXED);
    return nullptr;
  }
  if (object->refCount.isDeallocating()) {
    __atomic_store_n(&ref->Value, (uintptr_t)nullptr, __ATOMIC_RELAXED);
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
    return nullptr;
  }
  auto result = swift_tryRetain(object);
  __atomic_store_n(&ref->Value, ptr, __ATOMIC_RELAXED);
  return result;
}

HeapObject *swift::swift_weakTakeStrong(WeakReference *ref) {
  auto object = (HeapObject*) (ref->Value & ~WR_NATIVE);
  if (object == nullptr) return nullptr;
  auto result = swift_tryRetain(object);
  ref->Value = (uintptr_t)nullptr;
  swift_unownedRelease(object);
  return result;
}

void swift::swift_weakDestroy(WeakReference *ref) {
  auto tmp = (HeapObject*) (ref->Value & ~WR_NATIVE);
  ref->Value = (uintptr_t)nullptr;
  SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(tmp);
}

void swift::swift_weakCopyInit(WeakReference *dest, WeakReference *src) {
  if (src->Value == (uintptr_t)nullptr) {
    dest->Value = (uintptr_t)nullptr;
    return;
  }

  // src might be visible to other threads
  auto ptr = __atomic_fetch_or(&src->Value, WR_READING, __ATOMIC_RELAXED);
  while (ptr & WR_READING) {
    short c = 0;
    while (__atomic_load_n(&src->Value, __ATOMIC_RELAXED) & WR_READING) {
      if (++c == WR_SPINLIMIT) {
        std::this_thread::yield();
        c -= 1;
      }
    }
    ptr = __atomic_fetch_or(&src->Value, WR_READING, __ATOMIC_RELAXED);
  }

  auto object = (HeapObject*)(ptr & ~WR_NATIVE);
  if (object == nullptr) {
    __atomic_store_n(&src->Value, (uintptr_t)nullptr, __ATOMIC_RELAXED);
    dest->Value = (uintptr_t)nullptr;
  } else if (object->refCount.isDeallocating()) {
    __atomic_store_n(&src->Value, (uintptr_t)nullptr, __ATOMIC_RELAXED);
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
    dest->Value = (uintptr_t)nullptr;
  } else {
    SWIFT_RT_ENTRY_CALL(swift_unownedRetain)(object);
    __atomic_store_n(&src->Value, ptr, __ATOMIC_RELAXED);
    dest->Value = (uintptr_t)object | WR_NATIVE;
  }
}

void swift::swift_weakTakeInit(WeakReference *dest, WeakReference *src) {
  auto object = (HeapObject*) (src->Value & ~WR_NATIVE);
  if (object == nullptr) {
    dest->Value = (uintptr_t)nullptr;
  } else if (object->refCount.isDeallocating()) {
    dest->Value = (uintptr_t)nullptr;
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
  } else {
    dest->Value = (uintptr_t)object | WR_NATIVE;
  }
  src->Value = (uintptr_t)nullptr;
}

void swift::swift_weakCopyAssign(WeakReference *dest, WeakReference *src) {
  if (dest->Value) {
    auto object = (HeapObject*) (dest->Value & ~WR_NATIVE);
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
  swift_weakCopyInit(dest, src);
}

void swift::swift_weakTakeAssign(WeakReference *dest, WeakReference *src) {
  if (dest->Value) {
    auto object = (HeapObject*) (dest->Value & ~WR_NATIVE);
    SWIFT_RT_ENTRY_CALL(swift_unownedRelease)(object);
  }
  swift_weakTakeInit(dest, src);
}

void swift::_swift_abortRetainUnowned(const void *object) {
  (void)object;
  swift::crash("attempted to retain deallocated object");
}
