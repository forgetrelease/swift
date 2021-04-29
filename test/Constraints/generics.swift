// RUN: %target-typecheck-verify-swift -enable-objc-interop

infix operator +++

protocol ConcatToAnything { // expected-note {{where 'Self' = 'U'}}
  static func +++ <T>(lhs: Self, other: T)
}

func min<T : Comparable>(_ x: T, y: T) -> T {
  if y < x { return y }
  return x
}

func weirdConcat<T : ConcatToAnything, U>(_ t: T, u: U) {
  t +++ u
  t +++ 1
  u +++ t // expected-error{{referencing operator function '+++' on 'ConcatToAnything' requires that 'U' conform to 'ConcatToAnything'}}
}

// Make sure that the protocol operators don't get in the way.
var b1, b2 : Bool
_ = b1 != b2

extension UnicodeScalar {
  func isAlpha2() -> Bool {
    return (self >= "A" && self <= "Z") || (self >= "a" && self <= "z")
  }
}

protocol P {
  static func foo(_ arg: Self) -> Self
}
struct S : P {
  static func foo(_ arg: S) -> S {
    return arg
  }
}

func foo<T : P>(_ arg: T) -> T {
  return T.foo(arg)
}

// Associated types and metatypes
protocol SomeProtocol {
  associatedtype SomeAssociated
}

func generic_metatypes<T : SomeProtocol>(_ x: T)
  -> (T.Type, T.SomeAssociated.Type)
{
  return (type(of: x), type(of: x).SomeAssociated.self)
}

// Inferring a variable's type from a call to a generic.
struct Pair<T, U> { } // expected-note 3 {{'T' declared as parameter to type 'Pair'}} expected-note 3 {{'U' declared as parameter to type 'Pair'}}

func pair<T, U>(_ x: T, _ y: U) -> Pair<T, U> { }

var i : Int, f : Float
var p = pair(i, f)

// Conformance constraints on static variables.
func f1<S1 : Sequence>(_ s1: S1) {}
var x : Array<Int> = [1]
f1(x)

// Inheritance involving generics and non-generics.
class X {
  func f() {}
}

class Foo<T> : X { 
  func g() { }
}

class Y<U> : Foo<Int> {
}

func genericAndNongenericBases(_ x: Foo<Int>, y: Y<()>) {
  x.f()
  y.f()
  y.g()
}

func genericAndNongenericBasesTypeParameter<T : Y<()>>(_ t: T) {
  t.f()
  t.g()
}

protocol P1 {}
protocol P2 {}

func foo<T : P1>(_ t: T) -> P2 {
  return t // expected-error{{return expression of type 'T' does not conform to 'P2'}}
}

func foo2(_ p1: P1) -> P2 {
  return p1 // expected-error{{return expression of type 'P1' does not conform to 'P2'}}
}

// <rdar://problem/14005696>
protocol BinaryMethodWorkaround {
  associatedtype MySelf
}

protocol Squigglable : BinaryMethodWorkaround {
}

infix operator ~~~

func ~~~ <T : Squigglable>(lhs: T, rhs: T) -> Bool where T.MySelf == T {
  return true
}

extension UInt8 : Squigglable {
  typealias MySelf = UInt8
}

var rdar14005696 : UInt8
_ = rdar14005696 ~~~ 5

// <rdar://problem/15168483>
public struct SomeIterator<C: Collection, Indices: Sequence>
  : IteratorProtocol, Sequence
  where C.Index == Indices.Iterator.Element {
  var seq : C
  var indices : Indices.Iterator

  public typealias Element = C.Iterator.Element

  public mutating func next() -> Element? {
    fatalError()
  }

  public init(elements: C, indices: Indices) {
    fatalError()
  }
}
func f1<T>(seq: Array<T>) {
  let x = (seq.indices).lazy.reversed()
  SomeIterator(elements: seq, indices: x) // expected-warning{{unused}}
  SomeIterator(elements: seq, indices: seq.indices.reversed()) // expected-warning{{unused}}
}


// <rdar://problem/16078944>
func count16078944<T>(_ x: Range<T>) -> Int { return 0 }

func test16078944 <T: Comparable>(lhs: T, args: T) -> Int {
  return count16078944(lhs..<args) // don't crash
}


