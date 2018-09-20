// RUN: %target-swift-frontend -Xllvm -tf-dump-intermediates -O -emit-sil -verify %s | %FileCheck %s

import TensorFlow

// This test is intended to verify that all of the operations end up in the
// graph: that there are no host/accelerator copies generated.  This tests a
// combination of the partitioning pass being able to recognize various forms,
// but also checks that certain ops implementations are promotable as well.

// Please keep it so no errors or warnings are generated by functions in this
// file.

public func testSelect(conds1: Tensor<Bool>, x1: Tensor<Float>, y1: Tensor<Float>)
  -> Tensor<Float> {
  let conds = conds1.toAccelerator()
  let x = x1.toAccelerator()
  let y = y1.toAccelerator()

  let result = conds.selecting(x+x, y)*y

  return result.toHost()
}
/*
 CHECK-LABEL: --- TFPartition Accelerator Result: {{.*}}testSelect
 CHECK: sil private @{{.*}}testSelect{{.*}} : $@callee_owned (TensorHandle<Float>, TensorHandle<Bool>, TensorHandle<Float>) -> TensorHandle<Float> {
 CHECK: bb0(%0 : @unowned $TensorHandle<Float>, %1 : @unowned $TensorHandle<Bool>, %2 : @unowned $TensorHandle<Float>):
 CHECK:       [[A:%.*]] = graph_op "Add"(%0 : $TensorHandle<Float>, %0 : $TensorHandle<Float>
 CHECK:       [[B:%.*]] = graph_op "Select"(%1 : $TensorHandle<Bool>, [[A]] : $TensorHandle<Float>, %2 : $TensorHandle<Float>
 CHECK:      [[C:%.*]] = graph_op "Mul"([[B]] : $TensorHandle<Float>, %2 : $TensorHandle<Float>
 CHECK-NEXT:  return [[C]] : $TensorHandle<Float>
 CHECK-NEXT:}
*/

public func testEmptyScalarsArray() {
  let y = Tensor<Int32>(shape: [0, 20, 30], scalars: [])
  _ = y+y
}
/*
 CHECK-LABEL: --- TFPartition Accelerator Result: {{.*}}testEmptyScalarsArray
 CHECK: sil private @{{.*}}testEmptyScalarsArray{{.*}} : $@callee_owned () -> () {
 CHECK: bb0:
 CHECK: graph_op "Const"() {dtype: $Int32, value$tensor: [$Int32: ], shape$shape: [$Int32: (i32 0), (i32 20), (i32 30)],
 CHECK: graph_op "Add"({{.*}} : $TensorHandle<Int32>, {{.*}} : $TensorHandle<Int32>
 */

// This tests the attributes necessary to get arrays of integers and strings going.
public func testConvolution(x: Tensor<Float>, filter: Tensor<Float>) -> Tensor<Float> {
  return x.toAccelerator().convolved2D(withFilter: filter.toAccelerator(),
                       strides: (1, 2, 3, 4), padding: .same)
}

// CHECK-LABEL: --- TFPartition Accelerator Result: {{.*}}testConvolution
// CHECK: sil private @{{.*}}testConvolution{{.*}} : $@callee_owned (TensorHandle<Float>, TensorHandle<Float>) -> TensorHandle<Float> {
// CHECK: bb0(%0 : @unowned $TensorHandle<Float>, %1 : @unowned $TensorHandle<Float>):
// CHECK: [[A:%.*]] = graph_op "Conv2D"(%0 : $TensorHandle<Float>, %1 : $TensorHandle<Float>) {T: $Float, strides: [$Int32: (i32 1), (i32 2), (i32 3), (i32 4)], use_cudnn_on_gpu: i1 -1, padding: "SAME", data_format: "NHWC", dilations: [$Int32: (i32 1), (i32 1), (i32 1), (i32 1)], __device: "/device:CPU:0"} : $TensorHandle<Float>
// CHECK-NEXT:  return [[A]] : $TensorHandle<Float>
// CHECK-NEXT:}

// Testcase for an op that uses the $tensor and $shape modifiers.
public func testConstantArray() -> TensorHandle<Float> {
  return #tfop("Const", dtype: Float.self, value$tensor: [1.0, 2.0], shape$shape: [2])
}

// CHECK-LABEL: --- TFPartition Accelerator Result: {{.*}}testConstantArray
// CHECK: sil private @{{.*}}testConstantArray{{.*}} : $@callee_owned () -> TensorHandle<Float> {
// CHECK: bb0:
// CHECK:  %0 = graph_op "Const"() {dtype: $Float, value$tensor: [$Double: (f64 0x3FF0000000000000 /* 1 */), (f64 0x4000000000000000 /* 2 */)], shape$shape: [$Int: (i64 2)], __device: "/device:CPU:0"} : $TensorHandle<Float>
// CHECK-NEXT:  return %0 : $TensorHandle<Float>

