// RUN: %empty-directory(%t)
// RUN: cp -R %S/Inputs/mixed-target %t

// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -I %S/../Inputs/custom-modules -import-objc-header %t/mixed-target/header.h -emit-module-path %t/MixedWithHeader.swiftmodule %S/Inputs/mixed-with-header.swift %S/../../Inputs/empty.swift -module-name MixedWithHeader -enable-objc-interop -disable-objc-attr-requires-foundation-module
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -I %S/../Inputs/custom-modules -enable-objc-interop -typecheck %s -verify

// RUN: rm -rf %t/mixed-target/
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -I %S/../Inputs/custom-modules -enable-objc-interop -typecheck %s -verify

// REQUIRES: SR7768

import MixedWithHeader

func testReexportedClangModules(_ foo : FooProto) {
  _ = foo.bar as CInt
  _ = ExternIntX.x as CInt
}

func testCrossReferences(_ derived: Derived) {
  let obj: Base = derived
  _ = obj.safeOverride(ForwardClass()) as NSObject
  _ = obj.safeOverrideProto(ForwardProtoAdopter()) as NSObject

  testProtocolWrapper(ProtoConformer())
  _ = testStruct(Point2D(x: 2,y: 3))
}
