// RUN: %target-typecheck-verify-swift -enable-invalid-ephemeralness-as-error

// Test availability attributes on UnsafePointer initializers.
// Assume the original source contains no UnsafeRawPointer types.
func unsafePointerConversionAvailability(
  mrp: UnsafeMutableRawPointer,
  rp: UnsafeRawPointer,
  umpv: UnsafeMutablePointer<Void>, // expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  upv: UnsafePointer<Void>, // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  umpi: UnsafeMutablePointer<Int>,
  upi: UnsafePointer<Int>,
  umps: UnsafeMutablePointer<String>,
  ups: UnsafePointer<String>) {

  let omrp: UnsafeMutableRawPointer? = mrp
  let orp: UnsafeRawPointer? = rp
  let oumpv: UnsafeMutablePointer<Void> = umpv  // expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  let oupv: UnsafePointer<Void>? = upv  // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  let oumpi: UnsafeMutablePointer<Int>? = umpi
  let oupi: UnsafePointer<Int>? = upi
  let oumps: UnsafeMutablePointer<String>? = umps
  let oups: UnsafePointer<String>? = ups

  _ = UnsafeMutableRawPointer(mrp)
  _ = UnsafeMutableRawPointer(rp)   // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(umpv)
  _ = UnsafeMutableRawPointer(upv)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(umpi)
  _ = UnsafeMutableRawPointer(upi)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(umps)
  _ = UnsafeMutableRawPointer(ups)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(omrp)
  _ = UnsafeMutableRawPointer(orp)   // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(oumpv)
  _ = UnsafeMutableRawPointer(oupv)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(oumpi)
  _ = UnsafeMutableRawPointer(oupi)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}
  _ = UnsafeMutableRawPointer(oumps)
  _ = UnsafeMutableRawPointer(oups)  // expected-error {{'init(_:)' has been renamed to 'init(mutating:)'}}

  // These all correctly pass with no error.
  _ = UnsafeRawPointer(mrp)
  _ = UnsafeRawPointer(rp)
  _ = UnsafeRawPointer(umpv)
  _ = UnsafeRawPointer(upv)
  _ = UnsafeRawPointer(umpi)
  _ = UnsafeRawPointer(upi)
  _ = UnsafeRawPointer(umps)
  _ = UnsafeRawPointer(ups)
  _ = UnsafeRawPointer(omrp)
  _ = UnsafeRawPointer(orp)
  _ = UnsafeRawPointer(oumpv)
  _ = UnsafeRawPointer(oupv)
  _ = UnsafeRawPointer(oumpi)
  _ = UnsafeRawPointer(oupi)
  _ = UnsafeRawPointer(oumps)
  _ = UnsafeRawPointer(oups)
  _ = UnsafePointer<Int>(upi)
  _ = UnsafePointer<Int>(oumpi)
  _ = UnsafePointer<Int>(oupi)
  _ = UnsafeMutablePointer<Int>(umpi)
  _ = UnsafeMutablePointer<Int>(oumpi)

  _ = UnsafeMutablePointer<Void>(rp)  // expected-error {{no exact matches in call to initializer}} expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  _ = UnsafeMutablePointer<Void>(mrp) // expected-error {{no exact matches in call to initializer}} expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  _ = UnsafeMutablePointer<Void>(umpv) // expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  _ = UnsafeMutablePointer<Void>(umpi) // expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}
  _ = UnsafeMutablePointer<Void>(umps) // expected-warning {{UnsafeMutablePointer<Void> has been replaced by UnsafeMutableRawPointer}}

  _ = UnsafePointer<Void>(rp)  // expected-error {{cannot convert value of type 'UnsafeRawPointer' to expected argument type 'Builtin.RawPointer'}} expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(mrp) // expected-error {{cannot convert value of type 'UnsafeMutableRawPointer' to expected argument type 'Builtin.RawPointer'}} expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(umpv) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(upv) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(umpi) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(upi) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(umps) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}
  _ = UnsafePointer<Void>(ups) // expected-warning {{UnsafePointer<Void> has been replaced by UnsafeRawPointer}}

  _ = UnsafeMutablePointer<Int>(rp) // expected-error {{no exact matches in call to initializer}}
  _ = UnsafeMutablePointer<Int>(mrp) // expected-error {{no exact matches in call to initializer}}
  _ = UnsafeMutablePointer<Int>(orp) // expected-error {{no exact matches in call to initializer}}
  _ = UnsafeMutablePointer<Int>(omrp) // expected-error {{no exact matches in call to initializer}}

  _ = UnsafePointer<Int>(rp)  // expected-error {{cannot convert value of type 'UnsafeRawPointer' to expected argument type 'Builtin.RawPointer'}}
  _ = UnsafePointer<Int>(mrp) // expected-error {{cannot convert value of type 'UnsafeMutableRawPointer' to expected argument type 'Builtin.RawPointer'}}
  _ = UnsafePointer<Int>(orp)  // expected-error {{cannot convert value of type 'UnsafeRawPointer?' to expected argument type 'Builtin.RawPointer'}}
  _ = UnsafePointer<Int>(omrp) // expected-error {{cannot convert value of type 'UnsafeMutableRawPointer?' to expected argument type 'Builtin.RawPointer'}}

  _ = UnsafePointer<Int>(ups) // expected-error {{cannot convert value of type 'UnsafePointer<String>' to expected argument type 'UnsafePointer<Int>'}}
  // expected-note@-1 {{arguments to generic parameter 'Pointee' ('String' and 'Int') are expected to be equal}}
  _ = UnsafeMutablePointer<Int>(umps) // expected-error {{cannot convert value of type 'UnsafeMutablePointer<String>' to expected argument type 'UnsafeMutablePointer<Int>'}}
  // expected-note@-1 {{arguments to generic parameter 'Pointee' ('String' and 'Int') are expected to be equal}}
  _ = UnsafePointer<String>(upi) // expected-error {{cannot convert value of type 'UnsafePointer<Int>' to expected argument type 'UnsafePointer<String>'}}
  // expected-note@-1 {{arguments to generic parameter 'Pointee' ('Int' and 'String') are expected to be equal}}
  _ = UnsafeMutablePointer<String>(umpi) // expected-error {{cannot convert value of type 'UnsafeMutablePointer<Int>' to expected argument type 'UnsafeMutablePointer<String>'}}
  // expected-note@-1 {{arguments to generic parameter 'Pointee' ('Int' and 'String') are expected to be equal}}
}

