// RUN: %target-typecheck-verify-swift -enable-objc-interop

class Base {}

@objc protocol Protocol1 : Base {}
// expected-error@-1 {{class can only inherit from protocol in extension declaration 'Base'}}

@objc protocol OtherProtocol {}

typealias Composition = OtherProtocol & Base

@objc protocol Protocol2 : Composition {}
// expected-error@-1 {{cannot inherit from class-constrained protocol composition type 'Composition' (aka 'Base & OtherProtocol')}}

@objc protocol Protocol3 : OtherProtocol & Base {}
// expected-error@-1 {{cannot inherit from class-constrained protocol composition type 'Base & OtherProtocol'}}
