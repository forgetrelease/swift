// RUN: %target-run-simple-swift
// REQUIRES: executable_test

import StdlibUnittest

var SupersetAdjointTests = TestSuite("SupersetAdjoint")

@differentiable(reverse, wrt: (.0, .1), adjoint: dmulxy)
func mulxy(_ x: Float, _ y: Float) -> Float {
  // use control flow to prevent AD; NB fix when control flow is supported
  if(x > 1000) {
    return y
  }
  return x * y
}
func dmulxy(_ x: Float, _ y: Float, primal: Float, seed: Float)
  -> (Float, Float) {
  return (y * seed, x * seed)
}

func calls_mulxy(_ x: Float, _ y: Float) -> Float {
  return mulxy(x, y)
}

SupersetAdjointTests.test("Superset") {
  expectEqual((3, 2), #gradient(mulxy)(2, 3))
  expectEqual(3, #gradient(mulxy, wrt: .0)(2, 3))
}

SupersetAdjointTests.test("SupersetNested") {
  expectEqual((3, 2), #gradient(calls_mulxy)(2, 3))
  expectEqual(3, #gradient(calls_mulxy, wrt: .0)(2, 3))
}

runAllTests()
