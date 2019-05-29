// RUN: %target-run-simple-swift %swift-tensorflow-test-run-extra-options
// REQUIRES: executable_test
//
// Tensor API tests.

import TensorFlow
import TensorFlowUnittest
import StdlibUnittest

var TensorTests = TestSuite("Tensor")

TensorTests.testAllBackends("Initializers") {
  let scalar = Tensor<Float>(1)
  let matrix: Tensor<Float> = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
  let broadcastScalar = Tensor<Float>(broadcasting: 10, rank: 3)
  let some4d = Tensor<Float>(shape: [2, 1, 2, 1],
                             scalars: AnyRandomAccessCollection([2, 3, 4, 5]))
  expectEqual(ShapedArray(shape: [2, 1, 2, 1], scalars: [2, 3, 4, 5]),
              some4d.array)
  expectEqual(ShapedArray(shape: [], scalars: [1]), scalar.array)
  expectEqual(ShapedArray(shape: [2, 3], scalars: [1, 2, 3, 4, 5, 6]),
              matrix.array)
  expectEqual(ShapedArray(shape: [1, 1, 1], scalars: [10]),
              broadcastScalar.array)
}

TensorTests.testAllBackends("FactoryInitializers") {
  let x = Tensor<Float>(ones: [1, 10])
  expectEqual(ShapedArray(repeating: 1, shape: [1, 10]), x.array)
}

TensorTests.testAllBackends("NumericInitializers") {
  let x = Tensor<Float>(oneHotAtIndices: [0, 2, -1, 1], depth: 3)
  expectEqual(ShapedArray(shape: [4, 3], scalars: [1, 0, 0,
                                                   0, 0, 1,
                                                   0, 0, 0,
                                                   0, 1, 0]),
              x.array)
}

TensorTests.testAllBackends("ScalarToTensorConversion") {
  let tensor = Tensor<Float>(broadcasting: 42, rank: 4)
  expectEqual([1, 1, 1, 1], tensor.shape)
  expectEqual([42], tensor.scalars)
}

TensorTests.testAllBackends("ArrayConversion") {
  let array3D = ShapedArray(repeating: 1.0, shape: [2, 3, 4])
  let tensor3D = Tensor(array3D)
  expectEqual(array3D, tensor3D.array)
}

TensorTests.testAllBackends("DataTypeCast_NonTPU") {
  let x = Tensor<Int32>(ones: [5, 5])
  let ints = Tensor<Int64>(x)
  let floats = Tensor<Float>(x)
  let i8s = Tensor<Int8>(floats)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), ints.array)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), floats.array)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), i8s.array)
}

TensorTests.testAllBackends("DataTypeCast_TPU") {
  let x = Tensor<Int32>(ones: [5, 5])
  let ints = Tensor<Int64>(x)
  let floats = Tensor<Float>(x)
  let u32s = Tensor<UInt32>(floats)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), ints.array)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), floats.array)
  expectEqual(ShapedArray(repeating: 1, shape: [5, 5]), u32s.array)
}

TensorTests.testAllBackends("BoolToNumericCast_NonTPU") {
  let bools = Tensor<Bool>(shape: [2, 2], scalars: [true, false, true, false])
  let ints = Tensor<Int64>(bools)
  let floats = Tensor<Float>(bools)
  let i8s = Tensor<Int8>(bools)
  expectEqual(ShapedArray(shape: [2, 2], scalars: [1, 0, 1, 0]), ints.array)
  expectEqual(ShapedArray(shape: [2, 2], scalars: [1, 0, 1, 0]), floats.array)
  expectEqual(ShapedArray(shape: [2, 2], scalars: [1, 0, 1, 0]), i8s.array)
}

