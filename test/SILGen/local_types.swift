// RUN: %target-swift-emit-silgen  -parse-as-library -enable-sil-ownership-verifier %s -verify | %FileCheck %s
// RUN: %target-swift-emit-ir  -parse-as-library -enable-sil-ownership-verifier %s

func function() {
  return

  class UnreachableClass {} // expected-warning {{code after 'return' will never be executed}}
}

// CHECK-LABEL: sil_vtable UnreachableClass
