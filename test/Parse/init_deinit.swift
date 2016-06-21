// RUN: %target-parse-verify-swift

struct FooStructConstructorA {
  init // expected-error {{expected '('}}
}

struct FooStructConstructorB {
  init() // expected-error {{initializer requires a body}}
}

struct FooStructConstructorC {
  init {} // expected-error {{expected '('}}{{8-8=() }}
}


struct FooStructDeinitializerA {
  deinit // expected-error {{expected '{' for deinitializer}}
}

struct FooStructDeinitializerB {
  deinit // expected-error {{expected '{' for deinitializer}}
}

struct FooStructDeinitializerC {
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

class FooClassDeinitializerA {
  deinit(a : Int) {} // expected-error{{no parameter clause allowed on deinitializer}}{{9-18=}}
}

class FooClassDeinitializerB {
  deinit { }
}

init {} // expected-error {{initializers may only be declared within a type}} expected-error {{expected '('}} {{6-6=() }}
init() // expected-error {{initializers may only be declared within a type}}
init() {} // expected-error {{initializers may only be declared within a type}}

deinit {} // expected-error {{deinitializers may only be declared within a class}}
deinit // expected-error {{expected '{' for deinitializer}}
deinit {} // expected-error {{deinitializers may only be declared within a class}}

struct BarStruct {
  init() {}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

extension BarStruct {
  init(x : Int) {}

  // When/if we allow 'var' in extensions, then we should also allow dtors
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

enum BarUnion {
  init() {}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

extension BarUnion {
  init(x : Int) {}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

class BarClass {
  init() {}
  deinit {}
}

extension BarClass {
  convenience init(x : Int) { self.init() }
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

protocol BarProtocol {
  init() {} // expected-error {{protocol initializers may not have bodies}}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

extension BarProtocol {
  init(x : Int) {}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

func fooFunc() {
  init() {} // expected-error {{initializers may only be declared within a type}}
  deinit {} // expected-error {{deinitializers may only be declared within a class}}
}

func barFunc() {
  var x : () = { () -> () in
    init() {} // expected-error {{initializers may only be declared within a type}}
    return
  } ()

  var y : () = { () -> () in
    deinit {} // expected-error {{deinitializers may only be declared within a class}}
    return
  } ()
}

// SR-852
class Aaron {
  init(x: Int) {}
  convenience init() { init(x: 1) } // expected-error {{missing 'self.' at initializer invocation}}
}

class Theodosia: Aaron {
  init() {
    init(x: 2) // expected-error {{missing 'super.' at initializer invocation}}
  }
}
