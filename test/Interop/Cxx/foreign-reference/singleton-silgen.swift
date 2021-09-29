// RUN: %target-swift-emit-silgen %s -I %S/Inputs -enable-cxx-interop | %FileCheck %s

import Singleton

// CHECK-NOT: borrow
// CHECK-NOT: retain
// CHECK-NOT: release
// CHECK-LABEL: sil [ossa] @$s4main4testyyF : $@convention(thin) () -> ()

// CHECK: [[BOX:%.*]] = project_box {{.*}} : ${ var DeletedSpecialMembers }, 0

// CHECK: [[CREATE_FN:%.*]] = function_ref @_ZN21DeletedSpecialMembers6createEv : $@convention(c) () -> DeletedSpecialMembers
// CHECK: [[CREATED_PTR:%.*]] = apply [[CREATE_FN]]() : $@convention(c) () -> DeletedSpecialMembers
// CHECK: store [[CREATED_PTR]] to [trivial] [[BOX]] : $*DeletedSpecialMembers
// CHECK: [[ACCESS_1:%.*]] = begin_access [read] [unknown] [[BOX]] : $*DeletedSpecialMembers
// CHECK: [[X_1:%.*]] = load [trivial] [[ACCESS_1]] : $*DeletedSpecialMembers

// CHECK: [[TMP:%.*]] = alloc_stack $DeletedSpecialMembers
// CHECK: store [[X_1]] to [trivial] [[TMP]]

// CHECK: [[TEST_FN:%.*]] = function_ref @_ZNK21DeletedSpecialMembers4testEv : $@convention(c) (@in_guaranteed DeletedSpecialMembers) -> Int32
// CHECK: apply [[TEST_FN]]([[TMP]]) : $@convention(c) (@in_guaranteed DeletedSpecialMembers) -> Int32
// CHECK: [[ACCESS_2:%.*]] = begin_access [read] [unknown] [[BOX]] : $*DeletedSpecialMembers
// CHECK: [[X_2:%.*]] = load [trivial] [[ACCESS_2]] : $*DeletedSpecialMembers

// CHECK: [[MOVE_IN_RES_FN:%.*]] = function_ref @_Z8mutateItR21DeletedSpecialMembers : $@convention(c) (DeletedSpecialMembers) -> ()
// CHECK: apply [[MOVE_IN_RES_FN]]([[X_2]]) : $@convention(c) (DeletedSpecialMembers) -> ()

// CHECK: return
// CHECK-LABEL: end sil function '$s4main4testyyF'
public func test() {
  var x = DeletedSpecialMembers.create()
  _ = x.test()
  mutateIt(x)
}

// CHECK-LABEL: sil [clang DeletedSpecialMembers.create] @_ZN21DeletedSpecialMembers6createEv : $@convention(c) () -> DeletedSpecialMembers

// CHECK-LABEL: sil [clang DeletedSpecialMembers.test] @_ZNK21DeletedSpecialMembers4testEv : $@convention(c) (@in_guaranteed DeletedSpecialMembers) -> Int32

// CHECK-LABEL: sil [serializable] [clang mutateIt] @_Z8mutateItR21DeletedSpecialMembers : $@convention(c) (DeletedSpecialMembers) -> ()
