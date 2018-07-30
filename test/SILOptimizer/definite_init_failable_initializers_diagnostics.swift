// RUN: %target-swift-frontend -emit-sil -enable-sil-ownership-verifier -disable-objc-attr-requires-foundation-module -verify %s

// High-level tests that DI rejects certain invalid idioms for early
// return from initializers.

// <rdar://problem/19267795> failable initializers that call noreturn function produces bogus diagnostics
class FailableInitThatFailsReallyHard {
  init?() {   // no diagnostics generated.
    fatalError("bad")
  }
}


class BaseClass {}
final class DerivedClass : BaseClass {
  init(x : ()) {
    fatalError("bad")  // no diagnostics.
  }
}

func something(_ x: Int) {}

func something(_ x: inout Int) {}

func something(_ x: AnyObject) {}

func something(_ x: Any.Type) {}

// <rdar://problem/22946400> DI needs to diagnose self usages in error block
//
// FIXME: crappy QoI
class ErrantBaseClass {
  init() throws {}
}

class ErrantClass : ErrantBaseClass {
  let x: Int
  var y: Int

  override init() throws {
    x = 10
    y = 10
    try super.init()
  }

  init(invalidEscapeDesignated: ()) {
    x = 10
    y = 10
    do {
      try super.init()
    } catch {}
  } // expected-error {{'self' used inside 'catch' block reachable from super.init call}}

  init(invalidEscapeDesignated2: ()) throws {
    x = 10
    y = 10
    do {
      try super.init()
    } catch {
      try super.init() // expected-error {{'self' used inside 'catch' block reachable from super.init call}}
    }
  }

  init(invalidEscapeDesignated3: ()) {
    x = 10
    y = 10
    do {
      try super.init()
    } catch {
      print(self.x) // expected-error {{'self' used inside 'catch' block reachable from super.init call}}
      self.y = 20 // expected-error {{'self' used inside 'catch' block reachable from super.init call}}
    }
  } // expected-error {{'self' used inside 'catch' block reachable from super.init call}}

  init(invalidEscapeDesignated4: ()) throws {
    x = 10
    y = 10
    do {
      try super.init()
    } catch let e {
      print(self.x) // expected-error {{'self' used inside 'catch' block reachable from super.init call}}
      throw e
    }
  }

  convenience init(invalidEscapeConvenience: ()) {
    do {
      try self.init()
    } catch {}
  } // expected-error {{'self' used inside 'catch' block reachable from self.init call}}

  convenience init(invalidEscapeConvenience2: ()) throws {
    do {
      try self.init()
    } catch {
      try self.init() // expected-error {{'self' used inside 'catch' block reachable from self.init call}}
    }
  }

  convenience init(invalidEscapeConvenience3: ()) throws {
    do {
      try self.init()
    } catch let e {
      print(self) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}
      throw e
    }
  }

  init(noEscapeDesignated: ()) throws {
    x = 10
    y = 10
    do {
      try super.init()
    } catch let e {
      throw e  // ok
    }
  }

  convenience init(noEscapeConvenience: ()) throws {
    do {
      try self.init()
    } catch let e {
      throw e  // ok
    }
  }

  convenience init(invalidAccess: ()) throws {
    do {
      try self.init()
    } catch let e {
      something(x) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}
      something(self.x) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}

      something(y) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}
      something(self.y) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}

      something(&y) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}
      something(&self.y) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}

      something(self) // expected-error {{'self' used inside 'catch' block reachable from self.init call}}

      // FIXME: not diagnosed
      something(type(of: self))

      throw e
    }
  }
}
