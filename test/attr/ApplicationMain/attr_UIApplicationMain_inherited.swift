// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -typecheck -parse-as-library -verify %s
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -typecheck -parse-as-library -enable-upcoming-feature DeprecateApplicationMain -verify -verify-additional-prefix deprecated- %s

// REQUIRES: objc_interop

import UIKit

class DelegateBase : NSObject, UIApplicationDelegate { }

@UIApplicationMain // expected-deprecated-warning {{'UIApplicationMain' is deprecated; this is an error in Swift 6}}
// expected-deprecated-note@-1 {{use @main instead}} {{1-19=@main}}
class MyDelegate : DelegateBase { }

