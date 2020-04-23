// RUN: %target-swift-frontend -emit-sil %s | %FileCheck %s

import _Differentiation

func foo<T: Numeric>(_ x: T, _ y: T) -> T { x * y }

@derivative(of: foo)
func foo_vjp<T: Numeric & Differentiable>(_ x: T, _ y: T) -> (
  value: T, pullback: (T.TangentVector) -> (T.TangentVector, T.TangentVector)
) {
  (foo(x, y), { _ in (.zero, .zero) })
}

@differentiable
func differentiate_foo_wrt_0(_ x: Float) -> Float {
  foo(x, 1)
}

// CHECK-LABEL: sil hidden @{{.*}}differentiate_foo_wrt_0{{.*}}__vjp_src_0_wrt_0 : $@convention(thin) (Float) -> (Float, @owned @callee_guaranteed (Float) -> Float) {
// CHECK: bb0
// CHECK:   [[FOO_ORIG:%.*]] = function_ref @{{.*}}foo{{.*}} : $@convention(thin) <τ_0_0 where τ_0_0 : Numeric> (@in_guaranteed τ_0_0, @in_guaranteed τ_0_0) -> @out τ_0_0
// CHECK:   [[FOO_FLOAT:%.*]] = partial_apply [callee_guaranteed] [[FOO_ORIG]]<Float>() : $@convention(thin) <τ_0_0 where τ_0_0 : Numeric> (@in_guaranteed τ_0_0, @in_guaranteed τ_0_0) -> @out τ_0_0
// CHECK:   [[FOO_JVP:%.*]] = differentiability_witness_function [jvp] [parameters 0 1] [results 0] <T where T : Numeric, T : Differentiable> @{{.*}}foo{{.*}} : $@convention(thin) <T where T : Numeric> (@in_guaranteed T, @in_guaranteed T) -> @out T
// CHECK:   [[FOO_JVP_FLOAT:%.*]] = partial_apply [callee_guaranteed] [[FOO_JVP]]<Float>() : $@convention(thin) <τ_0_0 where τ_0_0 : Numeric, τ_0_0 : Differentiable> (@in_guaranteed τ_0_0, @in_guaranteed τ_0_0) -> (@out τ_0_0, @owned @callee_guaranteed @substituted <τ_0_0, τ_0_1, τ_0_2> (@in_guaranteed τ_0_0, @in_guaranteed τ_0_1) -> @out τ_0_2 for <τ_0_0.TangentVector, τ_0_0.TangentVector, τ_0_0.TangentVector>)
// CHECK:   [[FOO_JVP_SUBSET_THUNK_THIN:%.*]] = function_ref @AD__orig_{{.*}}foo{{.*}}_src_0_wrt_0_jvp_subset_parameters_thunk : $@convention(thin) (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float)
// CHECK:   [[FOO_JVP_SUBSET_THUNK:%.*]] = thin_to_thick_function [[FOO_JVP_SUBSET_THUNK_THIN]] : $@convention(thin) (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float) to $@callee_guaranteed (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float)
// CHECK:   [[FOO_VJP:%.*]] = differentiability_witness_function [vjp] [parameters 0 1] [results 0] <T where T : Numeric, T : Differentiable> @{{.*}}foo{{.*}} : $@convention(thin) <T where T : Numeric> (@in_guaranteed T, @in_guaranteed T) -> @out T
// CHECK:   [[FOO_VJP_FLOAT:%.*]] = partial_apply [callee_guaranteed] [[FOO_VJP]]<Float>() : $@convention(thin) <τ_0_0 where τ_0_0 : Numeric, τ_0_0 : Differentiable> (@in_guaranteed τ_0_0, @in_guaranteed τ_0_0) -> (@out τ_0_0, @owned @callee_guaranteed @substituted <τ_0_0, τ_0_1, τ_0_2> (@in_guaranteed τ_0_0) -> (@out τ_0_1, @out τ_0_2) for <τ_0_0.TangentVector, τ_0_0.TangentVector, τ_0_0.TangentVector>)
// CHECK:   [[FOO_VJP_SUBSET_THUNK_THIN:%.*]] = function_ref @AD__orig_{{.*}}foo{{.*}}_src_0_wrt_0_vjp_subset_parameters_thunk : $@convention(thin) (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float)
// CHECK:   [[FOO_VJP_SUBSET_THUNK:%.*]] = thin_to_thick_function [[FOO_VJP_SUBSET_THUNK_THIN]] : $@convention(thin) (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float) to $@callee_guaranteed (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float)
// CHECK:   [[FOO_DIFF:%.*]] = differentiable_function [parameters 0] [[FOO_FLOAT]] : $@callee_guaranteed (@in_guaranteed Float, @in_guaranteed Float) -> @out Float with_derivative {[[FOO_JVP_SUBSET_THUNK]] : $@callee_guaranteed (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float), [[FOO_VJP_SUBSET_THUNK]] : $@callee_guaranteed (@in_guaranteed Float, @in_guaranteed Float) -> (@out Float, @owned @callee_guaranteed (@in_guaranteed Float) -> @out Float)}
// CHECK: }

