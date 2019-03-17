// RUN: %target-swift-frontend -typecheck -verify %s

// Test top-level functions.

func sin(_ x: Float) -> Float {
  return x // dummy implementation
}

@differentiating(sin) // ok
func vjpSin(x: Float) -> (value: Float, pullback: (Float) -> Float) {
  return (x, { $0 })
}
@differentiating(sin)
func jvpSin(x: @nondiff Float) -> (value: Float, differential: (Float) -> (Float)) {
  return (x, { $0 })
}
// expected-error @+1 {{'@differentiating' attribute requires function to return a two-element tuple of type '(value: T..., pullback: (U.CotangentVector) -> T.CotangentVector...)' or '(value: T..., differential: (T.TangentVector...) -> U.TangentVector)'}}
@differentiating(sin)
func jvpSinResultInvalid(x: @nondiff Float) -> Float {
  return x
}
// expected-error @+1 {{'@differentiating' attribute requires function to return a two-element tuple (second element must have label 'pullback:' or 'differential:')}}
@differentiating(sin)
func vjpSinResultWrongLabel(x: Float) -> (value: Float, (Float) -> Float) {
  return (x, { $0 })
}
// expected-error @+1 {{'@differentiating' attribute requires function to return a two-element tuple (first element type 'Int' must conform to 'Differentiable')}}
@differentiating(sin)
func vjpSinResultNotDifferentiable(x: Int) -> (value: Int, pullback: (Int) -> Int) {
  return (x, { $0 })
}
// expected-error @+2 {{'pullback' does not have expected type '(Float.CotangentVector) -> (Float.CotangentVector)' (aka '(Float) -> Float')}}
@differentiating(sin)
func vjpSinResultInvalidSeedType(x: Float) -> (value: Float, pullback: (Double) -> Double) {
  return (x, { $0 })
}

func generic<T : Differentiable>(_ x: T, _ y: T) -> T {
  return x
}
@differentiating(generic) // ok
func vjpGeneric<T : Differentiable>(x: T, y: T) -> (value: T, pullback: (T.CotangentVector) -> (T.CotangentVector, T.CotangentVector)) {
  return (x, { ($0, $0) })
}
@differentiating(generic)
func jvpGeneric<T : Differentiable>(x: T, y: T) -> (value: T, differential: (T.TangentVector, T.TangentVector) -> T.TangentVector) {
  return (x, { $0 + $1 })
}
// expected-error @+1 {{'@differentiating' attribute requires function to return a two-element tuple (second element must have label 'pullback:' or 'differential:')}}
@differentiating(generic)
func vjpGenericWrongLabel<T : Differentiable>(x: T, y: T) -> (value: T, (T) -> (T, T)) {
  return (x, { ($0, $0) })
}
// expected-error @+2 {{'pullback' does not have expected type '(T) -> (T)'}}
@differentiating(generic)
func vjpGenericDiffParamMismatch<T : Differentiable>(x: T) -> (value: T, pullback: (T) -> (T, T)) where T == T.CotangentVector {
  return (x, { ($0, $0) })
}
@differentiating(generic)
func vjpGenericExtraGenericRequirements<T : Differentiable & FloatingPoint>(x: T, y: T) -> (value: T, pullback: (T) -> (T, T)) where T == T.CotangentVector {
  return (x, { ($0, $0) })
}

func foo<T : FloatingPoint & Differentiable>(_ x: T) -> T { return x }

// expected-error @+2 {{type 'T' does not conform to protocol 'FloatingPoint'}}
// expected-error @+1 {{'foo' does not have expected type '<T where T : AdditiveArithmetic, T : Differentiable> (T) -> T'}}
@differentiating(foo)
func vjpFoo<T : AdditiveArithmetic & Differentiable>(_ x: T) -> (value: T, pullback: (T.CotangentVector) -> (T.CotangentVector)) {
  return (x, { $0 })
}
@differentiating(foo)
func vjpFoo<T : FloatingPoint & Differentiable>(_ x: T) -> (value: T, pullback: (T.CotangentVector) -> (T.CotangentVector)) {
  return (x, { $0 })
}
@differentiating(foo)
func vjpFooExtraGenericRequirements<T : FloatingPoint & Differentiable & BinaryInteger>(_ x: T) -> (value: T, pullback: (T) -> (T)) where T == T.CotangentVector {
  return (x, { $0 })
}

// Test static methods.

