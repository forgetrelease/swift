// RUN: %sourcekitd-test -req=index %s -- -Xfrontend -serialize-diagnostics-path -Xfrontend %t.dia %s | %sed_clean > %t.response
// RUN: diff -u %s.response %t.response

import Foundation

struct Array {}

extension Swift.Array {
  func myMethod() {
    let dict = Swift.Dictionary<Swift.Array, Array>()
  }
}