// Testcase for an op that uses the $shape modifier.
public func tensorShapeModifier() {
  let _ : TensorHandle<Float> = #tfop("ImmutableConst",
                                      dtype: Float.self,
                                      shape$shape: [2, 2],
                                      memory_region_name: "abc")
}

// Sigmoid shouldn't cause copies.  This should compile with no copy warnings/errors.
public func testSigmoid(x: Tensor<Float>, y: Tensor<Float>) -> (Tensor<Float>, Tensor<Float>) {
  let a = sigmoid(x.toAccelerator())
  let b = sigmoid(y.toAccelerator()).toHost()
  // FIXME: b/76177896 the toHost() call should be movable up.
  return (a.toHost(), b)
}

// Likewise, mean and max shouldn't cause send/receive errors.
public func testMeanMax(x: Tensor<Float>) -> Float {
  let y = x.toAccelerator()
  let a = y.mean()
  let b = y.max()
  return a+b
}

public func testZeros() -> Tensor<Float> {
  let b1 = Tensor<Float>(zeros: [1, 4])
  let b2 = Tensor<Float>(zeros: [1, 4])
  return (b1+b2).toHost()
}

// Verify that we are able to run randomUniform on the accelerator, or at least hoist
// it to being an argument so we don't get copy-ins.
public func randomUniformHoisting() -> Tensor<Float> {
  let x = Tensor<Float>(ones: [2, 2, 2])
  let y = Tensor<Float>(randomUniform: [2, 2, 2])
  let z = Tensor<Float>(randomUniform: [2, 2, 2])

  return (x+y+z).toHost()
}

// Here ".mean()" contains a tensor2scalar operation, and we then convert that
// scalar back to a tensor.  This checks to make sure that tf-partition can pull
// this whole mess in graph without leaving anything on the host that will cause
// a send/receive.
public func tensorToScalarToTensor(a: Tensor<Int32>) -> Tensor<Int32> {
  let scalar = a.toAccelerator().mean()
  let b = Tensor(scalar)
  return (b+b).toHost()
}


// The tensor value inside the loop was getting copied back to the host because of
// the use by a branch instruction.  b/75494462
public func test75494462() {
  var x = Tensor<Float>(1)
  var i: Int32 = 1
  repeat {
    x += 1
    i += 1
  } while i < 5
  _hostOp(x.array)
}

public func paddingTuplesHoistable() {
  let matrix: Tensor<Float> = Tensor([[1, 2, 3], [4, 5, 6]]) + 1
  let padded = matrix.padded(forSizes: [(before: 1, after: 1), (before: 2, after: 2)]).toAccelerator()
  _ = padded.array
}

// b/76184126
public func rangeLiteral() -> Tensor<Float> {
  var x = Tensor<Float>(33)
  for _ in 1...10 {
    x += 1
  }
  return x.toHost()
}

/// b/76222306
struct Classifier {
  // Parameters
  var w1 = Tensor<Float>(randomUniform: [784, 30])
  var w2 = Tensor<Float>(randomUniform: [30, 10])
  var b1 = Tensor<Float>(zeros: [1, 30])
  var b2 = Tensor<Float>(zeros: [1, 10])

  func prediction(for input: Tensor<Float>) -> Tensor<Float> {
    let h1 = sigmoid(input • w1 + b1)
    return sigmoid(h1 • w2 + b2)
  }

  mutating func train(images: Tensor<Float>, labels: Tensor<Float>,
                      learningRate: Float, epochCount: Int) -> Float {
    var loss: Float
    var epochCount = epochCount
    repeat {
      // Forward pass
      let z1 = images • w1 + b1
      let h1 = sigmoid(z1)
      let z2 = h1 • w2 + b2
      let pred = sigmoid(z2)

      // Backward pass
      let dz2 = pred - labels
      let dw2 = h1.transposed(withPermutations: 1, 0) • dz2
      let db2 = dz2.sum(squeezingAxes: 0)
      let dz1 = matmul(dz2, w2.transposed(withPermutations: 1, 0)) * h1 * (1 - h1)
      let dw1 = images.transposed(withPermutations: 1, 0) • dz1
      let db1 = dz1.sum(squeezingAxes: 0)

      // Gradient descent
      w1 -= dw1 * learningRate
      b1 -= db1 * learningRate
      w2 -= dw2 * learningRate
      b2 -= db2 * learningRate

      loss = dz2.squared().mean(squeezingAxes: 1, 0).scalarized()

      epochCount -= 1
    } while epochCount > 0

    return loss
  }
}

