// RUN: %target-swift-frontend -typecheck -verify %s

@differentiable(reverse, adjoint: dfoo) // expected-error {{@differentiable may only be used on 'func' declarations}}
let x: Float = 1

@differentiable(reverse, adjoint: dfoo) // expected-error {{@differentiable may only be used on 'func' declarations}}
protocol P {}

func dfoo(_ seed: Float, _ primal: Float, _ x: Float) -> Float {
  return 2 * x
}

@differentiable(reverse, adjoint: dfoo) // ok!
func foo(_ x: Float) -> Float {
  return x * x
}

@differentiable(reverse) // ok!
func no_prim_or_adj(_ x: Float) -> Float {
  return x * x
}

@differentiable(reverse, primal: dfoo) // expected-error {{a corresponding adjoint must be specified when the primal is provided}}
func prim_but_no_adj(_ x: Float) -> Float {
  return x * x
}

// Original function must return non-Void type.
@differentiable(reverse, adjoint: dvoid) // expected-error {{cannot differentiate void function 'void'}}
func void(_ a: Float) {}
func dvoid(_ x: (), _ y: (), _ a: Float) -> Float { return 1 }

// Primal returns custom checkpoints type.
struct CheckpointsFoo {}
func pfoo(_ x: Float) -> (checkpoints: CheckpointsFoo, originalValue: Float) {
  return (CheckpointsFoo(), x * x)
}
func dfoo_checkpointed(_ seed: Float, _ checkpoints: CheckpointsFoo, _ originalValue: Float, _ x: Float) -> Float {
  return 2 * x
}
@differentiable(reverse, primal: pfoo, adjoint: dfoo_checkpointed) // ok!
func foo_checkpointed(_ x: Float) -> Float {
  return x * x
}

func dbar(_ seed: Float, primal: Float, _ x: Float, _ y: Float) -> (Float, Float) {
  return (1, 1)
}

@differentiable(reverse, adjoint: dbar) // ok!
func bar(_ x: Float, _ y: Float) -> Float {
  return x + y
}

@differentiable(forward, adjoint: dbar) // expected-error {{forward-mode automatic differentiation is not supported yet}}
func bar_fwd(_ x: Float, _ y: Float) -> Float {
  return x + y
}

func dfoo2_wrong_type(_ seed: Double, _ primal: Float, _ x: Float) -> Float {
  return 2 * x
}

@differentiable(reverse, adjoint: dfoo2_wrong_type) // expected-error {{'dfoo2_wrong_type' does not have expected type '(Float, Float, Float) -> Float'}}
func foo2(_ x: Float) -> Float {
  return x * x
}

@differentiable(reverse, adjoint: dfoo(_:primal:_:)) // expected-error {{use of unresolved identifier 'dfoo(_:primal:_:)'}}
func foo3(_ x: Float) -> Float {
  return x * x
}

@differentiable(reverse, adjoint: meow) // expected-error {{use of unresolved identifier}}
func foo4(_ x: Float) -> Float {
  return x * x
}

@differentiable(reverse, adjoint: woof) // expected-error {{'foo5' has no parameters to differentiate with respect to}}
func foo5() -> Float {
  return 1
}

@differentiable(reverse, wrt: (self, .0, .1), adjoint: dmeow1(_:_:_:_:)) // expected-error {{'self' parameter is only applicable to instance methods}}
func meow1(_ x: Float, _: Float) -> Float {
  return 1 + x
}

func dmeow1_out_of_S(_ seed: Float, _ primal: Float, _ s: S, _ x: Float) -> (S, Float) {
  return (s, x)
}

func dPlus(_ seed: S, _ primal: S, _ x: S, _ y: S) -> (S, S) {
  return (x, y)
}

func dPlus_curried(_ x: S.Type) -> (S, S, S, S) -> (S, S) {
  fatalError("never run")
}

func dPlus(_ seed: S, _ primal: S, _ x: Int, _ y: S) -> (Int, S) {
  return (x, y)
}

