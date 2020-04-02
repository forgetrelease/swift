// RUN: %target-typecheck-verify-swift

protocol SomeProtocol {
	associatedtype T
}

extension SomeProtocol where T == Optional<T> { } // expected-error{{same-type constraint 'Self.T' == 'Optional<Self.T>' is recursive}}

// rdar://problem/19840527

class X<T> where T == X { // expected-error{{same-type constraint 'T' == 'X<T>' is recursive}}
// expected-error@-1{{same-type requirement makes generic parameter 'T' non-generic}}
    var type: T { return Swift.type(of: self) } // expected-error{{cannot convert return expression of type 'X<T>.Type' to return type 'T'}}
}

// FIXME: The "associated type 'Foo' is not a member type of 'Self'" diagnostic
// should also become "associated type 'Foo' references itself"
protocol CircularAssocTypeDefault {
  associatedtype Z = Z // expected-error{{associated type 'Z' references itself}}
  // expected-note@-1{{type declared here}}
  // expected-note@-2{{protocol requires nested type 'Z'; do you want to add it?}}

  associatedtype Z2 = Z3
  // expected-note@-1{{protocol requires nested type 'Z2'; do you want to add it?}}
  associatedtype Z3 = Z2
  // expected-note@-1{{protocol requires nested type 'Z3'; do you want to add it?}}

  associatedtype Z4 = Self.Z4 // expected-error{{associated type 'Z4' references itself}}
  // expected-note@-1{{type declared here}}
  // expected-note@-2{{protocol requires nested type 'Z4'; do you want to add it?}}

  associatedtype Z5 = Self.Z6
  // expected-note@-1{{protocol requires nested type 'Z5'; do you want to add it?}}
  associatedtype Z6 = Self.Z5
  // expected-note@-1{{protocol requires nested type 'Z6'; do you want to add it?}}
}

struct ConformsToCircularAssocTypeDefault : CircularAssocTypeDefault { }
// expected-error@-1 {{type 'ConformsToCircularAssocTypeDefault' does not conform to protocol 'CircularAssocTypeDefault'}}

// rdar://problem/20000145
public protocol P {
  associatedtype T // expected-note {{protocol requires nested type 'T'; do you want to add it?}}
}

// Used to cause a circularity issue during gen. signature validation
public struct S<A: P> where A.T == S<A> {
// expected-note@-1 {{requirement specified as 'A.T' == 'S<A>' [with A = InvalidSubstForS1]}}
  func f(a: A.T) {
    g(a: id(t: a))
    _ = A.T.self
  }

  func g(a: S<A>) {
    f(a: id(t: a))
    _ = S<A>.self
  }

  func id<T>(t: T) -> T {
    return t
  }
}

struct SubstitutionForS: P { // OK
  typealias T = S<SubstitutionForS>
}
struct InvalidSubstForS1: P {
  typealias T = S<InvalidSubstForS2>
}
struct InvalidSubstForS2: P { // expected-error {{type 'InvalidSubstForS2' does not conform to protocol 'P'}}
  typealias T = S<InvalidSubstForS1>
  // expected-error@-1 {{'S' requires the types 'InvalidSubstForS1.T' (aka 'S<InvalidSubstForS2>') and 'S<InvalidSubstForS1>' be equivalent}}
}

protocol I {
  init()
}

protocol PI {
  associatedtype T : I //expected-note {{protocol requires nested type 'T'; do you want to add it?}}
}

// Used to cause a circularity issue during gen. signature validation
struct SI<A: PI> : I where A : I, A.T == SI<A> {
// expected-note@-1 {{requirement specified as 'A.T' == 'SI<A>' [with A = InvalidSubstForSI1]}}
  func ggg<T : I>(t: T.Type) -> T {
    return T()
  }

  func foo() {
    _ = A()

    _ = A.T()
    _ = SI<A>()

    _ = ggg(t: A.self)
    _ = ggg(t: A.T.self)

    _ = self.ggg(t: A.self)
    _ = self.ggg(t: A.T.self)
  }
}

struct SubstitutionForSI: PI, I {
  typealias T = SI<SubstitutionForSI> // OK
}
struct InvalidSubstForSI1: PI, I {
  typealias T = SI<InvalidSubstForSI2>
}
struct InvalidSubstForSI2: PI, I { // expected-error {{type 'InvalidSubstForSI2' does not conform to protocol 'PI'}}
  typealias T = SI<InvalidSubstForSI1>
  // expected-error@-1 {{'SI' requires the types 'InvalidSubstForSI1.T' (aka 'SI<InvalidSubstForSI2>') and 'SI<InvalidSubstForSI1>' be equivalent}}
}

// Used to hit infinite recursion
struct S4<A: PI> : I where A : I {
}

struct S5<A: PI> : I where A : I, A.T == S4<A> { }

// Used to hit ArchetypeBuilder assertions
struct SU<A: P> where A.T == SU {
}

struct SIU<A: PI> : I where A : I, A.T == SIU {
}
