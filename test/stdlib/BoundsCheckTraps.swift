// RUN: %empty-directory(%t)
// RUN: %target-build-swift %s -o %t/a.out_Debug -Onone
// RUN: %target-build-swift %s -o %t/a.out_Release -O
// RUN: %target-build-swift %s -o %t/a.out_ReleaseWithBoundsSafety -O -enable-experimental-feature UnsafePointerBoundsSafety
// RUN: %target-codesign %t/a.out_Debug
// RUN: %target-codesign %t/a.out_Release
// RUN: %target-codesign %t/a.out_ReleaseWithBoundsSafety
//
// RUN: %target-run %t/a.out_Debug
// RUN: %target-run %t/a.out_Release
// RUN: %target-run %t/a.out_ReleaseWithBoundsSafety
// REQUIRES: executable_test
// REQUIRES: asserts
// UNSUPPORTED: OS=wasi

import StdlibUnittest

let testSuiteSuffix = _isDebugAssertConfiguration() ? "_debug"
  : _isReleaseAssertConfiguration() ? "_release" : "_releaseWithBoundsSafety"

var BoundsCheckTraps = TestSuite("BoundsCheckTraps" + testSuiteSuffix)

BoundsCheckTraps.test("UnsafeMutableBufferPointer")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array = [1, 2, 3]
  array.withUnsafeBufferPointer { buffer in
    print(buffer[3])
  }
  array.withUnsafeMutableBufferPointer { buffer in
    buffer[3] = 17
  }
  _blackHole(array)
}

BoundsCheckTraps.test("UnsafeMutableBufferPointerIndexes")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array = [1, 2, 3]
  array.withUnsafeBufferPointer { buffer in
    let i = buffer.index(after: Int.max)
    _blackHole(i)
  }
  _blackHole(array)
}

BoundsCheckTraps.test("UnsafeRawBufferPointer")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array = [1, 2, 3]
  array.withUnsafeBufferPointer { buffer in
    print(UnsafeRawBufferPointer(buffer).load(fromByteOffset: MemoryLayout<Int>.stride * 3, as: Int.self))
  }
  array.withUnsafeMutableBufferPointer { buffer in
    UnsafeMutableRawBufferPointer(buffer).storeBytes(of: 17, toByteOffset: MemoryLayout<Int>.stride * 3, as: Int.self)
  }
  _blackHole(array)
}

BoundsCheckTraps.test("EmptyCollection")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var empty = EmptyCollection<Int>()
  print(empty[0])
  _blackHole(empty)
}

BoundsCheckTraps.test("Character")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  let twoChars = "ab"
  let char = Character(twoChars)
  _blackHole(char)
}

BoundsCheckTraps.test("ArrayUnchecked")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() || _isReleaseAssertWithBoundsSafetyConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array = [1, 2]
  array.append(3)
  let value = array[unchecked: 3]
  _blackHole(value)
}

BoundsCheckTraps.test("ArrayUncheckedBounds")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() || _isReleaseAssertWithBoundsSafetyConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array = [1, 2]
  array.append(3)
  let value = array[uncheckedBounds: 3..<4]
  _blackHole(value)
}

BoundsCheckTraps.test("ContiguousArrayUnchecked")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() || _isReleaseAssertWithBoundsSafetyConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array: ContiguousArray = [1, 2]
  array.append(3)
  let value = array[unchecked: 3]
  _blackHole(value)
}

BoundsCheckTraps.test("ContiguousArrayUncheckedBounds")
  .skip(.custom(
    { _isFastAssertConfiguration() || _isReleaseAssertConfiguration() || _isReleaseAssertWithBoundsSafetyConfiguration() },
    reason: "this trap is not guaranteed to happen"))
  .code {
  expectCrashLater()
  var array: ContiguousArray = [1, 2]
  array.append(3)
  let value = array[uncheckedBounds: 3..<4]
  _blackHole(value)
}

@available(SwiftStdlib 5.11, *)
extension Collection where Index == Int {
  func uncheckedReverse(upTo endIndex: Int) -> [Element] {
    var result: [Element] = []
    for i in (0..<endIndex).reversed() {
      result.append(self[unchecked: i])
    }
    return result
  }
}

BoundsCheckTraps.test("CollectionUnchecked")
  .skip(.custom(
    { _isDebugAssertConfiguration() },
    reason: "this will trap in debug builds"))
  .code {
  if #available(SwiftStdlib 5.11, *) {
    var array = [1, 2, 3]
    let reversed = array.withUnsafeBufferPointer { outerBuffer in
      // Artificially shrink the unsafe buffer so that the "reverse" operation
      // below will require out-of-bounds access. This ensures that [unchecked:]
      // is actually not checking.
      let innerBuffer = UnsafeBufferPointer<Int>(start: outerBuffer.baseAddress, count: 2)
      return innerBuffer.uncheckedReverse(upTo: 3)
    }
    if reversed != [3, 2, 1] {
      fatalError("uncheckedReversed() failed?")
    }
    _blackHole(array)
  }
}

runAllTests()
