//===--- Filter.swift - tests for lazy filtering --------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - current Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test

import StdlibUnittest


let FilterTests = TestSuite("Filter")

// Check that the generic parameter is called 'Base'.
protocol TestProtocol1 {}

extension LazyFilterIterator where Base : TestProtocol1 {
  var _baseIsTestProtocol1: Bool {
    fatalError("not implemented")
  }
}

extension LazyFilterSequence where Base : TestProtocol1 {
  var _baseIsTestProtocol1: Bool {
    fatalError("not implemented")
  }
}

extension LazyFilterCollection where Base : TestProtocol1 {
  var _baseIsTestProtocol1: Bool {
    fatalError("not implemented")
  }
}

FilterTests.test("filtering collections") {
  let f0 = LazyFilterCollection(_base: 0..<30) { $0 % 7 == 0 }
  expectEqualSequence([0, 7, 14, 21, 28], f0)

  let f1 = LazyFilterCollection(_base: 1..<30) { $0 % 7 == 0 }
  expectEqualSequence([7, 14, 21, 28], f1)
}

FilterTests.test("filtering sequences") {
  let f0 = (0..<30).makeIterator().lazy.filter { $0 % 7 == 0 }
  expectEqualSequence([0, 7, 14, 21, 28], f0)

  let f1 = (1..<30).makeIterator().lazy.filter { $0 % 7 == 0 }
  expectEqualSequence([7, 14, 21, 28], f1)
}

FilterTests.test("single-count") {
  // Check that we're only calling a lazy filter's predicate one time for
  // each element in a sequence or collection.
  var count = 0
  let mod7AndCount: (Int) -> Bool = {
    count += 1
    return $0 % 7 == 0
  }
    
  let f0 = (0..<30).makeIterator().lazy.filter(mod7AndCount)
  let a0 = Array(f0)
  expectEqual(30, count)

  count = 0
  let f1 = LazyFilterCollection(_base: 0..<30, mod7AndCount)
  let a1 = Array(f1)
  expectEqual(30, count)
}

FilterTests.test("Double filter type/Sequence") {
  func foldingLevels<S : Sequence>(_ xs: S) {
    var result = xs.lazy.filter { _ in true }.filter { _ in true }
    expectType(LazyFilterSequence<S>.self, &result)
  }
  foldingLevels(Array(0..<10))

  func backwardCompatible<S : Sequence>(_ xs: S) {
    typealias ExpectedType = LazyFilterSequence<LazyFilterSequence<S>>
    var result: ExpectedType = xs.lazy
      .filter { _ in true }.filter { _ in true }
    expectType(ExpectedType.self, &result)
  }
  backwardCompatible(Array(0..<10))
}

FilterTests.test("Double filter type/Collection") {
  func foldingLevels<C : Collection>(_ xs: C) {
    var result = xs.lazy.filter { _ in true }.filter { _ in true }
    expectType(LazyFilterCollection<C>.self, &result)
  }
  foldingLevels(Array(0..<10))

  func backwardCompatible<C : Collection>(_ xs: C) {
    typealias ExpectedType = LazyFilterCollection<LazyFilterCollection<C>>
    var result: ExpectedType = xs.lazy
      .filter { _ in true }.filter { _ in true }
    expectType(ExpectedType.self, &result)
  }
  backwardCompatible(Array(0..<10))
}

runAllTests()
