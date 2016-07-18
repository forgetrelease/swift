// RUN: %target-run-simple-swift
// REQUIRES: executable_test

// Disabled because of a crash with a debug stdlib - rdar://problem/27226313
// REQUIRES: optimized_stdlib

// REQUIRES: objc_interop

import StdlibUnittest
import Dispatch

let iterations = 200_000

class Thing {}

class WBox<T: AnyObject> {
  weak var wref: T?
  init(_ ref: T) { self.wref = ref }
  init() { self.wref = nil }
}

let WeakReferenceRaceTests = TestSuite("WeakReferenceRaceTests")

func forwardOptional<T>(_ t: T!) -> T {
  return t!
}

WeakReferenceRaceTests.test("class instance property [SR-192] (copy)") {
  let q = DispatchQueue(label: "", attributes: .concurrent)

  // Capture a weak reference via its container object
  // "https://bugs.swift.org/browse/SR-192"
  for i in 1...iterations {
    let box = WBox(Thing())
    let closure = {
      let nbox = WBox<Thing>()
      nbox.wref = box.wref
      _blackHole(nbox)
    }

    q.asynchronously(execute: closure)
    q.asynchronously(execute: closure)
  }

  q.asynchronously(flags: .barrier) {}
}

WeakReferenceRaceTests.test("class instance property [SR-192] (load)") {
  let q = DispatchQueue(label: "", attributes: .concurrent)

  // Capture a weak reference via its container object
  // "https://bugs.swift.org/browse/SR-192"
  for i in 1...iterations {
    let box = WBox(Thing())
    let closure = {
      if let ref = box.wref {
        _blackHole(ref)
      }
    }

    q.asynchronously(execute: closure)
    q.asynchronously(execute: closure)
  }

  q.asynchronously(flags: .barrier) {}
}

WeakReferenceRaceTests.test("direct capture (copy)") {
  let q = DispatchQueue(label: "", attributes: .concurrent)

  // Capture a weak reference directly in multiple closures
  for i in 1...iterations {
    weak var wref = Thing()
    let closure = {
      let nbox = WBox<Thing>()
      nbox.wref = wref
      _blackHole(nbox)
    }

    q.asynchronously(execute: closure)
    q.asynchronously(execute: closure)
  }

  q.asynchronously(flags: .barrier) {}
}

WeakReferenceRaceTests.test("direct capture (load)") {
  let q = DispatchQueue(label: "", attributes: .concurrent)

  // Capture a weak reference directly in multiple closures
  for i in 1...iterations {
    weak var wref = Thing()
    let closure = {
      if let ref = wref {
        _blackHole(ref)
      }
    }

    q.asynchronously(execute: closure)
    q.asynchronously(execute: closure)
  }

  q.asynchronously(flags: .barrier) {}
}

runAllTests()