public func mnist() {
  // Training data
  let images = Tensor<Float>(randomNormal: [10, 784])
  let labels = Tensor<Float>(randomNormal: [10, 10])
  var classifier = Classifier()
  let loss = classifier.train(images: images, labels: labels,
                              learningRate: 0.3, epochCount: 100)
  _hostOp(loss)
}

// A TF op that produces multiple outputs.
public func testMultiOutputs() {
  let d = Tensor<Float>(0.0)
  // FIXME: Support promoting scalar false to a Tensor<Bool>
  let c = Tensor<Bool>(false)
  let (x1, y1): (TensorHandle<Float>, TensorHandle<Float>) = #tfop("Switch", d, c)
  // FIXME: Remove the uses of Identity nodes here.
  let x: TensorHandle<Float> = #tfop("Identity", x1)
  let y: TensorHandle<Float> = #tfop("Identity", y1)
  _hostOp(x)
  _hostOp(y)
}

// TODO: Eliminate the sends/recvs when -Onone is enabled.
public func SR8395() {
  let x: Tensor<Float> = [[1, 2], [3, 4]]
  _hostOp(matmul(x, x) + x)
}

// Tuples should be deabstracted away.
public func noTupleExtractOverTensorValues() {
  let (a, _) = (Tensor<Float>(1.0), Tensor<Float>(2.0))
  let c = a + 5
  let d = (Tensor<Float>(3.0), Tensor<Float>(4.0))
  let e = c + d.1
  _hostOp(e)
}

// Non-top-level array element
public func SR8399() {
  let x = Tensor<Float>(ones: [2, 2])
  let y = x.reshaped(toShape: Tensor<Int32>([4, Int32(1)]))
  let z = x.reshaped(toShape: Tensor<Int32>([Int32(4), 1]))
  _hostOp(y)
  _hostOp(z)
}

public func SR8399_2() {
  let x = Tensor<Float>(ones: [2, 2])
  let y = x.reshaped(toShape: Tensor<Int32>([4, Int32(1 * 1)]))
  _hostOp(y)
}

public func SR8413() {
  let x = Tensor<Float>(ones: [17, 17, 17, 17])
  let _ = x.maxPooled(
    kernelSize: (64, 65, 66, 67), strides: (64, 65, 66, 67), padding: .same
  )
}


@inlinable @inline(__always)
func createStringTensorConst(_ str: String) -> TensorHandle<String> {
  // Const tfops with String cannot be placed on GPU/TPU. 
  // TODO: Find a better API to write string consts.
  return #tfop("Const",
               dtype: String.self,
               value$tensor: str,
               __device: "/device:CPU:0")
}

// Consider moving this test to a different test suite, if we add more tests
// related to summaries.
public func testScalarSummaryStraightline() {
  TensorFlow.enableGPU()
  let summaryWriter: ResourceHandle = #tfop("SummaryWriter",
                                            container: "",
                                            shared_name: "some_writer")
  let logdir = createStringTensorConst("logdir_s4tf")
  let maxQueueLen = Tensor<Int32>(0)
  let flushMs = Tensor<Int32>(120000)
  let filenameSuffix = createStringTensorConst(".v2")
  #tfop("CreateSummaryFileWriter", summaryWriter, logdir, maxQueueLen,
                         flushMs, filenameSuffix) as Void
  let familyName = createStringTensorConst("scalar")
  // The x-axis value.
  let step1 = Tensor<Int64>(0)
  // Scalar is the y-axis value.
  let scalar = Tensor<Int64>(2)
  #tfop("WriteScalarSummary", summaryWriter, step1, familyName, scalar) as Void
  let step2 = Tensor<Int64>(10)
  #tfop("WriteScalarSummary", summaryWriter, step2, familyName, scalar + 3) as Void
}

public func testScalarSummaryInALoop(n: Int64) {
  TensorFlow.enableGPU()
  let summaryWriter: ResourceHandle = #tfop("SummaryWriter",
                                            container: "",
                                            shared_name: "some_writer")
  let logdir = createStringTensorConst("logdir_s4tf")
  let maxQueueLen = Tensor<Int32>(0)
  let flushMs = Tensor<Int32>(120000)
  let filenameSuffix = createStringTensorConst(".v2")
  #tfop("CreateSummaryFileWriter", summaryWriter, logdir, maxQueueLen,
                         flushMs, filenameSuffix) as Void
  let familyName = createStringTensorConst("scalar")
  // The x-axis value.
  var i: Int64 = 0
  // The y-axis value.
  let initialVal = Tensor<Int64>(2)
  while i < n {
    let step1 = Tensor<Int64>(i)
    #tfop("WriteScalarSummary", summaryWriter, step1, familyName, initialVal + i) as Void
    i += 1
  }
}
