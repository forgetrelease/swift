// RUN: %target-run-sese-loops-swift
// REQUIRES: executable_test
// REQUIRES: swift_test_mode_optimize

import TensorFlow
import TensorFlowUnittest
import StdlibUnittest

var ControlFlowTests = TestSuite("ControlFlow")

func powerOfTwo(_ N: Int32) -> Tensor<Float>{
  var a = Tensor<Float>(1.0)
  for _ in 0..<N {
    a += a
  }
  return a
}

ControlFlowTests.testAllBackends("powerOfTwo") {
  expectNearlyEqualWithScalarTensor(2.0, powerOfTwo(1))
  expectNearlyEqualWithScalarTensor(4.0, powerOfTwo(2))
  expectNearlyEqualWithScalarTensor(8.0, powerOfTwo(3))
  expectNearlyEqualWithScalarTensor(1024.0, powerOfTwo(10))
}

func natSumWithBreak(_ breakIndex: Int32) -> Tensor<Int32> {
  var i: Int32 = 1
  var sum = Tensor<Int32>(0);
  let maxCount: Int32 = 100
  while i <= maxCount {
    sum += i
    if (i == breakIndex) {
      break;
    }
    i += 1
  }
  return sum;
}

ControlFlowTests.testAllBackends("natSumWithBreak") {
  expectEqualWithScalarTensor(3, natSumWithBreak(2))
  expectEqualWithScalarTensor(55, natSumWithBreak(10))
  expectEqualWithScalarTensor(5050, natSumWithBreak(-300))
  expectEqualWithScalarTensor(5050, natSumWithBreak(100))
  expectEqualWithScalarTensor(5050, natSumWithBreak(200))
}

func sumOfProducts(_ M : Int32, _ N : Int32) -> Tensor<Float> {
  // Effectively computes natSum(M)*natSum(N)
  var sum = Tensor<Float>(0)
  for i in 0..<M {
    for j in 0..<N {
      // i + 1 and j + 1 is a workaround for
      // https://bugs.swift.org/browse/SR-8256
      let prod = Tensor<Float>(Float((i + 1) * (j + 1)));
      sum += prod
    }
  }
  return sum
}

ControlFlowTests.testAllBackends("sumOfProducts") {
  expectNearlyEqualWithScalarTensor(18.0, sumOfProducts(2, 3))
  expectNearlyEqualWithScalarTensor(1980.0,sumOfProducts(10, 8))
  expectNearlyEqualWithScalarTensor(11550.0,sumOfProducts(20, 10))
}

// A contrived example to test labeled breaks
func sumOfProductsWithBound(_ M : Int32, _ N : Int32, _ Bound : Float) -> Tensor<Float> {
  // Effectively computes natSum(M)*natSum(N) upto Bound
  var sum = Tensor<Float>(0)
outer_loop:for i in 0..<M {
    for j in 0..<N {
      // i + 1 and j + 1 is a workaround for
      // https://bugs.swift.org/browse/SR-8256
      let prod = Tensor<Float>(Float((i + 1) * (j + 1)));
      sum += prod
      if (sum.scalarized() >= Bound) {
        break outer_loop;
      }
    }
  }
  return sum
}

ControlFlowTests.testAllBackends("sumOfProductsWithBound") {
  expectNearlyEqualWithScalarTensor(6, sumOfProductsWithBound(3, 3, 4))
  expectNearlyEqualWithScalarTensor(8, sumOfProductsWithBound(2, 3, 7))
  expectNearlyEqualWithScalarTensor(8, sumOfProductsWithBound(3, 3, 7))
  expectNearlyEqualWithScalarTensor(18, sumOfProductsWithBound(3, 3, 18))
  // Effectively no bound as natSum(3) * natSum(3) is 36.
  expectNearlyEqualWithScalarTensor(36, sumOfProductsWithBound(3, 3, 100))
}

runAllTests()