// <rdar://problem/22409190> QoI: Passing unsigned integer to ManagedBuffer elements.destroy()
class r22409190ManagedBuffer<Value, Element> {
  final var value: Value { get {} set {}}
  func withUnsafeMutablePointerToElements<R>(
    _ body: (UnsafeMutablePointer<Element>) -> R) -> R {
  }
}
class MyArrayBuffer<Element>: r22409190ManagedBuffer<UInt, Element> {
  deinit {
    self.withUnsafeMutablePointerToElements { elems -> Void in
      elems.deinitialize(count: self.value)  // expected-error {{cannot convert value of type 'UInt' to expected argument type 'Int'}}
    }
  }
}

// <rdar://problem/22459135> error: 'print' is unavailable: Please wrap your tuple argument in parentheses: 'print((...))'
func r22459135() {
  func h<S : Sequence>(_ sequence: S) -> S.Iterator.Element
    where S.Iterator.Element : FixedWidthInteger {
    return 0
  }

  func g(_ x: Any) {}
  func f(_ x: Int) {
    g(h([3]))
  }

  func f2<TargetType: AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> ()) {
    let _: (AnyObject) -> () = { internalTarget in
      handler(internalTarget as! TargetType)
    }
  }
}


// <rdar://problem/19710848> QoI: Friendlier error message for "[] as Set"
// <rdar://problem/22326930> QoI: "argument for generic parameter 'Element' could not be inferred" lacks context
_ = [] as Set  // expected-error {{protocol 'Any' as a type cannot conform to 'Hashable'}} expected-note {{only concrete types such as structs, enums and classes can conform to protocols}}
// expected-note@-1 {{required by generic struct 'Set' where 'Element' = 'Any'}}


//<rdar://problem/22509125> QoI: Error when unable to infer generic archetype lacks greatness
func r22509125<T>(_ a : T?) { // expected-note {{in call to function 'r22509125'}}
  r22509125(nil) // expected-error {{generic parameter 'T' could not be inferred}}
}


// <rdar://problem/24267414> QoI: error: cannot convert value of type 'Int' to specified type 'Int'
struct R24267414<T> {  // expected-note {{'T' declared as parameter to type 'R24267414'}}
  static func foo() -> Int {}
}
var _ : Int = R24267414.foo() // expected-error {{generic parameter 'T' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{24-24=<Any>}}


// https://bugs.swift.org/browse/SR-599
func SR599<T: FixedWidthInteger>() -> T.Type { return T.self }  // expected-note {{in call to function 'SR599()'}}
_ = SR599()         // expected-error {{generic parameter 'T' could not be inferred}}




// <rdar://problem/19215114> QoI: Poor diagnostic when we are unable to infer type
protocol Q19215114 {}
protocol P19215114 {}

// expected-note @+1 {{in call to function 'body9215114'}}
func body9215114<T: P19215114, U: Q19215114>(_ t: T) -> (_ u: U) -> () {}

func test9215114<T: P19215114, U: Q19215114>(_ t: T) -> (U) -> () {
  let f = body9215114(t)  // expected-error {{generic parameter 'U' could not be inferred}}
  return f
}

// <rdar://problem/21718970> QoI: [uninferred generic param] cannot invoke 'foo' with an argument list of type '(Int)'
class Whatever<A: Numeric, B: Numeric> {  // expected-note 2 {{'A' declared as parameter to type 'Whatever'}} expected-note {{'B' declared as parameter to type 'Whatever'}}
  static func foo(a: B) {}
  
  static func bar() {}

}
Whatever.foo(a: 23) // expected-error {{generic parameter 'A' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{9-9=<<#A: Numeric#>, Int>}}

// <rdar://problem/21718955> Swift useless error: cannot invoke 'foo' with no arguments
Whatever.bar()  // expected-error {{generic parameter 'A' could not be inferred}} expected-note 1 {{explicitly specify the generic arguments to fix this issue}} {{9-9=<<#A: Numeric#>, <#B: Numeric#>>}}
// expected-error@-1 {{generic parameter 'B' could not be inferred}}

// <rdar://problem/27515965> Type checker doesn't enforce same-type constraint if associated type is Any
protocol P27515965 {
  associatedtype R
  func f() -> R
}

struct S27515965 : P27515965 {
  func f() -> Any { return self }
}

struct V27515965 {
  init<T : P27515965>(_ tp: T) where T.R == Float {}
  // expected-note@-1 {{where 'T.R' = 'Any'}}
}

func test(x: S27515965) -> V27515965 {
  return V27515965(x)
  // expected-error@-1 {{initializer 'init(_:)' requires the types 'Any' and 'Float' be equivalent}}
}

protocol BaseProto {}
protocol SubProto: BaseProto {}
@objc protocol NSCopyish {
  func copy() -> Any
}