struct C {
  @differentiable(reverse, adjoint: adjoint)
  func primal(x: Float) -> Float {
    return x
  }

  func adjoint(x: Float, _: Float, _: Float) -> Float {
    return x
  }
}

struct S {
  @differentiable(reverse, wrt: (self, .0), adjoint: dmeow1_out_of_S(_:_:_:_:)) // expected-error {{'dmeow1_out_of_S' is not defined in the current type context}}
  func meow1(_ x: Float) -> Float {
    return x + 1
  }

  @differentiable(reverse, wrt: (.1, self, .2), adjoint: dmeow1(_:_:_:_:)) // expected-error {{'self' parameter must come first in the parameter list}}
  func meow1_not_ok(_ x: Float, _: Float, _: Float) -> Float {
    return 1 + x
  }

  @differentiable(reverse, wrt: (self, .0), adjoint: dmeow1_in_S(_:_:_:_:)) // expected-error {{'self' parameter is only applicable to instance methods}}
  static func meow1(_ x: Float) -> Float {
    return x + 1
  }

  @differentiable(reverse, wrt: (self, .0, .1), adjoint: dPlus(_:_:_:_:)) // expected-error {{'self' parameter is only applicable to instance methods}}
  static func + (lhs: S, rhs: S) -> S {
    return lhs
  }

  @differentiable(reverse, wrt: (.0, .1), adjoint: dPlus(_:_:_:_:)) // expected-error {{'dPlus' is not defined in the current type context}}
  static func - (lhs: S, rhs: S) -> S {
    return lhs
  }

  @differentiable(reverse, wrt: (.0, .1), adjoint: dPlus_curried(_:)) // expected-error {{'dPlus_curried' is not defined in the current type context}}
  static func try_plus_curried_adjoint(lhs: S, rhs: S) -> S {
    return lhs
  }

  static func dMul(_: S, _: S, _ lhs: Int, _ rhs: S) -> (Int, S) {
    return (lhs, rhs)
  }

  @differentiable(reverse, wrt: (.0, .1), adjoint: dMul) // ok
  static func * (lhs: Int, rhs: S) -> S {
    return rhs
  }

  @differentiable(reverse, wrt: (.0, .1), adjoint: dMul) // expected-error {{'dMul' does not have expected type '(S) -> (S, S, Int, S) -> (Int, S)'}}
  func instance_mul(lhs: Int, rhs: S) -> S {
    return rhs
  }

  @differentiable(reverse, adjoint: dIdentity_wrt_self) // expected-error {{specify at least one parameter to differentiate with respect to}}
  func identity() -> S {
    return self
  }

  func dIdentity_wrt_self(seed: S, _: S) -> S {
    return seed
  }

  @differentiable(reverse, adjoint: dStaticIdentity_wrt_0) // ok
  static func staticIdentity(_ s: S) -> S {
    return s
  }

  static func dStaticIdentity_wrt_0(_ seed: S, _: S, _: S) -> S {
    return seed
  }
}

@differentiable(reverse, wrt: (.1, .2), adjoint: dmeow2(_:_:_:_:_:)) // ok
func meow2(_ x: Float, _: Float, _: Float) -> Float {
  return 1 + x
}

@differentiable(reverse, wrt: (.2, .1), adjoint: dmeow1(_:_:_:_:)) // expected-error {{parameter indices must be ascending}}
func meow3(_ x: Float, _: Float, _: Float) -> Float {
  return 1 + x
}

@differentiable(reverse, wrt: (.2, self, .1), adjoint: dmeow1(_:_:_:_:)) // expected-error {{'self' parameter is only applicable to instance methods}}
func meow4(_ : Float, _: Float, _ x: Float) -> Float {
  return 1 + x
}

func dmeow1(_ : Float, _: Float, _: Float, _ x: Float) -> (Float, Float) {
  return (x, x)
}

func dmeow2(_ : Float, _: Float, _: Float, _: Float, _ x: Float) -> (Float, Float) {
  return (x, x)
}

