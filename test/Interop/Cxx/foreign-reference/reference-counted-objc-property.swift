// RUN: %target-swift-emit-irgen %s -I %S/Inputs -cxx-interoperability-mode=default -Xcc -fno-exceptions -Xcc -fno-objc-exceptions | %FileCheck %s

// REQUIRES: objc_interop

import ReferenceCountedObjCProperty

// CHECK: define swiftcc void @"$s4main10testGetteryyF"()
// CHECK: alloca ptr, align 8
// CHECK: %[[LC:.*]] = alloca ptr, align 8
// CHECK: %[[V4:.*]] = load ptr, ptr @"\01L_selector(lc)", align 8
// CHECK: %[[V5:.*]] = call ptr @objc_msgSend(ptr %{{.*}}, ptr %[[V4]])
// CHECK: %[[V6:.*]] = icmp ne ptr %[[V5]], null
// CHECK: br i1 %[[V6]], label %[[LIFETIME_NONNULL_VALUE:.*]], label %[[LIFETIME_CONT:.*]]

// CHECK: [[LIFETIME_NONNULL_VALUE]]:
// CHECK-NEXT: call void @_Z8LCRetainPN2NS10LocalCountE(ptr %[[V5]])
// CHECK-NEXT: br label %[[LIFETIME_CONT]]

// CHECK: [[LIFETIME_CONT]]:
// CHECK: store ptr %[[V5]], ptr %[[LC]], align 8
// CHECK: %[[TODESTROY:.*]] = load ptr, ptr %[[LC]], align 8
// CHECK: call void @_Z9LCReleasePN2NS10LocalCountE(ptr %[[TODESTROY]])

public func testGetter() {
  var c0 = C0()
  var lc = c0.lc
}
