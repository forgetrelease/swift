// RUN: %target-swift-emit-silgen -enable-sil-ownership-verifier %s | %FileCheck %s

class Test {
    // CHECK-LABEL: sil hidden [transparent] @$S46magic_identifiers_inside_property_initializers4TestC4fileSSvpfi
    // CHECK: string_literal utf16 "{{.*}}.swift"
    let file = #file
}
