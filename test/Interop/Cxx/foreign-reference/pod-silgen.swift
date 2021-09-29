// RUN: %target-swift-emit-silgen %s -I %S/Inputs -enable-cxx-interop | %FileCheck %s

import POD

// CHECK-NOT: borrow
// CHECK-NOT: retain
// CHECK-NOT: release
// CHECK-LABEL: sil [ossa] @$s4main4testyyF : $@convention(thin) () -> ()

// CHECK: [[BOX:%.*]] = project_box {{.*}} : ${ var IntPair }, 0

// CHECK: [[CREATE_FN:%.*]] = function_ref @_ZN7IntPair6createEv : $@convention(c) () -> IntPair
// CHECK: [[CREATED_PTR:%.*]] = apply [[CREATE_FN]]() : $@convention(c) () -> IntPair
// CHECK: store [[CREATED_PTR]] to [trivial] [[BOX]] : $*IntPair
// CHECK: [[ACCESS_1:%.*]] = begin_access [read] [unknown] [[BOX]] : $*IntPair
// CHECK: [[X_1:%.*]] = load [trivial] [[ACCESS_1]] : $*IntPair

// CHECK: [[TMP:%.*]] = alloc_stack $IntPair
// CHECK: store [[X_1]] to [trivial] [[TMP]]
// CHECK: [[TEST_FN:%.*]] = function_ref @_ZNK7IntPair4testEv : $@convention(c) (@in_guaranteed IntPair) -> Int32
// CHECK: apply [[TEST_FN]]([[TMP]]) : $@convention(c) (@in_guaranteed IntPair) -> Int32

// CHECK: return
// CHECK-LABEL: end sil function '$s4main4testyyF'
public func test() {
  var x = IntPair.create()
  _ = x.test()
}

// CHECK-LABEL: sil [clang IntPair.create] @_ZN7IntPair6createEv : $@convention(c) () -> IntPair

// CHECK-LABEL: sil [clang IntPair.test] @_ZNK7IntPair4testEv : $@convention(c) (@in_guaranteed IntPair) -> Int32
