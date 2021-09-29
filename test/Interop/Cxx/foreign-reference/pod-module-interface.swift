// RUN: %target-swift-ide-test -print-module -module-to-print=POD -I %S/Inputs -source-filename=x -enable-cxx-interop | %FileCheck %s

// CHECK-NOT: init
// CHECK: class Empty {
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> Empty
// CHECK: }
// CHECK: func mutateIt(_: Empty)
// CHECK-NOT: func passThroughByValue(_ x: Empty) -> Empty

// CHECK: class MultipleAttrs {
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> MultipleAttrs
// CHECK: }

// CHECK: class IntPair {
// CHECK:   var a: Int32
// CHECK:   var b: Int32
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> IntPair
// CHECK: }
// CHECK: func mutateIt(_ x: IntPair)
// CHECK-NOT: func passThroughByValue(_ x: IntPair) -> IntPair

// CHECK: class RefHoldingPair {
// CHECK-NOT: pair
// CHECK:   var otherValue: Int32
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> RefHoldingPair
// CHECK: }

// CHECK: class RefHoldingPairRef {
// CHECK:   var pair: IntPair
// CHECK:   var otherValue: Int32
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> RefHoldingPairRef
// CHECK: }

// CHECK: class RefHoldingPairPtr {
// CHECK:   var pair: IntPair
// CHECK:   var otherValue: Int32
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> RefHoldingPairPtr
// CHECK: }

// CHECK: struct ValueHoldingPair {
// CHECK-NOT: pair
// CHECK:   init()
// CHECK:   var otherValue: Int32
// CHECK:   func test() -> Int32
// CHECK:   mutating func testMutable() -> Int32
// CHECK:   static func create() -> UnsafeMutablePointer<ValueHoldingPair>
// CHECK: }

// CHECK: class BigType {
// CHECK:   var a: Int32
// CHECK:   var b: Int32
// CHECK:   var buffer:
// CHECK:   func test() -> Int32
// CHECK:   func testMutable() -> Int32
// CHECK:   class func create() -> BigType
// CHECK: }
// CHECK: func mutateIt(_ x: BigType)
// CHECK-NOT: func passThroughByValue(_ x: BigType) -> BigType
