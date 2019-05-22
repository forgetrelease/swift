// RUN: %target-run-simple-swift %swift-tensorflow-test-run-extra-options
// REQUIRES: executable_test

// This file contains stubs for functions that the playground transform in
// lib/Sema/PlaygroundTransform.cpp generates calls into.

import TensorFlow
import TensorFlowUnittest
import StdlibUnittest

var TopLevelTests = TestSuite("TopLevel")

let g = Tensor<Float>(1.0)

// This function is not inlined into main(). Confirm that it can read the global
// var properly and does not crash.
func SR8405() {
  expectNearlyEqualWithScalarTensor(1.0, g)
}

TopLevelTests.testAllBackends("TopLevel") {
  SR8405()
}

runAllTests()
