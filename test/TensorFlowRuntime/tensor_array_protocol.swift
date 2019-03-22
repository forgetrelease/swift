// RUN: %empty-directory(%t)
// RUN: %target-build-swift -swift-version 5 -g %s -o %t/a.out
// RUN: %target-codesign %t/a.out
// RUN: %target-run %t/a.out
// REQUIRES: executable_test
//
// `TensorArrayProtocol` tests.

import TensorFlow
import StdlibUnittest

var TensorArrayProtocolTests = TestSuite("TensorArrayProtocol")

struct Empty : TensorArrayProtocol {}

struct Simple : TensorArrayProtocol {
  var w, b: Tensor<Float>
}

struct Mixed : TensorArrayProtocol {
  // Mutable.
  var string: StringTensor
  var float: Tensor<Float>
  // Immutable.
  let int: Tensor<Int32>
}

struct Nested : TensorArrayProtocol {
  // Immutable.
  let simple: Simple
  // Mutable.
  var mixed: Mixed
}

struct Generic<T: TensorArrayProtocol, U: TensorArrayProtocol> : TensorArrayProtocol {
  var t: T
  var u: U
}

TensorArrayProtocolTests.test("Empty") {
  expectEqual(0, Empty()._tensorHandleCount)
}

TensorArrayProtocolTests.test("Simple") {
  let w = Tensor<Float>(0.1)
  let b = Tensor<Float>(0.1)
  expectEqual(2, Simple(w: w, b: b)._tensorHandleCount)
}

TensorArrayProtocolTests.test("Mixed") {
  let string = StringTensor("Test")
  let float = Tensor<Float>(0.1)
  let int = Tensor<Int32>(1)
  let mixed = Mixed(string: string, float: float, int: int)
  expectEqual(3, mixed._tensorHandleCount)
}

TensorArrayProtocolTests.test("Nested") {
  let w = Tensor<Float>(0.1)
  let b = Tensor<Float>(0.1)
  let simple = Simple(w: w, b: b)
  let string = StringTensor("Test")
  let float = Tensor<Float>(0.1)
  let int = Tensor<Int32>(1)
  let mixed = Mixed(string: string, float: float, int: int)
  let nested = Nested(simple: simple, mixed: mixed)
  expectEqual(5, nested._tensorHandleCount)
}

TensorArrayProtocolTests.test("Generic") {
  let w = Tensor<Float>(0.1)
  let b = Tensor<Float>(0.1)
  let simple = Simple(w: w, b: b)
  let string = StringTensor("Test")
  let float = Tensor<Float>(0.1)
  let int = Tensor<Int32>(1)
  let mixed = Mixed(string: string, float: float, int: int)
  let generic = Generic<Simple, Mixed>(t: simple, u: mixed)
  expectEqual(5, generic._tensorHandleCount)
}

runAllTests()