struct FullyGeneric<Foo> {} // expected-note 13 {{'Foo' declared as parameter to type 'FullyGeneric'}} expected-note 1 {{generic type 'FullyGeneric' declared here}}

struct AnyClassBound<Foo: AnyObject> {} // expected-note {{'Foo' declared as parameter to type 'AnyClassBound'}} expected-note {{generic type 'AnyClassBound' declared here}}
// expected-note@-1{{requirement specified as 'Foo' : 'AnyObject'}}
struct AnyClassBound2<Foo> where Foo: AnyObject {} // expected-note {{'Foo' declared as parameter to type 'AnyClassBound2'}}
// expected-note@-1{{requirement specified as 'Foo' : 'AnyObject' [with Foo = Any]}}

struct ProtoBound<Foo: SubProto> {} // expected-note {{'Foo' declared as parameter to type 'ProtoBound'}} expected-note {{generic type 'ProtoBound' declared here}}
struct ProtoBound2<Foo> where Foo: SubProto {} // expected-note {{'Foo' declared as parameter to type 'ProtoBound2'}}

struct ObjCProtoBound<Foo: NSCopyish> {} // expected-note {{'Foo' declared as parameter to type 'ObjCProtoBound'}} expected-note {{generic type 'ObjCProtoBound' declared here}}
struct ObjCProtoBound2<Foo> where Foo: NSCopyish {} // expected-note {{'Foo' declared as parameter to type 'ObjCProtoBound2'}}

struct ClassBound<Foo: X> {} // expected-note {{generic type 'ClassBound' declared here}}
struct ClassBound2<Foo> where Foo: X {} // expected-note {{generic type 'ClassBound2' declared here}}

struct ProtosBound<Foo> where Foo: SubProto & NSCopyish {} // expected-note {{'Foo' declared as parameter to type 'ProtosBound'}} expected-note {{generic type 'ProtosBound' declared here}}
struct ProtosBound2<Foo: SubProto & NSCopyish> {} // expected-note {{'Foo' declared as parameter to type 'ProtosBound2'}}
struct ProtosBound3<Foo: SubProto> where Foo: NSCopyish {} // expected-note {{'Foo' declared as parameter to type 'ProtosBound3'}}

struct AnyClassAndProtoBound<Foo> where Foo: AnyObject, Foo: SubProto {} // expected-note {{'Foo' declared as parameter to type 'AnyClassAndProtoBound'}}
struct AnyClassAndProtoBound2<Foo> where Foo: SubProto, Foo: AnyObject {} // expected-note {{'Foo' declared as parameter to type 'AnyClassAndProtoBound2'}}

struct ClassAndProtoBound<Foo> where Foo: X, Foo: SubProto {} // expected-note {{where 'Foo' = 'X'}}

struct ClassAndProtosBound<Foo> where Foo: X, Foo: SubProto, Foo: NSCopyish {} // expected-note 2 {{where 'Foo' = 'X'}}
struct ClassAndProtosBound2<Foo> where Foo: X, Foo: SubProto & NSCopyish {} // expected-note 2 {{where 'Foo' = 'X'}}

extension Pair {
  init(first: T) {}
  init(second: U) {}

  var first: T { fatalError() }
  var second: U { fatalError() }
}

