// RUN: %target-run-simple-swift

import StdlibUnittest

var ArrayAutodiffTests = TestSuite("ArrayAutodiff")

typealias FloatArrayGrad = Array<Float>.CotangentVector

ArrayAutodiffTests.test("ArrayIdentity") {
  func arrayIdentity(_ x: [Float]) -> [Float] {
    return x
  }

  expectEqual(
    FloatArrayGrad([1, 2, 3, 4]),
    pullback(at: [5, 6, 7, 8], in: arrayIdentity)(FloatArrayGrad([1, 2, 3, 4])))
}

ArrayAutodiffTests.test("ArraySubscript") {
  func sumFirstThree(_ array: [Float]) -> Float {
    return array[0] + array[1] + array[2]
  }

  expectEqual(
    FloatArrayGrad([1, 1, 1, 0, 0, 0]),
    gradient(at: [2, 3, 4, 5, 6, 7], in: sumFirstThree))
}

ArrayAutodiffTests.test("ArrayConcat") {
  struct TwoArrays : Differentiable {
    let a: [Float]
    let b: [Float]
  }

  func sumFirstThreeConcatted(_ arrs: TwoArrays) -> Float {
    let c = arrs.a + arrs.b
    return c[0] + c[1] + c[2]
  }

  expectEqual(
    TwoArrays.CotangentVector(a: FloatArrayGrad([1, 1]), b: FloatArrayGrad([1, 0])),
    gradient(at: TwoArrays(a: [0, 0], b: [0, 0]), in: sumFirstThreeConcatted))
  expectEqual(
    TwoArrays.CotangentVector(a: FloatArrayGrad([1, 1, 1, 0]), b: FloatArrayGrad([0, 0])),
    gradient(at: TwoArrays(a: [0, 0, 0, 0], b: [0, 0]), in: sumFirstThreeConcatted))
  expectEqual(
    TwoArrays.CotangentVector(a: FloatArrayGrad([]), b: FloatArrayGrad([1, 1, 1, 0])),
    gradient(at: TwoArrays(a: [], b: [0, 0, 0, 0]), in: sumFirstThreeConcatted))
}

ArrayAutodiffTests.test("Array.DifferentiableView.init") {
  @differentiable
  func constructView(_ x: [Float]) -> Array<Float>.DifferentiableView {
    return Array<Float>.DifferentiableView(x)
  }

  let backprop = pullback(at: [5, 6, 7, 8], in: constructView)
  expectEqual(
    FloatArrayGrad([1, 2, 3, 4]),
    backprop(FloatArrayGrad([1, 2, 3, 4])))
}

ArrayAutodiffTests.test("Array.DifferentiableView.array") {
  @differentiable
  func accessArray(_ x: Array<Float>.DifferentiableView) -> [Float] {
    return x.array
  }

  let backprop = pullback(at: Array<Float>.DifferentiableView([5, 6, 7, 8]), in: accessArray)
  expectEqual(
    FloatArrayGrad([1, 2, 3, 4]),
    backprop(FloatArrayGrad([1, 2, 3, 4])))
}

runAllTests()
