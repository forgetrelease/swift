// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -typecheck -verify %s -debug-constraints 2>%t.err
// RUN: %FileCheck %s < %t.err

// REQUIRES: objc_interop

import Foundation

@objc protocol P {
  func foo(_ i: Int) -> Double // expected-note {{'foo' previously declared here}}
  func foo(_ d: Double) -> Double // expected-warning {{method 'foo' with Objective-C selector 'foo:' conflicts with previous declaration with the same Objective-C selector; this is an error in Swift 6}}

  @objc optional func opt(_ i: Int) -> Int // expected-note {{'opt' previously declared here}}
  @objc optional func opt(_ d: Double) -> Int // expected-warning {{method 'opt' with Objective-C selector 'opt:' conflicts with previous declaration with the same Objective-C selector; this is an error in Swift 6}}
}

func testOptional(obj: P) {
  // CHECK: | Common result type for {{.*}} is Int
  _ = obj.opt?(1)

  // CHECK: | Common result type for {{.*}} is Int
  _ = obj.opt!(1)
}