func inoutIndirect<T: Differentiable, U: Differentiable, V: Differentiable>(
  _ x: T, _ y: inout U, _ z: V
) {}

@derivative(of: inoutIndirect)
func vjpInoutIndirect<T: Differentiable, U: Differentiable, V: Differentiable>(
  _ x: T, _ y: inout U, _ z: V
) -> (
  value: Void, pullback: (inout U.TangentVector) -> (T.TangentVector, V.TangentVector)
) {
  return ((), { dy in
    return (.zero, .zero)
  })
}

@differentiable(wrt: x)
@differentiable(wrt: y)
@differentiable
func inoutIndirectCaller<T: Differentiable, U: Differentiable, V: Differentiable>(
  _ x: T, _ y: U, _ z: V
) -> U {
  var result = y
  inoutIndirect(x, &result, z)
  return result
}

@differentiable(wrt: (x, z))
func concreteInoutIndirectCaller(
  _ x: Float, _ y: Double, _ z: Float
) -> Double {
  return inoutIndirectCaller(x, y, z)
}

// CHECK-LABEL: sil shared [transparent] [serialized] [thunk] @AD__$sSdSfSdSfIegnrrr_SdS2fIegnrr_TR_src_0_wrt_0_2_pullback_index_subset_thunk : $@convention(thin) (@in_guaranteed Double, @guaranteed @callee_guaranteed (@in_guaranteed Double) -> (@out Float, @out Double, @out Float)) -> (@out Float, @out Float) {
// CHECK: bb0(%0 : $*Float, %1 : $*Float, %2 : $*Double, %3 : $@callee_guaranteed (@in_guaranteed Double) -> (@out Float, @out Double, @out Float)):
// CHECK:   %4 = alloc_stack $Double
// CHECK:   %5 = apply %3(%0, %4, %1, %2) : $@callee_guaranteed (@in_guaranteed Double) -> (@out Float, @out Double, @out Float)
// CHECK:   destroy_addr %4 : $*Double
// CHECK:   dealloc_stack %4 : $*Double
// CHECK:   %8 = tuple ()
// CHECK:   return %8 : $()
// CHECK: }

// CHECK-LABEL: sil shared [transparent] [serialized] [thunk] @AD__$s13TangentVector16_Differentiation14DifferentiablePQy_AaDQzAaDQy0_Ieglrr_AeFIeglr_AbCRzAbCR_AbCR0_r1_lTR_src_0_wrt_0_1_pullback_index_subset_thunk : $@convention(thin) <τ_0_0, τ_0_1, τ_0_2 where τ_0_0 : Differentiable, τ_0_1 : Differentiable, τ_0_2 : Differentiable> (@inout τ_0_1.TangentVector, @guaranteed @callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)) -> @out τ_0_0.TangentVector {
// CHECK: bb0(%0 : $*τ_0_0.TangentVector, %1 : $*τ_0_1.TangentVector, %2 : $@callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)):
// CHECK:   %3 = alloc_stack $τ_0_2.TangentVector
// CHECK:   %4 = apply %2(%0, %3, %1) : $@callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)
// CHECK:   destroy_addr %3 : $*τ_0_2.TangentVector
// CHECK:   dealloc_stack %3 : $*τ_0_2.TangentVector
// CHECK:   %7 = tuple ()
// CHECK:   return %7 : $()
// CHECK: }

// CHECK-LABEL: sil shared [transparent] [serialized] [thunk] @AD__$s13TangentVector16_Differentiation14DifferentiablePQy_AaDQzAaDQy0_Ieglrr_AEIegl_AbCRzAbCR_AbCR0_r1_lTR_src_0_wrt_1_pullback_index_subset_thunk : $@convention(thin) <τ_0_0, τ_0_1, τ_0_2 where τ_0_0 : Differentiable, τ_0_1 : Differentiable, τ_0_2 : Differentiable> (@inout τ_0_1.TangentVector, @guaranteed @callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)) -> () {
// CHECK: bb0(%0 : $*τ_0_1.TangentVector, %1 : $@callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)):
// CHECK:   %2 = alloc_stack $τ_0_0.TangentVector
// CHECK:   %3 = alloc_stack $τ_0_2.TangentVector
// CHECK:   %4 = apply %1(%2, %3, %0) : $@callee_guaranteed (@inout τ_0_1.TangentVector) -> (@out τ_0_0.TangentVector, @out τ_0_2.TangentVector)
// CHECK:   destroy_addr %2 : $*τ_0_0.TangentVector
// CHECK:   destroy_addr %3 : $*τ_0_2.TangentVector
// CHECK:   dealloc_stack %3 : $*τ_0_2.TangentVector
// CHECK:   dealloc_stack %2 : $*τ_0_0.TangentVector
// CHECK:   %9 = tuple ()
// CHECK:   return %9 : $()
// CHECK: }