// Test cross-declaration references.
// NOTE: Cross-declaration references across files is not tested because it is
// difficult to set up and requires creating a new test target. Since the
// TensorFlow library will declare original functions/adjoints in separate
// files, successful compilation of the library itself is a sufficient test.

// Original function in struct definition, adjoint in extension.
struct E1 {
  @differentiable(reverse, adjoint: adjoint)
  func original(x: Float) -> Float {
    return x
  }
}
extension E1 {
  func adjoint(_: Float, _: Float, _ x: Float) -> Float {
    return x
  }
}

// Original function and adjoint in separate struct extensions.
struct E2 {}
extension E2 {
  @differentiable(reverse, adjoint: adjoint)
  func original(x: Float) -> Float {
    return x
  }
}
extension E2 {
  func adjoint(_: Float, _: Float, _ x: Float) -> Float {
    return x
  }
}

// Original function and adjoint in separate struct extensions, with matching
// generic constraints.
struct E3<T> {}
extension E3 where T == Float {
  @differentiable(reverse, adjoint: adjoint_same_constraint)
  func original(x: Float) -> Float {
    return x
  }
}
extension E3 where T == Float {
  func adjoint_same_constraint(x: Float, _: Float, _: Float) -> Float {
    return x
  }
}

struct E4<T> {}
extension E4 {
  @differentiable(reverse, adjoint: adjoint_no_constraint)
  func original(x: Float) -> Float {
    return x
  }
}
extension E4 {
  func adjoint_no_constraint(_: Float, _: Float, _ x: Float) -> Float {
    return x
  }
}

// Original function and adjoint in separate struct extensions, with
// non-matching generic constraints.
struct E5<T> {}
extension E5 {
  @differentiable(reverse, adjoint: adjoint_diff_constraint)
  // expected-error @-1 {{'adjoint_diff_constraint' does not have expected type '<T> (E5<T>) -> (Float, Float, Float) -> Float'}}
  func original(x: Float) -> Float {
    return x
  }
}
extension E5 where T == Float {
  func adjoint_diff_constraint(_: Float, _: Float, _ x: Float) -> Float {
    return x
  }
}

// Original function and adjoint in separate struct extensions, differentiating
// with respect to self.
struct E6<T> {}
extension E6 {
  @differentiable(reverse, wrt: (self), adjoint: adjoint_wrt_self)
  func original(x: Float) -> Float {
    return x
  }

  @differentiable(reverse, wrt: (self), primal: primal, adjoint: adjoint_checkpointed)
  func original2(x: Float) -> Float {
    return x
  }

  @differentiable(reverse, wrt: (self), primal: primal, adjoint: adjoint_checkpointed_mismatch)
  // expected-error @-1 {{'adjoint_checkpointed_mismatch' does not have expected type '<T> (E6<T>) -> (Float, E6<T>.Checkpoints, Float, Float) -> E6<T>'}}
  func original3(x: Float) -> Float {
    return x
  }
}
extension E6 {
  struct Checkpoints {
    let e6: E6
  }

  func primal(x: Float) -> (Checkpoints, Float) {
    return (Checkpoints(e6: self), x)
  }

  func adjoint_checkpointed(_: Float, _: Checkpoints, _: Float, _ x: Float) -> E6 {
    return self
  }

  func adjoint_checkpointed_mismatch(_: Float, _: Float, _ x: Float) -> E6 {
    return self
  }
}
extension E6 {
  func adjoint_wrt_self(_: Float, _: Float, _ x: Float) -> E6 {
    return self
  }
}

// Generic functions with no constraints.
func dbaz1<T>(_ seed: T, primal: T, _ x: T, _ y: T) -> (T, T) {
  return (y, x)
}
@differentiable(reverse, adjoint: dbaz1) // ok!
func baz1<T>(_ x: T, _ y: T) -> T {
  return x
}