func testFixIts() {
  _ = FullyGeneric() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{19-19=<Any>}}
  _ = FullyGeneric<Any>()

  _ = AnyClassBound() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{20-20=<AnyObject>}}
  _ = AnyClassBound<Any>() // expected-error {{'AnyClassBound' requires that 'Any' be a class type}}
  _ = AnyClassBound<AnyObject>()

  _ = AnyClassBound2() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{21-21=<AnyObject>}}
  _ = AnyClassBound2<Any>() // expected-error {{'AnyClassBound2' requires that 'Any' be a class type}}
  _ = AnyClassBound2<AnyObject>()

  _ = ProtoBound() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{17-17=<<#Foo: SubProto#>>}}
  _ = ProtoBound<Any>() // expected-error {{type 'Any' does not conform to protocol 'SubProto'}}

  _ = ProtoBound2() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{18-18=<<#Foo: SubProto#>>}}
  _ = ProtoBound2<Any>() // expected-error {{type 'Any' does not conform to protocol 'SubProto'}}

  _ = ObjCProtoBound() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{21-21=<NSCopyish>}}
  _ = ObjCProtoBound<AnyObject>() // expected-error {{type 'AnyObject' does not conform to protocol 'NSCopyish'}}
  _ = ObjCProtoBound<NSCopyish>()

  _ = ObjCProtoBound2() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{22-22=<NSCopyish>}}
  _ = ObjCProtoBound2<AnyObject>() // expected-error {{type 'AnyObject' does not conform to protocol 'NSCopyish'}}
  _ = ObjCProtoBound2<NSCopyish>()

  _ = ProtosBound() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{18-18=<<#Foo: NSCopyish & SubProto#>>}}
  _ = ProtosBound2() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{19-19=<<#Foo: NSCopyish & SubProto#>>}}
  _ = ProtosBound3() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{19-19=<<#Foo: NSCopyish & SubProto#>>}}

  _ = AnyClassAndProtoBound() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{28-28=<<#Foo: SubProto & AnyObject#>>}}
  _ = AnyClassAndProtoBound2() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{29-29=<<#Foo: SubProto & AnyObject#>>}}

  _ = ClassAndProtoBound() // expected-error {{generic struct 'ClassAndProtoBound' requires that 'X' conform to 'SubProto'}}

  _ = ClassAndProtosBound()
  // expected-error@-1 {{generic struct 'ClassAndProtosBound' requires that 'X' conform to 'SubProto'}}
  // expected-error@-2 {{generic struct 'ClassAndProtosBound' requires that 'X' conform to 'NSCopyish'}}
  _ = ClassAndProtosBound2()
  // expected-error@-1 {{generic struct 'ClassAndProtosBound2' requires that 'X' conform to 'SubProto'}}
  // expected-error@-2 {{generic struct 'ClassAndProtosBound2' requires that 'X' conform to 'NSCopyish'}}

  _ = Pair()
  // expected-error@-1 {{generic parameter 'T' could not be inferred}}
  // expected-error@-2 {{generic parameter 'U' could not be inferred}}
  // expected-note@-3 {{explicitly specify the generic arguments to fix this issue}} {{11-11=<Any, Any>}}
  _ = Pair(first: S()) // expected-error {{generic parameter 'U' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{11-11=<S, Any>}}
  _ = Pair(second: S()) // expected-error {{generic parameter 'T' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{11-11=<Any, S>}}
}

func testFixItClassBound() {
  // We infer a single class bound for simple cases in expressions...
  let x = ClassBound()
  let x1: String = x // expected-error {{cannot convert value of type 'ClassBound<X>' to specified type 'String'}}

  let y = ClassBound2()
  let y1: String = y // expected-error {{cannot convert value of type 'ClassBound2<X>' to specified type 'String'}}

  // ...but not in types.
  let z1: ClassBound // expected-error {{reference to generic type 'ClassBound' requires arguments in <...>}} {{21-21=<X>}}
  let z2: ClassBound2 // expected-error {{reference to generic type 'ClassBound2' requires arguments in <...>}} {{22-22=<X>}}
}

func testFixItCasting(x: Any) {
  _ = x as! FullyGeneric // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{25-25=<Any>}}
}

func testFixItContextualKnowledge() {
  // FIXME: These could propagate backwards.
  let _: Int = Pair().first // expected-error {{generic parameter 'U' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{20-20=<Int, Any>}}
  let _: Int = Pair().second // expected-error {{generic parameter 'T' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{20-20=<Any, Int>}}
}

func testFixItTypePosition() {
  let _: FullyGeneric // expected-error {{reference to generic type 'FullyGeneric' requires arguments in <...>}} {{22-22=<Any>}}
  let _: ProtoBound // expected-error {{reference to generic type 'ProtoBound' requires arguments in <...>}} {{20-20=<<#Foo: SubProto#>>}}
  let _: ObjCProtoBound // expected-error {{reference to generic type 'ObjCProtoBound' requires arguments in <...>}} {{24-24=<NSCopyish>}}
  let _: AnyClassBound // expected-error {{reference to generic type 'AnyClassBound' requires arguments in <...>}} {{23-23=<AnyObject>}}
  let _: ProtosBound // expected-error {{reference to generic type 'ProtosBound' requires arguments in <...>}} {{21-21=<<#Foo: NSCopyish & SubProto#>>}}
}

func testFixItNested() {
  _ = Array<FullyGeneric>() // expected-error {{generic parameter 'Foo' could not be inferred}}
  // expected-note@-1 {{explicitly specify the generic arguments to fix this issue}} {{25-25=<Any>}}
  _ = [FullyGeneric]() // expected-error {{generic parameter 'Foo' could not be inferred}} expected-note {{explicitly specify the generic arguments to fix this issue}} {{20-20=<Any>}}

  _ = FullyGeneric<FullyGeneric>() // expected-error {{generic parameter 'Foo' could not be inferred}}
  // expected-note@-1 {{explicitly specify the generic arguments to fix this issue}} {{32-32=<Any>}}

  _ = Pair<
    FullyGeneric,
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
    FullyGeneric
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  >()
  _ = Pair<
    FullyGeneric<Any>,
    FullyGeneric
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  >()
  _ = Pair<
    FullyGeneric,
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
    FullyGeneric<Any>
  >()

  _ = pair(
    FullyGeneric(),
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
    FullyGeneric()
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  )
  _ = pair(
    FullyGeneric<Any>(),
    FullyGeneric()
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  )
  _ = pair(
    FullyGeneric(),
    // expected-error@-1 {{generic parameter 'Foo' could not be inferred}}
    // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
    FullyGeneric<Any>()
  )
}

// rdar://problem/26845038
func occursCheck26845038(a: [Int]) {
  _ = Array(a)[0]
}

// rdar://problem/29633747
extension Array where Element: Hashable {
    public func trimmed(_ elements: [Element]) -> SubSequence {
        return []
    }
}

func rdar29633747(characters: String) {
  let _ = Array(characters).trimmed(["("])
}

// Null pointer dereference in noteArchetypeSource()
class GenericClass<A> {}
// expected-note@-1 {{'A' declared as parameter to type 'GenericClass'}}

func genericFunc<T>(t: T) {
  _ = [T: GenericClass] // expected-error {{generic parameter 'A' could not be inferred}}
  // expected-note@-1 {{explicitly specify the generic arguments to fix this issue}}
}

struct SR_3525<T> {}
func sr3525_arg_int(_: inout SR_3525<Int>) {}
func sr3525_arg_gen<T>(_: inout SR_3525<T>) {}
func sr3525_1(t: SR_3525<Int>) {
  let _ = sr3525_arg_int(&t) // expected-error {{cannot pass immutable value as inout argument: 't' is a 'let' constant}}
}
func sr3525_2(t: SR_3525<Int>) {
  let _ = sr3525_arg_gen(&t) // expected-error {{cannot pass immutable value as inout argument: 't' is a 'let' constant}}
}
func sr3525_3<T>(t: SR_3525<T>) {
  let _ = sr3525_arg_gen(&t) // expected-error {{cannot pass immutable value as inout argument: 't' is a 'let' constant}}
}

class testStdlibType {
  let _: Array // expected-error {{reference to generic type 'Array' requires arguments in <...>}} {{15-15=<Any>}}
}

// rdar://problem/32697033
protocol P3 {
    associatedtype InnerAssoc
}

protocol P4 {
    associatedtype OuterAssoc: P3
}

struct S3 : P3 {
  typealias InnerAssoc = S4
}

struct S4: P4 {
  typealias OuterAssoc = S3
}

public struct S5 {
    func f<Model: P4, MO> (models: [Model])
        where Model.OuterAssoc == MO, MO.InnerAssoc == Model {
    }

    func g<MO, Model: P4> (models: [Model])
        where Model.OuterAssoc == MO, MO.InnerAssoc == Model {
    }

    func f(arr: [S4]) {
        f(models: arr)
        g(models: arr)
    }
}

// rdar://problem/24329052 - QoI: call argument archetypes not lining up leads to ambiguity errors

struct S_24329052<T> { // expected-note {{generic parameter 'T' of generic struct 'S_24329052' declared here}}
  var foo: (T) -> Void
  // expected-note@+1 {{generic parameter 'T' of instance method 'bar(_:)' declared here}}
  func bar<T>(_ v: T) { foo(v) }
  // expected-error@-1 {{cannot convert value of type 'T' (generic parameter of instance method 'bar(_:)') to expected argument type 'T' (generic parameter of generic struct 'S_24329052')}}
}

extension Sequence {
  var rdar24329052: (Element) -> Void { fatalError() }
  // expected-note@+1 {{generic parameter 'Element' of instance method 'foo24329052(_:)' declared here}}
  func foo24329052<Element>(_ v: Element) { rdar24329052(v) }
  // expected-error@-1 {{cannot convert value of type 'Element' (generic parameter of instance method 'foo24329052(_:)') to expected argument type 'Self.Element' (associated type of protocol 'Sequence')}}
}

func rdar27700622<E: Comparable>(_ input: [E]) -> [E] {
  let pivot = input.first!
  let lhs = input.dropFirst().filter { $0 <= pivot }
  let rhs = input.dropFirst().filter { $0 > pivot }

  return rdar27700622(lhs) + [pivot] + rdar27700622(rhs) // Ok
}

// rdar://problem/22898292 - Type inference failure with constrained subclass
protocol P_22898292 {}

do {
  func construct_generic<T: P_22898292>(_ construct: () -> T) -> T { return construct() }

  class A {}
  class B : A, P_22898292 {}

  func foo() -> B { return B() }
  func bar(_ value: A) {}
  func baz<T: A>(_ value: T) {}

  func rdar_22898292_1() {
    let x = construct_generic { foo() } // returns A
    bar(x) // Ok
    bar(construct_generic { foo() }) // Ok
  }

  func rdar22898292_2<T: B>(_ d: T) {
    _ = { baz($0) }(construct_generic { d }) // Ok
  }
}

// rdar://problem/35541153 - Generic parameter inference bug

func rdar35541153() {
  func foo<U: Equatable, V: Equatable, C: Collection>(_ c: C) where C.Element == (U, V) {}
  func bar<K: Equatable, V, C: Collection>(_ c: C, _ k: K, _ v: V) where C.Element == (K, V) {}

  let x: [(a: Int, b: Int)] = []
  let y: [(k: String, v: Int)] = []

  foo(x) // Ok
  bar(y, "ultimate question", 42) // Ok
}

// rdar://problem/38159133 - [SR-7125]: Swift 4.1 Xcode 9.3b4 regression

protocol P_38159133 {}

do {
  class Super {}
  class A: Super, P_38159133 {}
  class B: Super, P_38159133 {}

  func rdar38159133(_ a: A?, _ b: B?) {
    let _: [P_38159133] = [a, b].compactMap { $0 } // Ok
  }
}

func rdar35890334(_ arr: inout [Int]) {
  _ = arr.popFirst() // expected-error {{referencing instance method 'popFirst()' on 'Collection' requires the types '[Int]' and 'ArraySlice<Int>' be equivalent}}
}

// rdar://problem/39616039

func rdar39616039() {
  func foo<V>(default: V, _ values: [String: V]) -> V {
    return values["foo"] ?? `default`
  }

  var a = foo(default: 42, ["foo": 0])
  a += 1 // ok

  var b = foo(default: 42.0, ["foo": 0])
  b += 1 // ok

  var c = foo(default: 42.0, ["foo": Float(0)])
  c += 1 // ok
}

// https://bugs.swift.org/browse/SR-8075

func sr8075() {
  struct UIFont {
    init(ofSize: Float) {}
  }

  func switchOnCategory<T>(_ categoryToValue: [Int: T]) -> T {
    fatalError()
  }

  let _: UIFont = .init(ofSize: switchOnCategory([0: 15.5, 1: 20.5]))
}

// rdar://problem/40537858 - Ambiguous diagnostic when type is missing conformance
func rdar40537858() {
  struct S {
    struct Id {}
    var id: Id
  }

  struct List<T: Collection, E: Hashable> { // expected-note {{where 'E' = 'S.Id'}}
    typealias Data = T.Element
    init(_: T, id: KeyPath<Data, E>) {}
  }

  var arr: [S] = []
  _ = List(arr, id: \.id) // expected-error {{generic struct 'List' requires that 'S.Id' conform to 'Hashable'}}

  enum E<T: P> { // expected-note 2 {{where 'T' = 'S'}}
    case foo(T)
    case bar([T])
  }

  var s = S(id: S.Id())
  let _: E = .foo(s)   // expected-error {{generic enum 'E' requires that 'S' conform to 'P'}}
  let _: E = .bar([s]) // expected-error {{generic enum 'E' requires that 'S' conform to 'P'}}
}

// https://bugs.swift.org/browse/SR-8934
struct BottleLayout {
    let count : Int
}
let arr = [BottleLayout]()
let layout = BottleLayout(count:1)
let ix = arr.firstIndex(of:layout) // expected-error {{referencing instance method 'firstIndex(of:)' on 'Collection' requires that 'BottleLayout' conform to 'Equatable'}}

let _: () -> UInt8 = { .init("a" as Unicode.Scalar) } // expected-error {{initializer 'init(_:)' requires that 'Unicode.Scalar' conform to }}

// https://bugs.swift.org/browse/SR-9068
func compare<C: Collection, Key: Hashable, Value: Equatable>(c: C)
  -> Bool where C.Element == (key: Key, value: Value)
{
  _ = Dictionary(uniqueKeysWithValues: Array(c))
}

// https://bugs.swift.org/browse/SR-7984
struct SR_7984<Bar> {
  func doSomething() {}
}

extension SR_7984 where Bar: String {} // expected-error {{type 'Bar' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'Bar == String' to require 'Bar' to be 'String'}} {{28-29= ==}}

protocol SR_7984_Proto {
  associatedtype Bar
}

extension SR_7984_Proto where Bar: String {} // expected-error {{type 'Self.Bar' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'Bar == String' to require 'Bar' to be 'String'}} {{34-35= ==}}

protocol SR_7984_HasFoo {
  associatedtype Foo
}
protocol SR_7984_HasAssoc {
  associatedtype Assoc: SR_7984_HasFoo
}

struct SR_7984_X<T: SR_7984_HasAssoc> {}
extension SR_7984_X where T.Assoc.Foo: String {} // expected-error {{type 'T.Assoc.Foo' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'T.Assoc.Foo == String' to require 'T.Assoc.Foo' to be 'String'}} {{38-39= ==}}

struct SR_7984_S<T: Sequence> where T.Element: String {} // expected-error {{type 'T.Element' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'T.Element == String' to require 'T.Element' to be 'String'}} {{46-47= ==}}
func SR_7984_F<T: Sequence>(foo: T) where T.Element: String {} // expected-error {{type 'T.Element' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'T.Element == String' to require 'T.Element' to be 'String'}} {{52-53= ==}}

protocol SR_7984_P {
  func S<T : Sequence>(bar: T) where T.Element: String // expected-error {{type 'T.Element' constrained to non-protocol, non-class type 'String'}} expected-note {{use 'T.Element == String' to require 'T.Element' to be 'String'}} {{47-48= ==}}
}

struct A<T: String> {} // expected-error {{type 'T' constrained to non-protocol, non-class type 'String'}}
struct B<T> where T: String {} // expected-error {{type 'T' constrained to non-protocol, non-class type 'String'}}
protocol C {
  associatedtype Foo: String // expected-error {{type 'Self.Foo' constrained to non-protocol, non-class type 'String'}}
}
protocol D {
  associatedtype Foo where Foo: String // expected-error {{type 'Self.Foo' constrained to non-protocol, non-class type 'String'}}
}

func member_ref_with_explicit_init() {
  struct S<T: P> { // expected-note {{where 'T' = 'Int'}}
    init(_: T) {}
    init(_: T, _ other: Int = 42) {}
  }

  _ = S.init(42)
  // expected-error@-1 {{generic struct 'S' requires that 'Int' conform to 'P'}}
}

protocol Q {
  init<T : P>(_ x: T) // expected-note 2{{where 'T' = 'T'}}
}

struct SR10694 {
  init<T : P>(_ x: T) {} // expected-note 3{{where 'T' = 'T'}}
  func bar<T>(_ x: T, _ s: SR10694, _ q: Q) {
    SR10694.self(x) // expected-error {{initializer 'init(_:)' requires that 'T' conform to 'P'}}

    type(of: s)(x)  // expected-error {{initializer 'init(_:)' requires that 'T' conform to 'P'}}
    // expected-error@-1 {{initializing from a metatype value must reference 'init' explicitly}}

    Q.self(x) // expected-error {{initializer 'init(_:)' requires that 'T' conform to 'P'}}
    // expected-error@-1 {{protocol type 'Q' cannot be instantiated}}

    type(of: q)(x)  // expected-error {{initializer 'init(_:)' requires that 'T' conform to 'P'}}
    // expected-error@-1 {{initializing from a metatype value must reference 'init' explicitly}}

    var srTy = SR10694.self
    srTy(x) // expected-error {{initializer 'init(_:)' requires that 'T' conform to 'P'}}
    // expected-error@-1 {{initializing from a metatype value must reference 'init' explicitly}}
  }
}

// SR-7003 (rdar://problem/51203824) - Poor diagnostics when attempting to access members on unfulfilled generic type
func sr_7003() {
  struct E<T> { // expected-note 4 {{'T' declared as parameter to type 'E'}}
    static var foo: String { return "" }
    var bar: String { return "" }
    static func baz() -> String { return "" }
    func qux() -> String { return "" }
  }

  let _: Any = E.foo
  // expected-error@-1 {{generic parameter 'T' could not be inferred}}
  // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  let _: Any = E().bar
  // expected-error@-1 {{generic parameter 'T' could not be inferred}}
  // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  let _: Any = E.baz()
  // expected-error@-1 {{generic parameter 'T' could not be inferred}}
  // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
  let _: Any = E().qux()
  // expected-error@-1 {{generic parameter 'T' could not be inferred}}
  // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{17-17=<Any>}}
}

func test_generic_subscript_with_missing_arg() {
  struct S<T> {
    subscript<U>(_: T) -> S<U> { fatalError() }
    // expected-note@-1 {{in call to 'subscript(_:)'}}
  }

  func test(_ s: S<Int>) {
    _ = s[0] // expected-error {{generic parameter 'U' could not be inferred}}
  }
}

func rdar_50007727() {
  struct A<T> { // expected-note {{'T' declared as parameter to type 'A'}}
    struct B<U> : ExpressibleByStringLiteral {
      init(stringLiteral value: String) {}
    }
  }

  struct S {}
  let _ = A.B<S>("hello")
  // expected-error@-1 {{generic parameter 'T' could not be inferred in cast to 'A.B'}}
  // expected-note@-2 {{explicitly specify the generic arguments to fix this issue}} {{12-12=<Any>}}
}

// rdar://problem/51413254

infix operator ==>

struct Key {
  init(_ key: String) {}
}

func ==> (lhs: Any, rhs: Key) throws -> Any {
  return 0
}

func ==> <A>(lhs: Any, rhs: Key) throws -> A {
  fatalError()
}

struct R_51413254 {
  var str: String = ""
  mutating func test(_ anyDict: Any) throws {
    self.str = try anyDict ==> Key("a") // Ok
  }
}

func test_correct_identification_of_requirement_source() {
  struct X<T: P> { // expected-note {{where 'T' = 'Int'}}
    init<U: P>(_: T, _: U) {} // expected-note {{where 'U' = 'Int'}}
  }

  struct A : P {
    static func foo(_ arg: A) -> A {
      return A()
    }
  }

  _ = X(17, A())
  // expected-error@-1 {{generic struct 'X' requires that 'Int' conform to 'P'}}
  _ = X(A(), 17)
  // expected-error@-1 {{initializer 'init(_:_:)' requires that 'Int' conform to 'P'}}
}

struct SR11435<T> {
  subscript<U : P & Hashable>(x x: U) -> U { x } // expected-note {{where 'U' = 'Int'}}
}

extension SR11435 where T : P { // expected-note {{where 'T' = 'Int'}}
  var foo: Int { 0 }
}

func test_identification_of_key_path_component_callees() {
  _ = \SR11435<Int>.foo // expected-error {{property 'foo' requires that 'Int' conform to 'P'}}
  _ = \SR11435<Int>.[x: 5] // expected-error {{subscript 'subscript(x:)' requires that 'Int' conform to 'P'}}
}

func sr_11491(_ value: [String]) {
  var arr: Set<String> = []
  arr.insert(value)
  // expected-error@-1 {{cannot convert value of type '[String]' to expected argument type 'String'}}
}

func test_dictionary_with_generic_mismatch_in_key_or_value() {
  struct S<T> : Hashable {}
  // expected-note@-1 2 {{arguments to generic parameter 'T' ('Int' and 'Bool') are expected to be equal}}

  let _: [Int: S<Bool>] = [0: S<Bool>(), 1: S<Int>()]
  // expected-error@-1 {{cannot convert value of type 'S<Int>' to expected dictionary value type 'S<Bool>'}}

  let _: [S<Bool>: Int] = [S<Int>(): 42]
  // expected-error@-1 {{cannot convert value of type 'S<Int>' to expected dictionary key type 'S<Bool>'}}
}


// rdar://problem/56212087 - unable to infer type for generic parameter `T`
func rdar56212087() {
  func setValue(_: Any?, forKey: String) {}

  func foo<T: ExpressibleByStringLiteral>(_: String, _: T) -> T {
    fatalError()
  }

  setValue(foo("", ""), forKey: "") // Ok (T is inferred as a `String` instead of `Any?`)
}

// rdar://77233864 - Ternary operator fails to deduce non-default literal type in SwiftUI preview
func test_ternary_operator_with_regular_conformance_to_literal_protocol() {
  // Note that in this case `ExpressibleByIntegerLiteral` is a non-literal requirement
  func test<T: ExpressibleByIntegerLiteral>(_: T) -> T {
    fatalError()
  }

  func bug(_: Float?) {}

  bug(true ? test(0) : test(42)) // Ok - type is `CGFloat` for 0 and 42
}
