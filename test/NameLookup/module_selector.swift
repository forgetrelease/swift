// RUN: %target-typecheck-verify-swift -sdk %clang-importer-sdk -module-name main -I %S/Inputs -enable-experimental-module-selector

// Make sure the lack of the experimental flag disables the feature:
// RUN: not %target-typecheck-verify-swift -sdk %clang-importer-sdk -module-name main -I %S/Inputs 2>/dev/null

// FIXME: This test doesn't really cover:
//
// * Whether X::foo finds foos in X's re-exports
// * Whether we handle access paths correctly
// * Interaction with ClangImporter
// * Cross-import overlays
// * Key paths
// * Key path dynamic member lookup
//
// It also might not cover all combinations of name lookup paths and inputs.

import ModuleSelectorTestingKit

import ctypes::bits   // FIXME: ban using :: with submodules?
import struct ModuleSelectorTestingKit::A

let magnitude: Never = fatalError()

// Test correct code using `A`

extension ModuleSelectorTestingKit::A: Swift::Equatable {
  @_implements(Swift::Equatable, ==(_:_:))
  public static func equals(_: ModuleSelectorTestingKit::A, _: ModuleSelectorTestingKit::A) -> Swift::Bool {
    Swift::fatalError()
  }

  // FIXME: Add tests with autodiff @_differentiable(jvp:vjp:) and
  // @_derivative(of:)

  @_dynamicReplacement(for: ModuleSelectorTestingKit::negate())
  mutating func myNegate() {
    let fn: (Swift::Int, Swift::Int) -> Swift::Int =
      (+)
      // TODO: it'd be nice to handle module selectors on operators.

    let magnitude: Int.Swift::Magnitude = main::magnitude
    // expected-error@-1 {{cannot convert value of type 'Never' to specified type 'Int.Magnitude' (aka 'UInt')}}

    if Swift::Bool.Swift::random() {
      self.ModuleSelectorTestingKit::negate()
    }
    else {
      self = ModuleSelectorTestingKit::A(value: .Swift::min)
      self = A.ModuleSelectorTestingKit::init(value: .min)
    }

    self.main::myNegate()

    Swift::fatalError()
  }

  // FIXME: Can we test @convention(witness_method:)?
}

// Test resolution of main:: using `B`

extension main::B {}
// expected-error@-1 {{type 'B' is not imported through module 'main'}}
// expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{11-15=ModuleSelectorTestingKit}}

extension B: main::Equatable {
  // expected-error@-1 {{type 'Equatable' is not imported through module 'main'}}
  // expected-note@-2 {{did you mean module 'Swift'?}} {{14-18=Swift}}

  @_implements(main::Equatable, main::==(_:_:))
  // expected-error@-1 {{name cannot be qualified with module selector here}} {{33-39=}}
  // expected-error@-2 {{type 'Equatable' is not imported through module 'main'}}
  // expected-note@-3 {{did you mean module 'Swift'?}} {{16-20=Swift}}
  public static func equals(_: main::B, _: main::B) -> main::Bool {
  // expected-error@-1 2{{type 'B' is not imported through module 'main'}}
  // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{32-36=ModuleSelectorTestingKit}}
  // expected-note@-3 {{did you mean module 'ModuleSelectorTestingKit'?}} {{44-48=ModuleSelectorTestingKit}}
  // expected-error@-4 {{type 'Bool' is not imported through module 'main'}}
  // expected-note@-5 {{did you mean module 'Swift'?}} {{56-60=Swift}}
    main::fatalError()    // no-error: body not typechecked
  }

  // FIXME: Add tests with autodiff @_differentiable(jvp:vjp:) and
  // @_derivative(of:)
  
