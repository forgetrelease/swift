// RUN: %target-swift-ide-test -print-module -module-to-print=AnonymousWithSwiftName -I %S/Inputs -source-filename=x -enable-experimental-cxx-interop | %FileCheck %s
//
// REQUIRES: objc_interop

// CHECK: class ColorMaker {
// CHECK:   class func makeColor(withOptions opts: SOColorMask)
// CHECK:   func makeColor(withOptions opts: SOColorMask)
// CHECK:   @available(swift, obsoleted: 3, renamed: "makeColor(withOptions:)")
// CHECK:   class func makeColorWithOptions(_ opts: SOColorMask)
// CHECK:   @available(swift, obsoleted: 3, renamed: "makeColor(withOptions:)")
// CHECK:   func makeColorWithOptions(_ opts: SOColorMask)
// CHECK:   class func makeOtherColor(with x: Int32, withOptions opts: CFColorMask)
// CHECK:   func makeOtherColor(with x: Int32, withOptions opts: CFColorMask)
// CHECK:   @available(swift, obsoleted: 3, renamed: "makeOtherColor(with:withOptions:)")
// CHECK:   class func makeOtherColorWithInt(_ x: Int32, withOptions opts: CFColorMask)
// CHECK:   @available(swift, obsoleted: 3, renamed: "makeOtherColor(with:withOptions:)")
// CHECK:   func makeOtherColorWithInt(_ x: Int32, withOptions opts: CFColorMask)
// CHECK: }
