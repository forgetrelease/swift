// RUN: %swift-syntax-test -input-source-filename %s -serialize-raw-tree > %t
// RUN: diff -u %S/Inputs/serialize_struct_decl.json %t

struct Foo {
  let   bar : Int

  let baz : Array < Int >
      }
