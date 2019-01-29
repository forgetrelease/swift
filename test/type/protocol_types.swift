// RUN: %target-typecheck-verify-swift

protocol HasSelfRequirements {
  func foo(_ x: Self)

  func returnsOwnProtocol() -> HasSelfRequirements // expected-error{{protocol 'HasSelfRequirements' can only be used as a generic constraint because it has Self or associated type requirements}}
}
protocol Bar {
  // init() methods should not prevent use as an existential.
  init()

  func bar() -> Bar
}

func useBarAsType(_ x: Bar) {}

protocol Pub : Bar { }

func refinementErasure(_ p: Pub) {
  useBarAsType(p)
}

typealias Compo = HasSelfRequirements & Bar

struct CompoAssocType {
  typealias Compo = HasSelfRequirements & Bar
}

func useAsRequirement<T: HasSelfRequirements>(_ x: T) { }
func useCompoAsRequirement<T: HasSelfRequirements & Bar>(_ x: T) { }
func useCompoAliasAsRequirement<T: Compo>(_ x: T) { }
func useNestedCompoAliasAsRequirement<T: CompoAssocType.Compo>(_ x: T) { }

func useAsWhereRequirement<T>(_ x: T) where T: HasSelfRequirements {}
func useCompoAsWhereRequirement<T>(_ x: T) where T: HasSelfRequirements & Bar {}
func useCompoAliasAsWhereRequirement<T>(_ x: T) where T: Compo {}
func useNestedCompoAliasAsWhereRequirement<T>(_ x: T) where T: CompoAssocType.Compo {}

func useAsType(_ x: HasSelfRequirements) { } // expected-error{{protocol 'HasSelfRequirements' can only be used as a generic constraint}}
func useCompoAsType(_ x: HasSelfRequirements & Bar) { } // expected-error{{protocol 'HasSelfRequirements' can only be used as a generic constraint}}
func useCompoAliasAsType(_ x: Compo) { } // expected-error{{protocol 'HasSelfRequirements' can only be used as a generic constraint}}
func useNestedCompoAliasAsType(_ x: CompoAssocType.Compo) { } // expected-error{{protocol 'HasSelfRequirements' can only be used as a generic constraint}}

struct TypeRequirement<T: HasSelfRequirements> {}
struct CompoTypeRequirement<T: HasSelfRequirements & Bar> {}
struct CompoAliasTypeRequirement<T: Compo> {}
struct NestedCompoAliasTypeRequirement<T: CompoAssocType.Compo> {}

struct CompoTypeWhereRequirement<T> where T: HasSelfRequirements & Bar {}
struct CompoAliasTypeWhereRequirement<T> where T: Compo {}
struct NestedCompoAliasTypeWhereRequirement<T> where T: CompoAssocType.Compo {}

struct Struct1<T> { }
struct Struct2<T : Pub & Bar> { }
struct Struct3<T : Pub & Bar & P3> { } // expected-error {{use of undeclared type 'P3'}}
struct Struct4<T> where T : Pub & Bar {}

struct Struct5<T : protocol<Pub, Bar>> { } // expected-error {{'protocol<...>' composition syntax has been removed; join the protocols using '&'}}
struct Struct6<T> where T : protocol<Pub, Bar> {} // expected-error {{'protocol<...>' composition syntax has been removed; join the protocols using '&'}}

typealias T1 = Pub & Bar
typealias T2 = protocol<Pub , Bar> // expected-error {{'protocol<...>' composition syntax has been removed; join the protocols using '&'}}

// rdar://problem/20593294
protocol HasAssoc {
  associatedtype Assoc
  func foo()
}

func testHasAssoc(_ x: Any) {
  if let p = x as? HasAssoc { // expected-error {{protocol 'HasAssoc' can only be used as a generic constraint}}
    p.foo() // don't crash here.
  }
}

// rdar://problem/16803384
protocol InheritsAssoc : HasAssoc {
  func silverSpoon()
}

func testInheritsAssoc(_ x: InheritsAssoc) { // expected-error {{protocol 'InheritsAssoc' can only be used as a generic constraint}}
  x.silverSpoon()
}

// SR-38
var b: HasAssoc // expected-error {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}

