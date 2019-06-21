// REQUIRES: enable-astscope-lookup
// RUN: %target-typecheck-verify-swift

func makeIncrementor(amount: Int) -> () -> Int {
  func incrementor() -> Int {
    currentTotal += amount // expected-error{{use of unresolved identifier 'currentTotal'}}
    return currentTotal // expected-error{{use of unresolved identifier 'currentTotal'}}
  }
  var currentTotal = 0
  currentTotal = 1; _ = currentTotal
  return incrementor
}

func pingpong() {
  func ping() -> Int {
    return pong()
  }
  func pong() -> Int {
    return ping()
  }
  _ = ping()
}

func transitiveForwardCapture() {
  func ping() -> Int {
    return pong() // expected-error{{cannot capture 'pong', which would use 'x' before it is declared}}
  }
  _ = ping()
  var x = 1 // expected-note{{'x' declared here}}
  func pong() -> Int { // expected-note{{'pong', declared here, captures 'x'}}
    x += 1
    return ping()
  }
}

func transitiveForwardCapture2() {
  func ping() -> Int {
    _ = pong() // expected-error{{cannot capture 'pong', which would use 'x' before it is declared}}
  }
  _ = ping()
  var x = 1 // expected-note{{'x' declared here}}
  func pong() -> Int { // expected-note{{'pong', declared here, captures 'pung'}}
    _ = pung()
  }
  func pung() -> Int { // expected-note{{'pung', declared here, captures 'x'}}
    x += 1
    return ping()
  }
}

func transitiveForwardCapture3() {
  var y = 2
  func ping() -> Int {
    _ = pong() // expected-error{{cannot capture 'pong', which would use 'x' before it is declared}}
  }
  _ = ping()
  var x = 1 // expected-note{{'x' declared here}}
  func pung() -> Int { // expected-note{{'pung', declared here, captures 'x'}}
    x += 1
    return ping()
  }
  func pong() -> Int { // expected-note{{'pong', declared here, captures 'pung'}}
    y += 2
    _ = pung()
  }
}

func outOfOrderEnum() {
  func f() -> Suit {
    return .Club
  }

  enum Suit {
  case Club
  case Diamond
  case Heart
  case Spade
  }
}

func captureInClosure() {
  let x = { (i: Int) in
    currentTotal += i // expected-error{{use of unresolved identifier 'currentTotal'}}
  }

  var currentTotal = 0

  _ = x
  currentTotal += 1
}

class X { 
  func foo() { }
}

func captureLists(x: X) {
  { [unowned x] in x.foo() }();
  let _: Void = { [unowned x] in x.foo() }()
  let _: Void = { [weak x] in x?.foo() }()
}