extension AdditiveArithmetic where Self : Differentiable {
  // expected-error @+1 {{derivative not in the same file as the original function}}
  @differentiating(+)
  static func vjpPlus(x: Self, y: Self) -> (value: Self, pullback: (Self.CotangentVector) -> (Self.CotangentVector, Self.CotangentVector)) {
    return (x + y, { v in (v, v) })
  }
}

extension FloatingPoint where Self : Differentiable, Self == Self.CotangentVector {
  // expected-error @+1 {{derivative not in the same file as the original function}}
  @differentiating(+)
  static func vjpPlus(x: Self, y: Self) -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (x + y, { v in (v, v) })
  }
}

extension Differentiable where Self : AdditiveArithmetic {
  // expected-error @+1 {{'+' is not defined in the current type context}}
  @differentiating(+)
  static func vjpPlus(x: Self, y: Self) -> (value: Self, pullback: (Self.CotangentVector) -> (Self.CotangentVector, Self.CotangentVector)) {
    return (x + y, { v in (v, v) })
  }
}

extension AdditiveArithmetic where Self : Differentiable, Self == Self.CotangentVector {
  // expected-error @+2 {{'pullback' does not have expected type '(Self) -> (Self, Self, Self)'}}
  @differentiating(+)
  func vjpPlusInstanceMethod(x: Self, y: Self) -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (x + y, { v in (v, v) })
  }
}

// Test instance methods.

protocol InstanceMethod : Differentiable {
  func foo(_ x: Self) -> Self
  func bar<T : Differentiable>(_ x: T) -> Self
}

extension InstanceMethod {
  // If `Self` conforms to `Differentiable`, then `Self` is currently always inferred to be a differentiation parameter.
  // expected-error @+2 {{'pullback' does not have expected type '(Self.CotangentVector) -> (Self.CotangentVector, Self.CotangentVector)'}}
  @differentiating(foo)
  func vjpFoo(x: Self) -> (value: Self, pullback: (Self.CotangentVector) -> Self.CotangentVector) {
    return (x, { $0 })
  }

  @differentiating(foo)
  func vjpFoo(x: Self) -> (value: Self, pullback: (Self.CotangentVector) -> (Self.CotangentVector, Self.CotangentVector)) {
    return (x, { ($0, $0) })
  }
}

extension InstanceMethod {
  // expected-error @+2 {{'pullback' does not have expected type '(Self.CotangentVector) -> (Self.CotangentVector, T.CotangentVector)'}}
  @differentiating(bar)
  func vjpBar<T : Differentiable>(_ x: T) -> (value: Self, pullback: (Self.CotangentVector) -> T.CotangentVector) {
    return (self, { _ in .zero })
  }

  @differentiating(bar)
  func vjpBar<T : Differentiable>(_ x: T) -> (value: Self, pullback: (Self.CotangentVector) -> (Self.CotangentVector, T.CotangentVector)) {
    return (self, { ($0, .zero) })
  }

  @differentiating(bar)
  func jvpBar<T : Differentiable>(_ x: T) -> (value: Self, differential: (Self.TangentVector, T.TangentVector) -> Self.TangentVector) {
    return (self, { dself, dx in dself })
  }
}

extension InstanceMethod where Self == Self.TangentVector, Self == Self.CotangentVector {
  @differentiating(foo)
  func vjpFooExtraRequirements(x: Self) -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (x, { ($0, $0) })
  }

  @differentiating(foo)
  func jvpFooExtraRequirements(x: Self) -> (value: Self, differential: (Self, Self) -> (Self)) {
    return (x, { $0 + $1 })
  }

  @differentiating(bar)
  func vjpBarExtraRequirements<T : Differentiable>(x: T) -> (value: Self, pullback: (Self) -> (Self, T.CotangentVector)) {
    return (self, { ($0, .zero) })
  }

  @differentiating(bar)
  func jvpBarExtraRequirements<T : Differentiable>(_ x: T) -> (value: Self, differential: (Self, T.TangentVector) -> Self) {
    return (self, { dself, dx in dself })
  }
}

protocol GenericInstanceMethod : Differentiable where Self == Self.TangentVector, Self == Self.CotangentVector {
  func instanceMethod<T : Differentiable>(_ x: T) -> T
}

extension GenericInstanceMethod {
  func jvpInstanceMethod<T : Differentiable>(_ x: T) -> (T, (T.TangentVector) -> (TangentVector, T.TangentVector)) {
    return (x, { v in (self, v) })
  }

  func vjpInstanceMethod<T : Differentiable>(_ x: T) -> (T, (T.CotangentVector) -> (CotangentVector, T.CotangentVector)) {
    return (x, { v in (self, v) })
  }
}