TensorTests.testAllBackends("ElementIndexing") {
  // NOTE: cannot test multiple `Tensor.shape` or `Tensor.scalars` directly
  // until send and receive are implemented (without writing a bunch of mini
  // tests). Instead, `Tensor.array` is called to make a ShapedArray host copy
  // and the ShapedArray is tested.
  let tensor3D = Tensor<Float>(shape: [3, 4, 5],
                               scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let element2D = tensor3D[2]
  let element1D = tensor3D[1][3]
  let element0D = tensor3D[2][0][3]

  let array2D = element2D.array
  let array1D = element1D.array
  let array0D = element0D.array

  /// Test shapes
  expectEqual([4, 5], array2D.shape)
  expectEqual([5], array1D.shape)
  expectEqual([], array0D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 40.0, to: 60, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 35.0, to: 40, by: 1)), array1D.scalars)
  expectEqual([43], array0D.scalars)
}

#if !CUDA
// TODO(https://bugs.swift.org/browse/TF-469): This test fails in GPU mode.
TensorTests.testAllBackends("ElementIndexingAssignment") {
  // NOTE: cannot test multiple `Tensor.shape` or `Tensor.scalars` directly
  // until send and receive are implemented (without writing a bunch of mini
  // tests). Instead, `Tensor.array` is called to make a ShapedArray host copy
  // and the ShapedArray is tested.
  var tensor3D = Tensor<Float>(shape: [3, 4, 5],
                               scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  tensor3D[2] = Tensor<Float>(shape: [4, 5],
                              scalars: Array(stride(from: 20.0, to: 40, by: 1)))
  let element2D = tensor3D[2]
  let element1D = tensor3D[1][3]
  let element0D = tensor3D[2][0][3]

  let array2D = element2D.array
  let array1D = element1D.array
  let array0D = element0D.array

  /// Test shapes
  expectEqual([4, 5], array2D.shape)
  expectEqual([5], array1D.shape)
  expectEqual([], array0D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 20.0, to: 40, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 35.0, to: 40, by: 1)), array1D.scalars)
  expectEqual([23], array0D.scalars)
}
#endif // !CUDA

TensorTests.testAllBackends("NestedElementIndexing") {
  // NOTE: This test could use a clearer name, along with other "indexing"
  // tests. Note to update corresponding test names in other files
  // (shaped_array.test) as well.
  let tensor3D = Tensor<Float>(shape: [3, 4, 5],
                               scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let element1D = tensor3D[1, 3]
  let element0D = tensor3D[2, 0, 3]

  let array1D = element1D.array
  let array0D = element0D.array

  /// Test shapes
  expectEqual([5], array1D.shape)
  expectEqual([], array0D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 35.0, to: 40, by: 1)), array1D.scalars)
  expectEqual([43], array0D.scalars)
}

TensorTests.testAllBackends("SliceIndexing") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  let tensor3D = Tensor<Float>(shape: [3, 4, 5],
                               scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let slice3D = tensor3D[2...]
  let slice2D = tensor3D[1][0..<2]
  let slice1D = tensor3D[0][0][3..<5]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 40.0, to: 60, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}

TensorTests.testAllBackends("SliceUpdate") {
  var t1 = Tensor<Float>([[1, 2, 3], [4, 5, 6]])
  t1[0] = Tensor(zeros: [3])
  expectEqual(ShapedArray(shape:[2, 3], scalars: [0, 0, 0, 4, 5, 6]), t1.array)
  var t2 = t1
  t2[0][2] = Tensor(3)
  expectEqual(ShapedArray(shape:[2, 3], scalars: [0, 0, 3, 4, 5, 6]), t2.array)
  var t3 = Tensor<Bool>([[true, true, true], [false, false, false]])
  t3[0][1] = Tensor(false)
  expectEqual(ShapedArray(shape:[2, 3],
                          scalars: [true, false, true, false, false, false]),
              t3.array)
  var t4 = Tensor<Bool>([[true, true, true], [false, false, false]])
  t4[0] = Tensor(repeating: false, shape: [3])
  expectEqual(ShapedArray(repeating: false, shape: [2, 3]), t4.array)
}