  @_dynamicReplacement(for: main::negate())
  // expected-error@-1 {{replaced function 'main::negate()' could not be found}}
  // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{29-33=ModuleSelectorTestingKit}}
  mutating func myNegate() {
    let fn: (main::Int, main::Int) -> main::Int =
    // expected-error@-1 3{{type 'Int' is not imported through module 'main'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{14-18=Swift}}
    // expected-note@-3 {{did you mean module 'Swift'?}} {{25-29=Swift}}
    // expected-note@-4 {{did you mean module 'Swift'?}} {{39-43=Swift}}
      (main::+)
      // TODO: it'd be nice to handle module selectors on operators.
      // expected-error@-2 {{expected expression}}
      // expected-error@-3 {{expected expression after operator}}

    let magnitude: Int.main::Magnitude = main::magnitude
    // expected-error@-1 {{type 'Magnitude' is not imported through module 'main'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{24-28=Swift}}

    if main::Bool.main::random() {
    // expected-error@-1 {{declaration 'Bool' is not imported through module 'main'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{8-12=Swift}}

      main::negate()
      // expected-error@-1 {{declaration 'negate' is not imported through module 'main'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{7-11=self.ModuleSelectorTestingKit}}
    }
    else {
      self = main::B(value: .main::min)
      // expected-error@-1 {{declaration 'B' is not imported through module 'main'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{14-18=ModuleSelectorTestingKit}}
      self = B.main::init(value: .min)
      // expected-error@-1 {{declaration 'init(value:)' is not imported through module 'main'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{16-20=ModuleSelectorTestingKit}}
    }
    
    self.main::myNegate()

    main::fatalError()
    // expected-error@-1 {{declaration 'fatalError' is not imported through module 'main'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{5-9=Swift}}
  }

  // FIXME: Can we test @convention(witness_method:)?
}

// Test resolution of ModuleSelectorTestingKit:: using `C`

extension ModuleSelectorTestingKit::C {}

extension C: ModuleSelectorTestingKit::Equatable {
// expected-error@-1 {{type 'Equatable' is not imported through module 'ModuleSelectorTestingKit'}}
// expected-note@-2 {{did you mean module 'Swift'?}} {{14-38=Swift}}

  @_implements(ModuleSelectorTestingKit::Equatable, ModuleSelectorTestingKit::==(_:_:))
  // expected-error@-1 {{name cannot be qualified with module selector here}} {{53-79=}}
  // expected-error@-2 {{type 'Equatable' is not imported through module 'ModuleSelectorTestingKit'}}
  // expected-note@-3 {{did you mean module 'Swift'?}} {{16-40=Swift}}

  public static func equals(_: ModuleSelectorTestingKit::C, _: ModuleSelectorTestingKit::C) -> ModuleSelectorTestingKit::Bool {
  // expected-error@-1 {{type 'Bool' is not imported through module 'ModuleSelectorTestingKit'}}
  // expected-note@-2 {{did you mean module 'Swift'?}} {{96-120=Swift}}
    ModuleSelectorTestingKit::fatalError()    // no-error: body not typechecked
  }

  // FIXME: Add tests with autodiff @_differentiable(jvp:vjp:) and
  // @_derivative(of:)
  
  @_dynamicReplacement(for: ModuleSelectorTestingKit::negate())
  mutating func myNegate() {
  // expected-note@-1 {{'myNegate()' declared here}}

    let fn: (ModuleSelectorTestingKit::Int, ModuleSelectorTestingKit::Int) -> ModuleSelectorTestingKit::Int =
    // expected-error@-1 3{{type 'Int' is not imported through module 'ModuleSelectorTestingKit'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{14-38=Swift}}
    // expected-note@-3 {{did you mean module 'Swift'?}} {{45-69=Swift}}
    // expected-note@-4 {{did you mean module 'Swift'?}} {{79-103=Swift}}
      (ModuleSelectorTestingKit::+)
      // TODO: it'd be nice to handle module selectors on operators.
      // expected-error@-2 {{expected expression}}
      // expected-error@-3 {{expected expression after operator}}

    let magnitude: Int.ModuleSelectorTestingKit::Magnitude = ModuleSelectorTestingKit::magnitude
    // expected-error@-1 {{type 'Magnitude' is not imported through module 'ModuleSelectorTestingKit'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{24-48=Swift}}

    if ModuleSelectorTestingKit::Bool.ModuleSelectorTestingKit::random() {
    // expected-error@-1 {{declaration 'Bool' is not imported through module 'ModuleSelectorTestingKit'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{8-32=Swift}}

      ModuleSelectorTestingKit::negate()
      // expected-error@-1 {{declaration 'negate' is not imported through module 'ModuleSelectorTestingKit'}}
      // expected-note@-2 {{did you mean the member of 'self'?}} {{7-7=self.}}
    }
    else {
      self = ModuleSelectorTestingKit::C(value: .ModuleSelectorTestingKit::min)
      // expected-error@-1 {{declaration 'min' is not imported through module 'ModuleSelectorTestingKit'}}
      // expected-note@-2 {{did you mean module 'Swift'?}} {{50-74=Swift}}
      self = C.ModuleSelectorTestingKit::init(value: .min)
    }
    
    self.ModuleSelectorTestingKit::myNegate()
    // expected-error@-1 {{declaration 'myNegate()' is not imported through module 'ModuleSelectorTestingKit'}}
    // expected-note@-2 {{did you mean module 'main'?}} {{10-34=main}}

    ModuleSelectorTestingKit::fatalError()
    // expected-error@-1 {{declaration 'fatalError' is not imported through module 'ModuleSelectorTestingKit'}}
    // expected-note@-2 {{did you mean module 'Swift'?}} {{5-29=Swift}}
  }

