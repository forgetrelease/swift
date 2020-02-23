// RUN: not %target-swift-frontend -enable-experimental-diagnostic-formatting -typecheck %s 2>&1 | %FileCheck %s

1 + 2

func foo(a: Int, b: Int) {
  a + b
}

foo(b: 1, a: 2)


func baz() {
  bar(a: "hello, world!")
}

struct Foo: Codable {
  var x: Int
  var x: Int
}

func bar(a: Int) {}
func bar(a: Float) {}


func bazz() throws {

}
bazz()

struct A {}
extension A {
  let x: Int = { 42 }
}

let abc = "👍

// Test fallback for non-ASCII characters.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:35:11
// CHECK: 34 |
// CHECK: 35 | let abc = "👍
// CHECK:    | --> error: unterminated string literal
// CHECK: 36 |

// Test underlining.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:3:3
// CHECK: 2 |
// CHECK: 3 | 1 + 2
// CHECK:   | ~   ~
// CHECK:   |   ^ warning: result of operator '+' is unused
// CHECK: 4 |

// Test inline fix-it rendering.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:9:11
// CHECK: 8 |
// CHECK: 9 | foo(a: 2, b: 1, a: 2)
// CHECK:   |           ~~~~  ~~~~
// CHECK:   |                 ^ error: argument 'a' must precede argument 'b'
// CHECK: 10 |


// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:18:7
// CHECK: 16 | struct Foo: Codable {
// CHECK: 17 |   var x: Int
// CHECK:    |       ^ note: 'x' previously declared here
// CHECK: 18 |   var x: Int
// CHECK:    |       ^ error: invalid redeclaration of 'x'
// CHECK: 19 | }

// Test fallback for invalid locations.
// CHECK: Unknown Location
// CHECK:    | error: invalid redeclaration of 'x'
// CHECK:    | note: 'x' previously declared here

// Test cross-file and decl anchored diagnostics.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:16:8
// CHECK: 15 |
// CHECK: 16 | struct Foo: Codable {
// CHECK:    |        ^ error: type 'Foo' does not conform to protocol 'Encodable'
// CHECK: 17 |   var x: Int
// CHECK: 18 |   var x: Int
// CHECK:    |       ^ note: cannot automatically synthesize 'Encodable' because
// CHECK:    |       ^ note: cannot automatically synthesize 'Encodable' because
// CHECK: 19 | }
// CHECK: Swift.Encodable:2:10
// CHECK: 1 | public protocol Encodable {
// CHECK: 2 |     func encode(to encoder: Encoder) throws
// CHECK:   |          ^ note: protocol requires function 'encode(to:)' with type 'Encodable'
// CHECK: 3 | }

// Test out-of-line fix-its on notes.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:28:1
// CHECK: 27 | }
// CHECK: 28 | bazz()
// CHECK:    | ~~~~~~
// CHECK:    | ^ error: call can throw but is not marked with 'try'
// CHECK:    | ^ note: did you mean to use 'try'? [insert 'try ']
// CHECK:    | ^ note: did you mean to handle error as optional value? [insert 'try? ']
// CHECK:    | ^ note: did you mean to disable error propagation? [insert 'try! ']
// CHECK: 29 |


// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:32:7
// CHECK: 31 | extension A {
// CHECK: 32 |   let x: Int = { 42 }
// CHECK:    |       ^ error: extensions must not contain stored properties
// CHECK: 33 | }

// Test complex out-of-line fix-its.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:32:16
// CHECK: 31 | extension A {
// CHECK: 32 |   let x: Int = { 42 }()
// CHECK:    |                ~~~~~~
// CHECK:    |                ^ error: function produces expected type 'Int'; did you mean to call it with '()'?
// CHECK:    |                ^ note: Remove '=' to make 'x' a computed property [remove '= '] [replace 'let' with 'var']
// CHECK: 33 | }


// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:6:5
// CHECK: 5 | func foo(a: Int, b: Int) {
// CHECK: 6 |   a + b
// CHECK:   |   ~   ~
// CHECK:   |     ^ warning: result of operator '+' is unused
// CHECK: 7 | }

// Test snippet truncation.
// CHECK: SOURCE_DIR/test/diagnostics/pretty-printed-diagnostics.swift:13:3
// CHECK: 12 | func baz() {
// CHECK: 13 |   bar(a: "hello, world!")
// CHECK:    |   ^ error: no exact matches in call to global function 'bar'
// CHECK: 14 | }
// CHECK:   ...
// CHECK: 20 |
// CHECK: 21 | func bar(a: Int) {}
// CHECK:    |      ^ note: candidate expects value of type 'Int' for parameter #1
// CHECK: 22 | func bar(a: Float) {}
// CHECK:    |      ^ note: candidate expects value of type 'Float' for parameter #1
// CHECK: 23 |