func pbaz1<T>(_ x: T, _ y: T) -> ((T, T), T) {
  return ((y, y), x)
}
func dbaz1_checkpointed<T>(_ seed: T, _ primal: (T, T), originalValue: T, _ x: T, _ y: T) -> (T, T) {
  return (y, x)
}
@differentiable(reverse, primal: pbaz1, adjoint: dbaz1_checkpointed) // ok!
func baz1_checkpointed<T>(_ x: T, _ y: T) -> T {
  return x
}

// Generic functions with matching constraints.
func dbaz2<T : FloatingPoint>(_ seed: T, _ primal: T, _ x: T, _ y: T) -> (T, T) {
  return (1, 1)
}
@differentiable(reverse, adjoint: dbaz2) // ok!
func baz2<T : FloatingPoint>(_ x: T, _ y: T) -> T {
  return x + y
}

struct CheckpointsFP<T : FloatingPoint> {
  let meow: T
}
func pbaz2<T : FloatingPoint>(_ x: T, _ y: T) -> (CheckpointsFP<T>, T) {
  return (CheckpointsFP(meow: 1), x + y)
}
func dbaz2_checkpointed<T : FloatingPoint>(_ seed: T, _ primal: CheckpointsFP<T>, _ originalValue: T, _ x: T, _ y: T) -> (T, T) {
  return (1, 1)
}
@differentiable(reverse, primal: pbaz2, adjoint: dbaz2_checkpointed) // ok!
func baz2_checkpointed<T : FloatingPoint>(_ x: T, _ y: T) -> T {
  return x
}

// Generic functions with different constraints.
func dbaz3<T : Numeric>(_ seed: T, _ primal: T, _ x: T, _ y: T) -> (T, T) {
  return (1, 1)
}
@differentiable(reverse, adjoint: dbaz3)
// expected-error @-1 {{'dbaz3' does not have expected type '<T where T : FloatingPoint> (T, T, T, T) -> (T, T)'}}
func baz3<T : FloatingPoint>(_ x: T, _ y: T) -> T {
  return x + y
}

struct CheckpointsNumeric<T : Numeric> {
  let meow: T
}
func pbaz3<T : Numeric>(_ x: T, _ y: T) -> (CheckpointsNumeric<T>, T) {
  return (CheckpointsNumeric(meow: 1), x + y)
}
func dbaz3_checkpointed<T : Numeric>(_ seed: T, _ primal: CheckpointsNumeric<T>, _ originalValue: T, _ x: T, _ y: T) -> (T, T) {
  return (1, 1)
}
@differentiable(reverse, primal: pbaz3(_:_:), adjoint: dbaz3_checkpointed)
// expected-error @-1 {{'pbaz3' does not have expected parameters' type '(T, T)'}}
func baz3_checkpointed<T : FloatingPoint>(_ x: T, _ y: T) -> T {
  return x
}

// Adjoints trying to define derivatives with respect to classes and existentials.

class ParamClass {}
protocol ParamProtocol {}
struct ParamProtocolStruct : ParamProtocol {}

@differentiable(reverse, adjoint: dClassParameter)
// expected-error @-1 {{class objects and protocol existentials ('ParamClass') cannot be differentiated with respect to}}
func classParameter1(_: ParamClass) -> Float {
  return 1
}

@differentiable(reverse, wrt: (.0), adjoint: dClassParameter)
// expected-error @-1 {{class objects and protocol existentials ('ParamClass') cannot be differentiated with respect to}}
func classParameter2(_: ParamClass) -> Float {
  return 1
}

func dClassParameter(_: ParamClass, _: Float, seed: Float) -> ParamClass {
  return ParamClass()
}

@differentiable(reverse, adjoint: dProtocolParameter)
// expected-error @-1 {{class objects and protocol existentials ('ParamProtocol') cannot be differentiated with respect to}}
func protocolParameter1(_: ParamProtocol) -> Float {
  return 1
}

@differentiable(reverse, wrt: (.0), adjoint: dProtocolParameter)
// expected-error @-1 {{class objects and protocol existentials ('ParamProtocol') cannot be differentiated with respect to}}
func protocolParameter2(_: ParamProtocol) -> Float {
  return 1
}