func unsafeRawBufferPointerConversions(
  mrp: UnsafeMutableRawPointer,
  rp: UnsafeRawPointer,
  mrbp: UnsafeMutableRawBufferPointer,
  rbp: UnsafeRawBufferPointer,
  mbpi: UnsafeMutableBufferPointer<Int>,
  bpi: UnsafeBufferPointer<Int>) {

  let omrp: UnsafeMutableRawPointer? = mrp
  let orp: UnsafeRawPointer? = rp

  _ = UnsafeMutableRawBufferPointer(start: mrp, count: 1)
  _ = UnsafeRawBufferPointer(start: mrp, count: 1)
  _ = UnsafeMutableRawBufferPointer(start: rp, count: 1) // expected-error {{cannot convert value of type 'UnsafeRawPointer' to expected argument type 'UnsafeMutableRawPointer?'}}
  _ = UnsafeRawBufferPointer(start: rp, count: 1)
  _ = UnsafeMutableRawBufferPointer(mrbp)
  _ = UnsafeRawBufferPointer(mrbp)
  _ = UnsafeMutableRawBufferPointer(rbp) // expected-error {{missing argument label 'mutating:' in call}}
  _ = UnsafeRawBufferPointer(rbp)
  _ = UnsafeMutableRawBufferPointer(mbpi)
  _ = UnsafeRawBufferPointer(mbpi)
  _ = UnsafeMutableRawBufferPointer(bpi) // expected-error {{cannot convert value of type 'UnsafeBufferPointer<Int>' to expected argument type 'UnsafeMutableRawBufferPointer'}}
  _ = UnsafeRawBufferPointer(bpi)
  _ = UnsafeMutableRawBufferPointer(start: omrp, count: 1)
  _ = UnsafeRawBufferPointer(start: omrp, count: 1)
  _ = UnsafeMutableRawBufferPointer(start: orp, count: 1) // expected-error {{cannot convert value of type 'UnsafeRawPointer?' to expected argument type 'UnsafeMutableRawPointer?'}}
  _ = UnsafeRawBufferPointer(start: orp, count: 1)
}


struct SR9800 {
  func foo(_: UnsafePointer<CChar>) {}
  func foo(_: UnsafePointer<UInt8>) {}

  func ambiguityTest(buf: UnsafeMutablePointer<CChar>) {
    _ = foo(UnsafePointer(buf)) // this call should be unambiguoius
  }
}

