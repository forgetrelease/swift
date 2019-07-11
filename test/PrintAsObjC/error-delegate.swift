// Please keep this file in alphabetical order!

// REQUIRES: objc_interop

// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -import-objc-header %S/Inputs/error-delegate.h -emit-module -o %t %s
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -import-objc-header %S/Inputs/error-delegate.h -parse-as-library %t/error-delegate.swiftmodule -typecheck -emit-objc-header-path %t/error-delegate.h

// RUN: %FileCheck %s < %t/error-delegate.h
// RUN: %check-in-clang %t/error-delegate.h

import Foundation

// CHECK-LABEL: @interface Test : NSObject <ABCErrorProtocol>
// CHECK-NEXT: - (void)didFail:(NSError * _Nonnull)error;
// CHECK-NEXT: - (void)didFailOptional:(NSError * _Nullable)error;
// CHECK-NEXT: - (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
// CHECK-NEXT: @end
class Test : NSObject, ABCErrorProtocol {
  func didFail(_ error: Swift.Error) {}
  func didFailOptional(_ error: Swift.Error?) {}
}