func dProtocolParameter(_ seed: Float, _: Float, _: ParamProtocol) -> ParamProtocol {
  return ParamProtocolStruct()
}

class ClassWithDifferentiableMethods {
  @differentiable(reverse, wrt: (self), adjoint: dMethod)
  // expected-error @-1 {{class objects and protocol existentials ('ClassWithDifferentiableMethods') cannot be differentiated with respect to}}
  func method() -> Float {
    return 1
  }

  func dMethod(_: Float, _: Float) -> ClassWithDifferentiableMethods {
    return ClassWithDifferentiableMethods()
  }
}

// @differentiable attribute on protocol requirements

func dummyPrimal() {}
func dummyAdjoint() {}

protocol ProtoWithDiffReqs {
  // OK
  @differentiable(reverse)
  func req1(x: Float) -> Float

  // OK
  @differentiable(reverse, wrt: (self))
  func req2(x: Float) -> Float

  // OK
  @differentiable(reverse, wrt: (.0))
  func req3(x: Float) -> Float

  // OK
  @differentiable(reverse)
  static func req4(x: Float) -> Float

  // expected-error @+1 {{parameter index out of bounds}}
  @differentiable(reverse, wrt: (.1))
  func req5(x: Float) -> Float

  // expected-error @+1 {{cannot specify associated differentiation function on protocol requirement}}
  @differentiable(reverse, primal: dummyPrimal)
  func req6(x: Float) -> Float

  // expected-error @+1 {{cannot specify associated differentiation function on protocol requirement}}
  @differentiable(reverse, adjoint: dummyAdjoint)
  func req7(x: Float) -> Float
}

// JVP and VJP typechecking
// These tests are not as exhaustive as the primal and adjoint tests above,
// because JVP and VJP are still under development. When we delete primal and
// adjoint, we will replace the primal and adjoint tests with corresponding JVP
// and VJP tests.

// JVP

@differentiable(reverse, jvp: jvpSimpleJVP)
func jvpSimple(x: Float) -> Float {
  return x
}

func jvpSimpleJVP(x: Float) -> (Float, ((Float) -> Float)) {
  return (x, { v in v })
}

@differentiable(reverse, wrt: (.1), jvp: jvpWrtSubsetJVP)
func jvpWrtSubset(x: Float, y: Float) -> Float {
  return x + y
}

func jvpWrtSubsetJVP(x: Float, y: Float) -> (Float, (Float) -> Float) {
  return (x + y, { v in v })
}

@differentiable(reverse, jvp: jvp2ParamsJVP)
func jvp2Params(x: Float, y: Float) -> Float {
  return x + y
}

func jvp2ParamsJVP(x: Float, y: Float) -> (Float, (Float, Float) -> Float) {
  return (x + y, { (a, b) in a + b })
}

// expected-error @+1 {{'jvpWrongTypeJVP' does not have expected type '(Float) -> (Float, (Float) -> Float)'}}
@differentiable(reverse, jvp: jvpWrongTypeJVP)
func jvpWrongType(x: Float) -> Float {
  return x
}

func jvpWrongTypeJVP(x: Float) -> (Float, (Float) -> Int) {
  return (x, { v in Int(v) })
}

// expected-error @+1 {{can only differentiate with respect to parameters that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, jvp: jvpSimpleJVP)
func jvpNonDiffParam(x: Int) -> Float {
  return Float(x)
}

// expected-error @+1 {{can only differentiate functions with results that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, jvp: jvpSimpleJVP)
func jvpNonDiffResult(x: Float) -> Int {
  return Int(x)
}

// expected-error @+1 {{can only differentiate functions with results that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, jvp: jvpSimpleJVP)
func jvpNonDiffResult2(x: Float) -> (Float, Int) {
  return (x, Int(x))
}

struct JVPStruct {
  let p: Float
}