  // FIXME: Can we test @convention(witness_method:)?
}

// Test resolution of Swift:: using `D`
// FIXME: Many more of these should fail once the feature is actually implemented.

extension Swift::D {}
// expected-error@-1 {{type 'D' is not imported through module 'Swift'}}
// expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{11-16=ModuleSelectorTestingKit}}

extension D: Swift::Equatable {
// Caused by Swift::D failing to typecheck in `equals(_:_:)`: expected-error@-1 *{{extension outside of file declaring struct 'D' prevents automatic synthesis of '==' for protocol 'Equatable'}}

  @_implements(Swift::Equatable, Swift::==(_:_:))
  // expected-error@-1 {{name cannot be qualified with module selector here}} {{34-41=}}

  public static func equals(_: Swift::D, _: Swift::D) -> Swift::Bool {
  // expected-error@-1 2{{type 'D' is not imported through module 'Swift'}}
  // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{32-37=ModuleSelectorTestingKit}}
  // expected-note@-3 {{did you mean module 'ModuleSelectorTestingKit'?}} {{45-50=ModuleSelectorTestingKit}}
    Swift::fatalError()
  }

  // FIXME: Add tests with autodiff @_differentiable(jvp:vjp:) and
  // @_derivative(of:)
  
  @_dynamicReplacement(for: Swift::negate())
  // expected-error@-1 {{replaced function 'Swift::negate()' could not be found}}
  // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{29-34=ModuleSelectorTestingKit}}
  mutating func myNegate() {
  // expected-note@-1 {{'myNegate()' declared here}}

    let fn: (Swift::Int, Swift::Int) -> Swift::Int =
      (Swift::+)
      // TODO: it'd be nice to handle module selectors on operators.
      // expected-error@-2 {{cannot convert value of type '()' to specified type '(Int, Int) -> Int'}}
      // expected-error@-3 {{expected expression}}
      // expected-error@-4 {{expected expression after operator}}
    let magnitude: Int.Swift::Magnitude = Swift::magnitude
    // expected-error@-1 {{declaration 'magnitude' is not imported through module 'Swift'}}
    // expected-note@-2 {{did you mean module 'main'?}}
    if Swift::Bool.Swift::random() {
      Swift::negate()
      // expected-error@-1 {{declaration 'negate' is not imported through module 'Swift'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{7-12=self.ModuleSelectorTestingKit}}
    }
    else {
      self = Swift::D(value: .ModuleSelectorTestingKit::min)
      // expected-error@-1 {{declaration 'D' is not imported through module 'Swift'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{14-19=ModuleSelectorTestingKit}}
      self = D.Swift::init(value: .min)
      // expected-error@-1 {{declaration 'init(value:)' is not imported through module 'Swift'}}
      // expected-note@-2 {{did you mean module 'ModuleSelectorTestingKit'?}} {{16-21=ModuleSelectorTestingKit}}
    }
    
    self.Swift::myNegate()
    // expected-error@-1 {{declaration 'myNegate()' is not imported through module 'Swift'}}
    // expected-note@-2 {{did you mean module 'main'?}} {{10-15=main}}

    Swift::fatalError()
  }

  // FIXME: Can we test @convention(witness_method:)?
}

let mog: Never = fatalError()

func localVarsCantBeAccessedByModuleSelector() {
  let mag: Int.Swift::Magnitude = main::mag
  // expected-error@-1 {{declaration 'mag' is not imported through module 'main'}}
  // expected-note@-2 {{did you mean the local declaration?}} {{35-41=}}

  let mog: Never = main::mog
  // no-error
}

struct AvailableUser {
  @available(macOS 10.15, *) var use1: String { "foo" }

  @main::available() var use2
  // FIXME improve: expected-error@-1 {{unknown attribute 'available'}}
  // FIXME suppress: expected-error@-2 {{type annotation missing in pattern}}

  @ModuleSelectorTestingKit::available() var use4
  // no-error

  @Swift::available() var use5
  // FIXME improve: expected-error@-1 {{unknown attribute 'available'}}
  // FIXME suppress: expected-error@-2 {{type annotation missing in pattern}}
}

