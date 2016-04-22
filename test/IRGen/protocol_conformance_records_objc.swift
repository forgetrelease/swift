// RUN: rm -rf %t && mkdir %t
// RUN: %build-irgen-test-overlays
// RUN: %target-swift-frontend(mock-sdk: -sdk %S/Inputs -I %t) -emit-module -o %t %S/Inputs/objc_protocols_Bas.swift
// RUN: %target-swift-frontend(mock-sdk: -sdk %S/Inputs -I %t) -primary-file %s -emit-ir -disable-incremental-llvm-codegen | FileCheck %s
// RUN: %target-swift-frontend(mock-sdk: -sdk %S/Inputs -I %t) %s -emit-ir -disable-incremental-llvm-codegen -num-threads 8 | FileCheck %s

// REQUIRES: objc_interop

import gizmo

protocol Runcible {
  func runce()
}

// CHECK-LABEL: @"\01l_protocol_conformances" = private constant [

// CHECK:         %swift.protocol_conformance {
// -- protocol descriptor
// CHECK:           [[RUNCIBLE:%swift.protocol\* @_TMp33protocol_conformance_records_objc8Runcible]]
// -- type metadata
// CHECK:           @_TMVSC6NSRect
// -- witness table
// CHECK:           @_TWPVSC6NSRect33protocol_conformance_records_objc8Runcible
// -- flags 0x02: nonunique direct metadata
// CHECK:           i32 2 },
extension NSRect: Runcible {
  func runce() {}
}

// -- TODO class refs should be indirected through their ref variable
// CHECK:         %swift.protocol_conformance {
// -- protocol descriptor
// CHECK:           [[RUNCIBLE]]
// -- class object (TODO should be class ref variable)
// CHECK:           @"got.OBJC_CLASS_$_Gizmo"
// -- witness table
// CHECK:           @_TWPCSo5Gizmo33protocol_conformance_records_objc8Runcible
// -- flags 0x01: unique direct metadata (TODO should be 0x03 indirect class)
// CHECK:           i32 1
// CHECK:         }
extension Gizmo: Runcible {
  func runce() {}
}