#if !CUDA
// TODO(https://bugs.swift.org/browse/TF-469): This test fails in GPU mode.
TensorTests.testAllBackends("SliceIndexingAssignment") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  var tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  tensor3D[2, 0..<5, 0..<6] = Tensor<Float>(
    shape: [4, 5], scalars: Array(stride(from: 20.0, to: 40, by: 1)))
  let slice3D = tensor3D[2...]
  let slice2D = tensor3D[1][0..<2]
  let slice1D = tensor3D[0][0][3..<5]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 20.0, to: 40, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}
#endif // !CUDA

#if !CUDA
// TODO(https://bugs.swift.org/browse/TF-469): This test fails in GPU mode.
TensorTests.testAllBackends("EllipsisIndexing") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  var tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  tensor3D[2, TensorRange.ellipsis] = Tensor<Float>(
    shape: [4, 5], scalars: Array(stride(from: 20.0, to: 40, by: 1)))
  let slice3D = tensor3D[2..., TensorRange.ellipsis]
  let slice2D = tensor3D[1][0..<2]
  let slice1D = tensor3D[0][0][3..<5]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 20.0, to: 40, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}
#endif // !CUDA

TensorTests.testAllBackends("NewAxisIndexing") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  let tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let newAxis = TensorRange.newAxis
  let ellipsis = TensorRange.ellipsis
  let slice3D = tensor3D[2..., newAxis, ellipsis]
  let slice2D = tensor3D[1, newAxis][0..<1, 0..<2]
  let slice1D = tensor3D[0][newAxis, 0][0..<1, 3..<5, newAxis]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 1, 4, 5], array3D.shape)
  expectEqual([1, 2, 5], array2D.shape)
  expectEqual([1, 2, 1], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 40.0, to: 60, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}

TensorTests.testAllBackends("SqueezeAxisIndexing") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  let tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let newAxis = TensorRange.newAxis
  let ellipsis = TensorRange.ellipsis
  let squeezeAxis = TensorRange.squeezeAxis
  let slice3D = tensor3D[2..., newAxis, ellipsis][squeezeAxis, squeezeAxis]
  let slice2D = tensor3D[1, newAxis][squeezeAxis, 0..<2]
  let slice1D = tensor3D[0..<1, 0, 3..<5, newAxis][
    squeezeAxis, ellipsis, squeezeAxis]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 40.0, to: 60, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}

TensorTests.testAllBackends("StridedSliceIndexing") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  let tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let slice3D = tensor3D[2...]
  let slice2D = tensor3D[1][0..<3..2]
  let slice1D = tensor3D[0][0][1..<5..2]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(Array(stride(from: 40.0, to: 60, by: 1)), array3D.scalars)
  expectEqual(
    Array(stride(from: 20.0, to: 25, by: 1)) +
    Array(stride(from: 30.0, to: 35, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 1.0, to: 5, by: 2)), array1D.scalars)
}