func builderUser2(@main::MyBuilder fn: () -> Void) {}
// FIXME improve: expected-error@-1 {{unknown attribute 'MyBuilder'}}

func builderUser3(@ModuleSelectorTestingKit::MyBuilder fn: () -> Void) {}
// no-error

func builderUser4(@Swift::MyBuilder fn: () -> Void) {}
// FIXME improve: expected-error@-1 {{unknown attribute 'MyBuilder'}}

func whitespace() {
  Swift::print
  // expected-error@-1 {{function is unused}}

  Swift:: print
  // expected-error@-1 {{function is unused}}

  Swift ::print
  // expected-error@-1 {{function is unused}}

  Swift :: print
  // expected-error@-1 {{function is unused}}

  Swift::
  print
  // expected-error@-1 {{function is unused}}

  Swift
  ::print
  // expected-error@-1 {{function is unused}}

  Swift ::
  print
  // expected-error@-1 {{function is unused}}

  Swift
  :: print
  // expected-error@-1 {{function is unused}}

  Swift
  ::
  print
  // expected-error@-1 {{function is unused}}
}

// Error cases

func main::decl1(
  // expected-error@-1 {{name of function declaration cannot be qualified with module selector}}
  main::p1: main::A,
  // expected-error@-1 {{argument label cannot be qualified with module selector}}
  // expected-error@-2 {{type 'A' is not imported through module 'main'}}
  // expected-note@-3 {{did you mean module 'ModuleSelectorTestingKit'?}} {{13-17=ModuleSelectorTestingKit}}
  main::label p2: main::inout A,
  // expected-error@-1 {{argument label cannot be qualified with module selector}}
  // FIXME: expected-error@-2 {{expected identifier in dotted type}} should be something like {{type 'inout' is not imported through module 'main'}}
  label main::p3: @main::escaping () -> A
  // expected-error@-1 {{name of parameter declaration cannot be qualified with module selector}}
  // FIXME: expected-error@-2 {{attribute can only be applied to declarations, not types}} should be something like {{type 'escaping' is not imported through module 'main'}}
  // FIXME: expected-error@-3 {{expected parameter type following ':'}}
) {
  let main::decl1a = "a"
  // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}

  var main::decl1b = "b"
  // expected-error@-1 {{name of variable declaration cannot be qualified with module selector}}

  let (main::decl1c, main::decl1d) = ("c", "d")
  // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
  // expected-error@-2 {{name of constant declaration cannot be qualified with module selector}}

  if let (main::decl1e, main::decl1f) = Optional(("e", "f")) {}
  // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
  // expected-error@-2 {{name of constant declaration cannot be qualified with module selector}}

  guard let (main::decl1g, main::decl1h) = Optional(("g", "h")) else { return }
  // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
  // expected-error@-2 {{name of constant declaration cannot be qualified with module selector}}

  // From uses in the switch statements below:
  // expected-note@-5 3{{did you mean the local declaration?}}

  switch Optional(main::decl1g) {
  // expected-error@-1 {{declaration 'decl1g' is not imported through module 'main'}}
  case Optional.some(let main::decl1i):
    // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
    break
  case .none:
    break
  }

  switch Optional(main::decl1g) {
  // expected-error@-1 {{declaration 'decl1g' is not imported through module 'main'}}
  case let Optional.some(main::decl1j):
    // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
    break
  case .none:
    break
  }

  switch Optional(main::decl1g) {
 // expected-error@-1 {{declaration 'decl1g' is not imported through module 'main'}}
 case let main::decl1k?:
    // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}
    break
  case .none:
    break
  }

  for main::decl1l in "lll" {}
  // expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}

  "lll".forEach { [main::magnitude]
    // expected-error@-1 {{name of captured variable declaration cannot be qualified with module selector}}
    main::elem in print(elem)
    // expected-error@-1 {{name of parameter declaration cannot be qualified with module selector}}
  }

  "lll".forEach { (main::elem) in print(elem) }
  // expected-error@-1 {{name of parameter declaration cannot be qualified with module selector}}

  "lll".forEach { (main::elem) -> Void in print(elem) }
  // expected-error@-1 {{name of parameter declaration cannot be qualified with module selector}}

  "lll".forEach { (main::elem: Character) -> Void in print(elem) }
  // expected-error@-1 {{name of parameter declaration cannot be qualified with module selector}}
}
enum main::decl2 {
  // expected-error@-1 {{name of enum declaration cannot be qualified with module selector}}

