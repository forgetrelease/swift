// RUN: not --crash %target-swift-emit-sil %s
// REQUIRES: asserts

// TF-923: Ownership verification error in pullback function generated by the
// differentiation transform.

struct Tensor<Scalar> {
  class Box {
    init() {}
  }
  var box: Box = Box()
}
extension Tensor: Equatable where Scalar: Equatable {
  static func ==(_: Self, _: Self) -> Bool { fatalError() }
}
extension Tensor: AdditiveArithmetic where Scalar: AdditiveArithmetic {
  static var zero: Self { fatalError() }
  static func +(_: Self, _: Self) -> Self { fatalError() }
  static func -(_: Self, _: Self) -> Self { fatalError() }
}
extension Tensor: Differentiable where Scalar: Differentiable & AdditiveArithmetic {
  typealias TangentVector = Self
}

struct Tuple<T: Differentiable & AdditiveArithmetic>: Differentiable {
  var first: Tensor<T>
  @noDerivative var second: Tensor<T>
}

@differentiable(wrt: (input))
func TF_923<T>(_ input: Tensor<T>, _ bool: Bool) -> Tuple<T> {
  let x = bool ? input : input
  return Tuple(first: x, second: x)
}

// Function: 'AD__$s4main6TF_923yAA5TupleVyxGAA6TensorVyxG_Sbts18AdditiveArithmeticRzs14DifferentiableRzlF__pullback_src_0_wrt_0'
// Found use after free due to unvisited non lifetime ending uses?!
// Value:   %22 = load [take] %10 : $*Tensor<τ_0_0>        // users: %88, %60, %47
//     Remaining Users:
// User:   %60 = copy_value %22 : $Tensor<τ_0_0>          // user: %65
// User:   %88 = copy_value %22 : $Tensor<τ_0_0>          // user: %93