// Test that we get a custom diagnostic for an ephemeral conversion to non-ephemeral param for an Unsafe[Mutable][Raw][Buffer]Pointer init.
func unsafePointerInitEphemeralConversions() {
  class C {}
  var foo = 0
  var str = ""
  var arr = [0]
  var optionalArr: [Int]? = [0]
  var c: C?

  // FIXME(rdar://57360581): Once we re-introduce the @_nonEphemeral attribute,
  // these should produce errors.
  _ = UnsafePointer(&foo)
  _ = UnsafePointer(&foo + 1)
  _ = UnsafePointer.init(&foo)
  _ = UnsafePointer<Int8>("")
  _ = UnsafePointer<Int8>.init("")
  _ = UnsafePointer<Int8>(str)
  _ = UnsafePointer([0])
  _ = UnsafePointer(arr)
  _ = UnsafePointer(&arr)
  _ = UnsafePointer(optionalArr)

  _ = UnsafeMutablePointer(&foo)
  _ = UnsafeMutablePointer(&arr)
  _ = UnsafeMutablePointer(&arr + 2)
  _ = UnsafeMutablePointer(mutating: &foo)
  _ = UnsafeMutablePointer<Int8>(mutating: "")
  _ = UnsafeMutablePointer<Int8>(mutating: str)
  _ = UnsafeMutablePointer(mutating: [0])
  _ = UnsafeMutablePointer(mutating: arr)
  _ = UnsafeMutablePointer(mutating: &arr)
  _ = UnsafeMutablePointer(mutating: optionalArr)

  _ = UnsafeRawPointer(&foo)
  _ = UnsafeRawPointer(str)
  _ = UnsafeRawPointer(arr)
  _ = UnsafeRawPointer(&arr)
  _ = UnsafeRawPointer(optionalArr)

  _ = UnsafeMutableRawPointer(&foo)
  _ = UnsafeMutableRawPointer(&arr)
  _ = UnsafeMutableRawPointer(mutating: &foo)
  _ = UnsafeMutableRawPointer(mutating: str)
  _ = UnsafeMutableRawPointer(mutating: arr)
  _ = UnsafeMutableRawPointer(mutating: &arr)
  _ = UnsafeMutableRawPointer(mutating: optionalArr)

  _ = UnsafeBufferPointer(start: &foo, count: 0)
  _ = UnsafeBufferPointer.init(start: &foo, count: 0)
  _ = UnsafeBufferPointer<Int8>(start: str, count: 0)
  _ = UnsafeBufferPointer<Int8>.init(start: str, count: 0)
  _ = UnsafeBufferPointer(start: arr, count: 0)
  _ = UnsafeBufferPointer(start: &arr, count: 0)
  _ = UnsafeBufferPointer(start: optionalArr, count: 0)

  _ = UnsafeMutableBufferPointer(start: &foo, count: 0)
  _ = UnsafeMutableBufferPointer(start: &arr, count: 0)

  _ = UnsafeRawBufferPointer(start: &foo, count: 0)
  _ = UnsafeRawBufferPointer(start: str, count: 0)
  _ = UnsafeRawBufferPointer(start: arr, count: 0)
  _ = UnsafeRawBufferPointer(start: &arr, count: 0)
  _ = UnsafeRawBufferPointer(start: optionalArr, count: 0)

  _ = UnsafeMutableRawBufferPointer(start: &foo, count: 0)
  _ = UnsafeMutableRawBufferPointer(start: &arr, count: 0)

  // FIXME: This is currently ambiguous.
  _ = OpaquePointer(&foo) // expected-error {{ambiguous use of 'init(_:)'}}

  // FIXME: This is currently ambiguous.
  _ = OpaquePointer(&arr) // expected-error {{ambiguous use of 'init(_:)'}}

  _ = OpaquePointer(arr)
  _ = OpaquePointer(str)
}

var global = 0

// Test that we allow non-ephemeral conversions, such as inout-to-pointer for globals.
func unsafePointerInitNonEphemeralConversions() {
  _ = UnsafePointer(&global)
  _ = UnsafeMutablePointer(&global)
  _ = UnsafeRawPointer(&global)
  _ = UnsafeMutableRawPointer(&global)
  _ = UnsafeBufferPointer(start: &global, count: 0)
  _ = UnsafeMutableBufferPointer(start: &global, count: 0)
  _ = UnsafeRawBufferPointer(start: &global, count: 0)
  _ = UnsafeMutableRawBufferPointer(start: &global, count: 0)

  // FIXME: This is currently ambiguous.
  _ = OpaquePointer(&global) // expected-error {{ambiguous use of 'init(_:)'}}
}
