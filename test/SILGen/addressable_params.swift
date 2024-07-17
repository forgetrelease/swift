// RUN: %target-swift-emit-silgen %s | %FileCheck %s

// CHECK-LABEL: sil {{.*}}@$s{{.*}}6withUP{{.*}} : $@convention(thin) <T> (@in_guaranteed T, @guaranteed @noescape @callee_guaranteed @substituted <τ_0_0> (UnsafePointer<τ_0_0>) -> () for <T>) -> ()
func withUP<T>(to: borrowing @_addressable T, _ body: (UnsafePointer<T>) -> Void) -> Void {}

// Forwarding an addressable parameter binding as an argument to another
// addressable parameter with matching ownership forwards the address without
// copying or moving the value.
// CHECK-LABEL: sil {{.*}}@$s{{.*}}4test{{.*}} : $@convention(thin) (@in_guaranteed String) -> ()
func test(x: borrowing @_addressable String) {
    // CHECK: [[MO:%.*]] = copyable_to_moveonlywrapper_addr %0
    // CHECK: [[MOR:%.*]] = mark_unresolved_non_copyable_value [no_consume_or_assign] [[MO]]
    // CHECK: [[MORC:%.*]] = moveonlywrapper_to_copyable_addr [[MOR]]
    // CHECK: apply {{.*}}([[MORC]],
    withUP(to: x) {
        _ = $0
    }
}