// Further generic constraint error testing - typealias used inside statements
protocol P {}
typealias MoreHasAssoc = HasAssoc & P
func testHasMoreAssoc(_ x: Any) {
  if let p = x as? MoreHasAssoc { // expected-error {{protocol 'HasAssoc' can only be used as a generic constraint}}
    p.foo() // don't crash here.
  }
}

struct Outer {
  typealias Any = Int // expected-error {{keyword 'Any' cannot be used as an identifier here}} expected-note {{if this name is unavoidable, use backticks to escape it}} {{13-16=`Any`}}
  typealias `Any` = Int
  static func aa(a: `Any`) -> Int { return a }
}

typealias X = Struct1<Pub & Bar>
_ = Struct1<Pub & Bar>.self

typealias BadAlias<T> = T
where T : HasAssoc, T.Assoc == HasAssoc
// expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}

struct BadStruct<T>
where T : HasAssoc,
      T.Assoc == HasAssoc {}
// expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}

protocol BadProtocol where T == HasAssoc {
  // expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}
  associatedtype T

  associatedtype U : HasAssoc
    where U.Assoc == HasAssoc
  // expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}
}

extension HasAssoc where Assoc == HasAssoc {}
// expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}

func badFunction<T>(_: T)
where T : HasAssoc,
      T.Assoc == HasAssoc {}
// expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}

struct BadSubscript {
  subscript<T>(_: T) -> Int
  where T : HasAssoc,
        T.Assoc == HasAssoc {
    // expected-error@-1 {{protocol 'HasAssoc' can only be used as a generic constraint because it has Self or associated type requirements}}
    get {}
    set {}
  }
}


protocol TrivialProto {}
class TrivialClass {}

protocol ProtAssocHasSelf {
  associatedtype Assoc
  func unsupportedSelfWeirdReturnTy(arg: Self) -> ([Assoc?]) -> ()
}

protocol ProtAssocConcreteHasSelf: ProtAssocHasSelf where Assoc == Bool {}

protocol ProtAssoc {
  associatedtype Assoc
  func foo(arg: Assoc) -> Assoc
}
protocol ProtAssocInt: ProtAssoc where Assoc == Int {}

protocol ProtBssoc: ProtAssocInt {
  associatedtype Bssoc
  func supportedSelf(arg: Bssoc) -> Self
}
protocol ProtAssocBssocConcrete: ProtBssoc where Bssoc == Assoc.Magnitude {}

protocol ProtAssoc2 {
  associatedtype Assoc
  func bar(arg: Assoc)
}
protocol ProtMergeAssocInt: ProtAssocInt, ProtAssoc2 {}

func testExistential1(arg: ProtAssocInt) {} // Ok
func testExistential2(arg: ProtAssocBssocConcrete) {} // Ok
func testExistential3(arg: ProtMergeAssocInt) {} // Ok

func testExistential4(arg: ProtAssocConcreteHasSelf) {}
// expected-error@-1 {{protocol 'ProtAssocConcreteHasSelf' can only be used}}

// Test various edge cases and expressions.
class Conforming: EdgeCase1, EdgeCase2 {
  typealias Assoc = Conforming

  func simpleAliasToAssoc(arg: SimpleAlias) -> Assoc { return arg }
}
protocol EdgeCase1 {
  associatedtype Assoc: EdgeCase1
}
protocol EdgeCaseSub1: EdgeCase1 where Assoc.Assoc == Conforming {}

protocol EdgeCase2 {
  associatedtype Assoc: EdgeCase2 where Assoc == Assoc.Assoc
  typealias SimpleAlias = Assoc.Assoc.Assoc
  typealias ComplexAlias = ([Assoc?]) -> Assoc.Assoc

  func simpleAliasToAssoc(arg: SimpleAlias) -> Assoc
}
protocol EdgeCaseSub2: EdgeCase2 where Assoc.Assoc == Conforming {}

func testExistential11(arg: EdgeCaseSub1) {}
// expected-error@-1 {{protocol 'EdgeCaseSub1' can only be used}}
func testExistential12(arg1: EdgeCaseSub2) {

  let _: Conforming = arg1.simpleAliasToAssoc(arg: Conforming())
}