#if !CUDA
// TODO(https://bugs.swift.org/browse/TF-469): This test fails in GPU mode.
TensorTests.testAllBackends("StridedSliceIndexingAssignment") {
  // NOTE: cannot test `Tensor.shape` or `Tensor.scalars` directly until send
  // and receive are implemented (without writing a bunch of mini tests).
  // Instead, `Tensor.array` is called to make a ShapedArray host copy and the
  // ShapedArray is tested instead.
  var tensor3D = Tensor<Float>(
    shape: [3, 4, 5], scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  tensor3D[2, 0..<5..2, 0..<6] = Tensor<Float>(
    shape: [2, 5], scalars: Array(stride(from: 20.0, to: 40, by: 2)))
  let slice3D = tensor3D[2...]
  let slice2D = tensor3D[1][0..<2]
  let slice1D = tensor3D[0][0][3..<5]

  let array3D = slice3D.array
  let array2D = slice2D.array
  let array1D = slice1D.array

  /// Test shapes
  expectEqual([1, 4, 5], array3D.shape)
  expectEqual([2, 5], array2D.shape)
  expectEqual([2], array1D.shape)

  /// Test scalars
  expectEqual(
    Array(stride(from: 20.0, to: 30, by: 2)) +
    Array(stride(from: 45.0, to: 50, by: 1)) +
    Array(stride(from: 30.0, to: 40, by: 2)) +
    Array(stride(from: 55.0, to: 60, by: 1)), array3D.scalars)
  expectEqual(Array(stride(from: 20.0, to: 30, by: 1)), array2D.scalars)
  expectEqual(Array(stride(from: 3.0, to: 5, by: 1)), array1D.scalars)
}
#endif // !CUDA

TensorTests.test("WholeTensorSlicing") {
  let t: Tensor<Int32> = [[[1, 1, 1], [2, 2, 2]],
                          [[3, 3, 3], [4, 4, 4]],
                          [[5, 5, 5], [6, 6, 6]]]
  let slice2 = t.slice(lowerBounds: [1, 0, 0], upperBounds: [2, 1, 3])
  expectEqual(ShapedArray(shape: [1, 1, 3], scalars: [3, 3, 3]),
              slice2.array)
}

TensorTests.testAllBackends("AdvancedIndexing") {
  // NOTE: cannot test multiple `Tensor.shape` or `Tensor.scalars` directly
  // until send and receive are implemented (without writing a bunch of mini
  // tests). Instead, `Tensor.array` is called to make a ShapedArray host copy
  // and the ShapedArray is tested.
  let tensor3D = Tensor<Float>(shape: [3, 4, 5],
                               scalars: Array(stride(from: 0.0, to: 60, by: 1)))
  let element2D = tensor3D[1..<3, 0, 3...]
  let array2D = element2D.array

  // Test shape
  expectEqual([2, 2], array2D.shape)

  // Test scalars
  expectEqual(Array([23.0, 24.0, 43.0, 44.0]), array2D.scalars)
}

TensorTests.testAllBackends("Reduction") {
  // 2 x 5
  let x = Tensor<Float>([[1, 2, 3, 4, 5], [1, 2, 3, 4, 5]])
  expectEqual(Tensor(30), x.sum())
  expectEqual(Tensor(shape: [5], scalars: [2, 4, 6, 8, 10]),
              x.sum(squeezingAxes: 0))
  expectEqual(Tensor(shape: [1, 5], scalars: [2, 4, 6, 8, 10]),
              x.sum(alongAxes: 0))

  expectEqual(Tensor(14400), x.product())
  expectEqual(Tensor(shape: [5], scalars: [1, 4, 9, 16, 25]),
              x.product(squeezingAxes: 0))
  expectEqual(Tensor(shape: [1, 5], scalars: [1, 4, 9, 16, 25]),
              x.product(alongAxes: 0))

  expectEqual(Tensor(3), x.mean())
  expectEqual(Tensor(shape: [5], scalars: [1, 2, 3, 4, 5]),
              x.mean(squeezingAxes: 0))
  expectEqual(Tensor(shape: [5], scalars: [1, 2, 3, 4, 5]),
              x.mean(alongAxes: 0))
  expectEqual(Tensor(shape: [2], scalars: [3, 3]),
              x.mean(squeezingAxes: 1))
  expectEqual(Tensor(shape: [1, 2], scalars: [3, 3]),
              x.mean(alongAxes: 1))

  expectEqual(Tensor(2), x.variance())
  expectEqual(Tensor(shape: [5], scalars: [0, 0, 0, 0, 0]),
              x.variance(squeezingAxes: 0))
  expectEqual(Tensor(shape: [5], scalars: [0, 0, 0, 0, 0]),
              x.variance(alongAxes: 0))
  expectEqual(Tensor(shape: [2], scalars: [2, 2]),
              x.variance(squeezingAxes: 1))
  expectEqual(Tensor(shape: [1, 2], scalars: [2, 2]),
              x.variance(alongAxes: 1))
}

TensorTests.testAllBackends("Concatenation") {
  // 2 x 3
  let t1 = Tensor<Int32>([[0, 1, 2], [3, 4, 5]])
  // 2 x 3
  let t2 = Tensor<Int32>([[6, 7, 8], [9, 10, 11]])
  let concatenated = t1 ++ t2
  let concatenated0 = t1.concatenated(with: t2)
  let concatenated1 = t1.concatenated(with: t2, alongAxis: 1)
  expectEqual(ShapedArray(shape: [4, 3], scalars: Array(0..<12)),
              concatenated.array)
  expectEqual(ShapedArray(shape: [4, 3], scalars: Array(0..<12)),
              concatenated0.array)
  expectEqual(ShapedArray(shape: [2, 6],
                          scalars: [0, 1, 2, 6, 7, 8, 3, 4, 5, 9, 10, 11]),
              concatenated1.array)
}

TensorTests.test("EwiseComparison") {
  let x = Tensor<Float>([0, 1, 2])
  let y = Tensor<Float>([2, 1, 3])
  expectEqual((x .< y).scalars, [true, false, true])
}

TensorTests.test("LexicographicalComparison") {
  let x = Tensor<Float>([0, 1, 2, 3, 4])
  let y = Tensor<Float>([2, 3, 4, 5, 6])
  expectTrue(x < y)
}

TensorTests.testAllBackends("ArgMax") {
  // 2 x 3
  let x = Tensor<Float>([[0, 1, 2], [3, 4, 5]])
  let argmax0 = x.argmax(squeezingAxis: 0)
  let argmax1 = x.argmax(squeezingAxis: 1)
  let scalarsArgmax = x.argmax()
  expectEqual(ShapedArray(shape: [3], scalars: [1, 1, 1]), argmax0.array)
  expectEqual(ShapedArray(shape: [2], scalars: [2, 2]), argmax1.array)
  expectEqual(ShapedArray(shape: [], scalars: [5]), scalarsArgmax.array)
}

TensorTests.testAllBackends("CeilFloor") {
  let x = Tensor<Float>([-1.3, -0.4, 0.5, 1.6])
  let xFloor = floor(x)
  let xCeil = ceil(x)
  expectEqual(ShapedArray(shape: [4], scalars: [-2, -1, 0, 1]), xFloor.array)
  expectEqual(ShapedArray(shape: [4], scalars: [-1, 0, 1, 2]), xCeil.array)
}

TensorTests.testAllBackends("SimpleMath") {
  let x = Tensor<Float>([1.2, 1.2])
  let y = tanh(x)
  let array = y.array
  expectEqual([2], array.shape)
  expectPointwiseNearlyEqual([0.833655, 0.833655], array.scalars,
                             byError: 0.0001)
}

TensorTests.testAllBackends("StandardDeviation") {
  expectEqual(Tensor(0), Tensor<Float>([1]).standardDeviation())
  expectEqual(Tensor(0.5), Tensor<Float>([0, 1]).standardDeviation(alongAxes: 0))
  expectEqual(Tensor(0.5), Tensor<Float>([0, 1]).standardDeviation())
  expectNearlyEqual(
    2.87228132,
    Tensor<Float>(rangeFrom: 0, to: 10, stride: 1).standardDeviation().scalarized(),
    byError: 0.001)
  let matrix = Tensor<Float>(rangeFrom: 0, to: 10, stride: 1).reshaped(to: [2, 5])
  expectNearlyEqual(2.87228132,
                    matrix.standardDeviation().scalarized(),
                    byError: 0.001)
  expectPointwiseNearlyEqual(
    [1.4142, 1.4142],
    matrix.standardDeviation(alongAxes: 1).array.scalars,
    byError: 0.001)
}

TensorTests.testAllBackends("3Adds") {
  let a = Tensor<Float>([1])
  let b = Tensor<Float>([2])
  let c = Tensor<Float>([3])

  let o = a + b + c
  expectEqual([6], o.scalars)
}

TensorTests.testAllBackends("MultiOpMath") {
  let x = Tensor<Float>([1.2, 1.2])
  let y = Tensor<Float>([2.4, 2.4])
  let t1 = x + y
  let t2 = t1 * t1
  let t3 = sqrt(t2)

  let array1 = t1.array
  let array2 = t2.array
  let array3 = t3.array
  expectEqual([2], array1.shape)
  expectEqual([2], array2.shape)
  expectEqual([2], array3.shape)
  expectPointwiseNearlyEqual([3.6, 3.6], array1.scalars)
  expectPointwiseNearlyEqual([12.96, 12.96], array2.scalars)
  expectPointwiseNearlyEqual([3.6, 3.6], array3.scalars)
}

TensorTests.testAllBackends("XWPlusB") {
  // Shape: 1 x 4
  let x = Tensor<Float>([[1.0, 2.0, 2.0, 1.0]])
  // Shape: 4 x 2
  let w = Tensor<Float>([[1.0, 0.0], [3.0, 0.0], [2.0, 3.0], [1.0, 0.0]])
  // Shape: 2
  let b = Tensor<Float>([0.5, 0.5])
  // Shape: 1 x 2 (broadcasted)
  let result = matmul(x, w) + b
  expectEqual([1, 2], result.shape)
  expectEqual([12.5, 6.5], result.scalars)
}

TensorTests.testAllBackends("Transpose") {
  // 3 x 2 -> 2 x 3
  let xT = Tensor<Float>([[1, 2], [3, 4], [5, 6]]).transposed()
  let xTArray = xT.array
  expectEqual(2, xTArray.rank)
  expectEqual([2, 3], xTArray.shape)
  expectEqual([1, 3, 5, 2, 4, 6], xTArray.scalars)
}

TensorTests.testAllBackends("SimpleCond") {
  func selectValue(_ pred: Bool) -> Tensor<Int32> {
    let a = Tensor<Int32>(0)
    let b = Tensor<Int32>(1)
    if pred {
      return a
    }
    return b
  }

  expectEqual(0, selectValue(true).scalar)
}

TensorTests.testAllBackends("TensorShapeDescription") {
  expectEqual("[2, 2]", Tensor<Int32>(ones: [2, 2]).shape.description)
  expectEqual("[]", Tensor(1).shape.description)
}

@inline(never)
func testXORInference() {
  func xor(_ x: Float, _ y: Float) -> Float {
    let x = Tensor<Float>([x, y]).reshaped(to: [1, 2])

    // FIXME: If params are declared outside of `xor`, it would crash.
    // 2 x 4
    let w1 = Tensor<Float>(
      [[-1.83586664, -0.20809225, 0.47667537, 1.90780607],
       [-1.83523219, -0.51167348, 0.15490439, 1.91018065]])
    // 1 x 4
    let b1 = Tensor<Float>(
      [[2.54353216, 0.25132703, -0.16503136, -0.85754058]])
    // 4 x 1
    let w2 = Tensor<Float>(
      [[3.04350065], [0.35590511], [-0.3252157], [3.49349223]])
    // 1 x 1
    let b2 = Tensor<Float>([[-0.74635993]])

    let o1 = tanh(matmul(x, w1) + b1)
    let y = tanh(matmul(o1, w2) + b2)
    return y.array.scalars[0] // TODO: use better scalar getter
  }
  expectNearlyEqual(0.0, xor(0.0, 0.0), byError: 0.1)
  expectNearlyEqual(1.0, xor(0.0, 1.0), byError: 0.1)
  expectNearlyEqual(1.0, xor(1.0, 0.0), byError: 0.1)
  expectNearlyEqual(0.0, xor(1.0, 1.0), byError: 0.1)
}
TensorTests.testAllBackends("XORInference", testXORInference)

TensorTests.testAllBackends("MLPClassifierStruct") {
  struct MLPClassifier {
    // 2 x 4
    var w1 = Tensor<Float>([[1.0, 0.8, 0.4, 0.4],
                            [0.4, 0.3, 0.2, 0.1]])
    // 4 x 1
    var w2 = Tensor<Float>([[0.4], [0.4], [0.3], [0.9]])
    var b1 = Tensor<Float>(zeros: [1, 4])
    var b2 = Tensor<Float>(zeros: [1, 1])

    func prediction(for x: Tensor<Float>) -> Tensor<Float> {
      let o1 = tanh(matmul(x, w1) + b1)
      return tanh(matmul(o1, w2) + b2)
    }
  }
  let input = Tensor<Float>([[1, 0.5]])
  let classifier = MLPClassifier()
  let prediction = classifier.prediction(for: input)
  expectPointwiseNearlyEqual([0.816997], prediction.scalars)
}

TensorTests.testAllBackends("ExpandingShape") {
  // 2 x 3 -> 1 x 2 x 1 x 3 x 1
  let matrix = Tensor<Int32>([[0, 1, 2], [3, 4, 5]])
  let reshaped = matrix.expandingShape(at: 0,2,4)

  expectEqual([1, 2, 1, 3, 1], reshaped.shape)
  expectEqual(Array(0..<6), reshaped.scalars)

  // 1 x 2 x 1 x 3 x 1 -> 2 x 3
  let rereshaped = reshaped.squeezingShape(at: 0,2,4)
  expectEqual([2, 3], rereshaped.shape)
  expectEqual(Array(0..<6), rereshaped.scalars)
}

TensorTests.testAllBackends("Reshape") {
  // 2 x 3 -> 1 x 3 x 1 x 2 x 1
  let matrix = Tensor<Int32>([[0, 1, 2], [3, 4, 5]])
  let reshaped = matrix.reshaped(to: [1, 3, 1, 2, 1])

  expectEqual([1, 3, 1, 2, 1], reshaped.shape)
  expectEqual(Array(0..<6), reshaped.scalars)
}

TensorTests.testAllBackends("Flatten") {
  // 2 x 3 -> 6
  let matrix = Tensor<Int32>([[0, 1, 2], [3, 4, 5]])
  let flattened = matrix.flattened()

  expectEqual([6], flattened.shape)
  expectEqual(Array(0..<6), flattened.scalars)
}

TensorTests.testAllBackends("Flatten0D") {
  let scalar = Tensor<Float>(5)
  let flattened = scalar.flattened()
  expectEqual([1], flattened.shape)
  expectEqual([5], flattened.scalars)
}

TensorTests.testAllBackends("ReshapeToScalar") {
  // 1 x 1 -> scalar
  let z = Tensor<Float>([[10]]).reshaped(to: [])
  expectEqual([], z.shape)
}

TensorTests.testAllBackends("ReshapeTensor") {
  // 2 x 3 -> 1 x 3 x 1 x 2 x 1
  let x = Tensor<Float>(repeating: 0.0, shape: [2, 3])
  let y = Tensor<Float>(repeating: 0.0, shape: [1, 3, 1, 2, 1])
  let result = x.reshaped(like: y)
  expectEqual([1, 3, 1, 2, 1], result.shape)
}

TensorTests.testAllBackends("BroadcastTensor") {
  // 1 -> 2 x 3 x 4
  let one = Tensor<Float>(1)
  var target = Tensor<Float>(repeating: 0.0, shape: [2, 3, 4])
  let broadcasted = one.broadcast(like: target)
  expectEqual(Tensor(repeating: 1, shape: [2, 3, 4]), broadcasted)
  target .= Tensor(repeating: 1, shape: [1, 3, 1])
  expectEqual(Tensor(repeating: 1, shape: [2, 3, 4]), target)
}

TensorTests.testAllBackends("Unbroadcast1") {
  let x = Tensor<Float>(repeating: 1, shape: [2, 3, 4, 5])
  let y = Tensor<Float>(repeating: 1, shape: [4, 5])
  let z = x.unbroadcast(like: y)
  expectEqual(ShapedArray<Float>(repeating: 6, shape: [4, 5]),
              z.array)
}

TensorTests.testAllBackends("Unbroadcast2") {
  let x = Tensor<Float>(repeating: 1, shape: [2, 3, 4, 5])
  let y = Tensor<Float>(repeating: 1, shape: [3, 1, 5])
  let z = x.unbroadcast(like: y)
  expectEqual(ShapedArray<Float>(repeating: 8, shape: [3, 1, 5]),
              z.array)
}

// TODO: Merge all rank/shape getter tests into one when we support code motion
// to avoid sends.

@inline(never)
func testRankGetter() {
  let tensor = Tensor<Int32>(shape: [3, 4, 5], scalars: Array(0..<60))
  expectEqual(3, tensor.rank)
}
TensorTests.testAllBackends("RankGetter", testRankGetter)

@inline(never)
func testRankGetter2() {
  let vector = Tensor<Int32>([1])
  expectEqual(1, vector.rank)
}
TensorTests.testAllBackends("RankGetter2", testRankGetter2)

@inline(never)
func testRankGetter3() {
  let matrix = Tensor<Float>([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
  expectEqual(2, matrix.rank)
}
TensorTests.testAllBackends("RankGetter3", testRankGetter3)

@inline(never)
func testRankGetter4() {
  let ones = Tensor<Int32>(ones: [1, 2, 2, 2, 2, 2, 1])
  expectEqual(7, ones.rank)
}
TensorTests.testAllBackends("RankGetter4", testRankGetter4)

@inline(never)
func testShapeGetter() {
  let tensor = Tensor<Int32>(shape: [3, 4, 5], scalars: Array(0..<60))
  expectEqual([3, 4, 5], tensor.shape)
}
TensorTests.testAllBackends("ShapeGetter", testShapeGetter)

@inline(never)
func testShapeGetter2() {
  let vector = Tensor<Int32>([1])
  expectEqual([1], vector.shape)
}
TensorTests.testAllBackends("ShapeGetter2", testShapeGetter2)

@inline(never)
func testShapeGetter3() {
  let matrix = Tensor<Float>([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
  expectEqual([2, 3], matrix.shape)
}
TensorTests.testAllBackends("ShapeGetter3", testShapeGetter3)

@inline(never)
func testShapeGetter4() {
  let ones = Tensor<Int32>(ones: [1, 2, 2, 2, 2, 2, 1])
  expectEqual([1, 2, 2, 2, 2, 2, 1], ones.shape)
}
TensorTests.testAllBackends("ShapeGetter4", testShapeGetter4)

TensorTests.testAllBackends("replacing(with:where:) no broadcasting") {
  let original = Tensor<Float>([[1.0, 0.0], [3.0, 0.0], [2.0, 3.0], [1.0, 0.0]])
  let modified = original.replacing(
                with: Tensor<Float>(-1).broadcast(like: original), 
                where: original.<3)
  let expected = Tensor<Float>([[-1.0,-1.0],[3.0, -1.0], 
                                [-1.0, 3.0], [-1.0, -1.0]])
  expectEqual(expected, modified)
}

TensorTests.testAllBackends("replacing(with:where:) with broadcasting") {
  let original = Tensor<Float>([[1.0, 0.0], [3.0, 0.0], [2.0, 3.0], [1.0, 0.0]])
  let modified = original.replacing(with: Tensor<Float>(-1), where: original.<3)
  let expected = Tensor<Float>([[-1.0, -1.0], [3.0, -1.0], 
                                [-1.0, 3.0], [-1.0, -1.0]])
  expectEqual(expected, modified)
}

// For now it is sufficient to run remote tests with test cases in this file
// only. When creating new test files, consider simply calling runAllTests().
#if CUDA
// RemoteSession does not work for GPU because partitioning logic gets confused
// with multiple devices.
runAllTests()
#else
runAllTestsWithRemoteSession()
#endif  // CUDA
