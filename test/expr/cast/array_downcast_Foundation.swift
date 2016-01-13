// RUN: rm -rf %t
// RUN: mkdir %t

// FIXME: BEGIN -enable-source-import hackaround
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -emit-module -o %t %clang-importer-sdk-path/swift-modules/Foundation.swift
// FIXME: END -enable-source-import hackaround

// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk-nosource -I %t) -parse %s -verify
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk-nosource -I %t) %s -dump-ast -verify 2>&1 | FileCheck %s

// REQUIRES: objc_interop

import Foundation

func testDowncastObjectToArray(obj: AnyObject, objImplicit: AnyObject!) {
  var nsstrArr1 = (obj as! [NSString])! // expected-error{{cannot force unwrap value of non-optional type '[NSString]'}}{{39-40=}}
  var strArr1 = (obj as! [String])! // expected-error{{cannot force unwrap value of non-optional type '[String]'}}{{35-36=}}

  var nsstrArr2 = (objImplicit as! [NSString])! // expected-error{{cannot force unwrap value of non-optional type '[NSString]'}}{{47-48=}}
  var strArr2 = (objImplicit as! [String])! // expected-error{{cannot force unwrap value of non-optional type '[String]'}}{{43-44=}}
}

func testArrayDowncast(arr: [AnyObject], arrImplicit: [AnyObject]!) {
  var nsstrArr1 = (arr as! [NSString])! // expected-error{{cannot force unwrap value of non-optional type '[NSString]'}} {{39-40=}}
  var strArr1 = (arr as! [String])! // expected-error{{cannot force unwrap value of non-optional type '[String]'}} {{35-36=}}

  var nsstrArr2 = (arrImplicit as! [NSString])! // expected-error{{cannot force unwrap value of non-optional type '[NSString]'}} {{47-48=}}
  var strArr2 = (arrImplicit as! [String])! // expected-error{{cannot force unwrap value of non-optional type '[String]'}} {{43-44=}}
}

func testDowncastNSArrayToArray(nsarray: NSArray) {
  _ = nsarray as! [NSString]
  _ = nsarray as! [String]
}

// CHECK-LABEL: testDowncastOptionalObject
func testDowncastOptionalObject(obj: AnyObject?!) -> [String]? {
  // CHECK: (optional_evaluation_expr implicit type='[String]?'
  // CHECK-NEXT: (inject_into_optional implicit type='[String]?'
  // CHECK: (forced_checked_cast_expr type='[String]'{{.*value_cast}}
  // CHECK: (bind_optional_expr implicit type='AnyObject'
  // CHECK-NEXT: (force_value_expr implicit type='AnyObject?'
  // CHECK-NEXT: (declref_expr type='AnyObject?!'
  return obj as! [String]?
}

// CHECK-LABEL: testDowncastOptionalObjectConditional
func testDowncastOptionalObjectConditional(obj: AnyObject?!) -> [String]?? {
  // CHECK: (optional_evaluation_expr implicit type='[String]??'
  // CHECK-NEXT: (inject_into_optional implicit type='[String]??'
  // CHECK-NEXT: (optional_evaluation_expr implicit type='[String]?'
  // CHECK-NEXT: (inject_into_optional implicit type='[String]?'
  // CHECK-NEXT: (bind_optional_expr implicit type='[String]'
  // CHECK-NEXT: (conditional_checked_cast_expr type='[String]?' {{.*value_cast}} writtenType=[String]?
  // CHECK-NEXT: (bind_optional_expr implicit type='AnyObject'
  // CHECK-NEXT: (bind_optional_expr implicit type='AnyObject?'
  // CHECK-NEXT: (declref_expr type='AnyObject?!'
  return obj as? [String]?
}