  case main::decl2a
  // expected-error@-1 {{name of enum 'case' declaration cannot be qualified with module selector}}
}

struct main::decl3 {}
// expected-error@-1 {{name of struct declaration cannot be qualified with module selector}}

class main::decl4<main::T> {}
// expected-error@-1 {{name of class declaration cannot be qualified with module selector}}
// expected-error@-2 {{name of generic parameter declaration cannot be qualified with module selector}}

typealias main::decl5 = main::Bool
// expected-error@-1 {{name of typealias declaration cannot be qualified with module selector}}
// expected-error@-2 {{type 'Bool' is not imported through module 'main'}}
// expected-note@-3 {{did you mean module 'Swift'?}} {{25-29=Swift}}

protocol main::decl6 {
  // expected-error@-1 {{name of protocol declaration cannot be qualified with module selector}}

  associatedtype main::decl6a
  // expected-error@-1 {{name of associatedtype declaration cannot be qualified with module selector}}
}

let main::decl7 = 7
// expected-error@-1 {{name of constant declaration cannot be qualified with module selector}}

var main::decl8 = 8 {
// expected-error@-1 {{name of variable declaration cannot be qualified with module selector}}

  willSet(main::newValue) {}
  // expected-error@-1 {{name of accessor parameter declaration cannot be qualified with module selector}}

  didSet(main::oldValue) {}
  // expected-error@-1 {{name of accessor parameter declaration cannot be qualified with module selector}}
}

struct Parent {
  func main::decl1() {}
  // expected-error@-1 {{name of function declaration cannot be qualified with module selector}}

  enum main::decl2 {
  // expected-error@-1 {{name of enum declaration cannot be qualified with module selector}}

    case main::decl2a
    // expected-error@-1 {{name of enum 'case' declaration cannot be qualified with module selector}}
  }

  struct main::decl3 {}
  // expected-error@-1 {{name of struct declaration cannot be qualified with module selector}}

  class main::decl4 {}
  // expected-error@-1 {{name of class declaration cannot be qualified with module selector}}

  typealias main::decl5 = main::Bool
  // expected-error@-1 {{name of typealias declaration cannot be qualified with module selector}}
  // expected-error@-2 {{type 'Bool' is not imported through module 'main'}}
  // expected-note@-3 {{did you mean module 'Swift'?}} {{27-31=Swift}}
}

@_swift_native_objc_runtime_base(main::BaseClass)
// expected-error@-1 {{Objective-C class name in @_swift_native_objc_runtime_base}}
class C1 {}

infix operator <<<<< : Swift::AdditionPrecedence
// expected-error@-1 {{precedence group specifier cannot be qualified with module selector}}

precedencegroup main::PG1 {
// expected-error@-1 {{name of precedence group declaration cannot be qualified with module selector}}

  higherThan: Swift::AdditionPrecedence
  // expected-error@-1 {{precedence group specifier cannot be qualified with module selector}}
}

func badModuleNames() {
  NonexistentModule::print()
  // expected-error@-1 {{declaration 'print' is not imported through module 'NonexistentModule'}}
  // expected-note@-2 {{did you mean module 'Swift'?}} {{3-20=Swift}}
  // FIXME redundant: expected-note@-3  {{did you mean module 'Swift'?}}

  _ = "foo".NonexistentModule::count
  // expected-error@-1 {{declaration 'count' is not imported through module 'NonexistentModule'}}
  // expected-note@-2 {{did you mean module 'Swift'?}} {{13-30=Swift}}

  let x: NonexistentModule::MyType = NonexistentModule::MyType()
  // expected-error@-1 {{cannot find type 'NonexistentModule::MyType' in scope}}

  let y: A.NonexistentModule::MyChildType = fatalError()
  // expected-error@-1 {{'NonexistentModule::MyChildType' is not a member type of struct 'ModuleSelectorTestingKit.A'}}
}

@_spi(main::Private)
// expected-error@-1 {{name of SPI group declaration cannot be qualified with module selector}} {{7-13=}}
public struct BadImplementsAttr: CustomStringConvertible {
  @_implements(CustomStringConvertible, Swift::description)
  // expected-error@-1 {{name cannot be qualified with module selector here}} {{41-48=}}
  public var stringValue: String { fatalError() }

  @_specialize(spi: main::Private, where T == Swift::Int)
  // expected-error@-1 {{name of SPI group declaration cannot be qualified with module selector}} {{21-27=}}
  public func fn<T>() -> T { fatalError() }
}