extension JVPStruct : Differentiable {
  typealias TangentVector = JVPStruct
  typealias CotangentVector = JVPStruct
  func moved(toward direction: JVPStruct) -> JVPStruct {
    return JVPStruct(p: p + direction.p)
  }
  func tangentVector(from cotangent: JVPStruct) -> JVPStruct {
    return cotangent
  }
}

extension JVPStruct {
  @differentiable(reverse, jvp: wrtAllNonSelfJVP)
  func wrtAllNonSelf(x: Float) -> Float {
    return x + p
  }

  func wrtAllNonSelfJVP(x: Float) -> (Float, (Float) -> Float) {
    return (x + p, { v in v })
  }
}

extension JVPStruct {
  @differentiable(reverse, wrt: (self, .0), jvp: wrtAllJVP)
  func wrtAll(x: Float) -> Float {
    return x + p
  }

  func wrtAllJVP(x: Float) -> (Float, (JVPStruct, Float) -> Float) {
    return (x + p, { (a, b) in a.p + b })
  }
}

// VJP

@differentiable(reverse, vjp: vjpSimpleVJP)
func vjpSimple(x: Float) -> Float {
  return x
}

func vjpSimpleVJP(x: Float) -> (Float, ((Float) -> Float)) {
  return (x, { v in v })
}

@differentiable(reverse, wrt: (.1), vjp: vjpWrtSubsetVJP)
func vjpWrtSubset(x: Float, y: Float) -> Float {
  return x + y
}

func vjpWrtSubsetVJP(x: Float, y: Float) -> (Float, (Float) -> Float) {
  return (x + y, { v in v })
}

@differentiable(reverse, vjp: vjp2ParamsVJP)
func vjp2Params(x: Float, y: Float) -> Float {
  return x + y
}

func vjp2ParamsVJP(x: Float, y: Float) -> (Float, (Float) -> (Float, Float)) {
  return (x + y, { v in (v, v) })
}

// expected-error @+1 {{'vjpWrongTypeVJP' does not have expected type '(Float) -> (Float, (Float) -> Float)'}}
@differentiable(reverse, vjp: vjpWrongTypeVJP)
func vjpWrongType(x: Float) -> Float {
  return x
}

func vjpWrongTypeVJP(x: Float) -> (Float, (Float) -> Int) {
  return (x, { v in Int(v) })
}

// expected-error @+1 {{can only differentiate with respect to parameters that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, vjp: vjpSimpleVJP)
func vjpNonDiffParam(x: Int) -> Float {
  return Float(x)
}

// expected-error @+1 {{can only differentiate functions with results that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, vjp: vjpSimpleVJP)
func vjpNonDiffResult(x: Float) -> Int {
  return Int(x)
}

// expected-error @+1 {{can only differentiate functions with results that conform to 'Differentiable', but 'Int' does not conform to 'Differentiable'}}
@differentiable(reverse, vjp: vjpSimpleVJP)
func vjpNonDiffResult2(x: Float) -> (Float, Int) {
  return (x, Int(x))
}

struct VJPStruct {
  let p: Float
}

extension VJPStruct : Differentiable {
  typealias TangentVector = VJPStruct
  typealias CotangentVector = VJPStruct
  func moved(toward direction: VJPStruct) -> VJPStruct {
    return VJPStruct(p: p + direction.p)
  }
  func tangentVector(from cotangent: VJPStruct) -> VJPStruct {
    return cotangent
  }
}

extension VJPStruct {
  @differentiable(reverse, vjp: wrtAllNonSelfVJP)
  func wrtAllNonSelf(x: Float) -> Float {
    return x + p
  }

  func wrtAllNonSelfVJP(x: Float) -> (Float, (Float) -> Float) {
    return (x + p, { v in v })
  }
}

extension VJPStruct {
  @differentiable(reverse, wrt: (self, .0), vjp: wrtAllVJP)
  func wrtAll(x: Float) -> Float {
    return x + p
  }

  func wrtAllVJP(x: Float) -> (Float, (Float) -> (VJPStruct, Float)) {
    return (x + p, { v in (VJPStruct(p: v), v) })
  }
}
