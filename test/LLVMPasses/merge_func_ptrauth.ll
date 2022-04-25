; RUN: %swift-llvm-opt -swift-merge-functions -swiftmergefunc-threshold=4 %s | %FileCheck %s
; RUN: %swift-llvm-opt -enable-new-pm -swift-merge-functions -swiftmergefunc-threshold=4 %s | %FileCheck %s
; REQUIRES: CODEGENERATOR=AArch64

target triple = "arm64e-apple-macosx11.0.0"

; CHECK: [[RELOC1:@[0-9]+]] = private constant { i8*, i32, i64, i64 } { i8* bitcast (i32 (i32, i32)* @callee1 to i8*), i32 0, i64 0, i64 [[DISCR:[0-9]+]] }, section "llvm.ptrauth"
; CHECK: [[RELOC2:@[0-9]+]] = private constant { i8*, i32, i64, i64 } { i8* bitcast (i32 (i32, i32)* @callee2 to i8*), i32 0, i64 0, i64 [[DISCR]] }, section "llvm.ptrauth"


; CHECK-LABEL: define i32 @simple_func1(i32 %x)
; CHECK: %1 = tail call i32 @simple_func1Tm(i32 %x, i32 27, i32 (i32, i32)* bitcast ({ i8*, i32, i64, i64 }* [[RELOC1]] to i32 (i32, i32)*))
; CHECK: ret i32 %1
define i32 @simple_func1(i32 %x) {
  %sum = add i32 %x, 1
  %sum2 = add i32 %sum, 2
  %sum3 = add i32 %sum2, 3
  %r = call i32 @callee1(i32 %sum3, i32 27)
  ret i32 %r
}

; CHECK-LABEL: define i32 @simple_func2(i32 %x)
; CHECK: %1 = tail call i32 @simple_func1Tm(i32 %x, i32 42, i32 (i32, i32)* bitcast ({ i8*, i32, i64, i64 }* [[RELOC2]] to i32 (i32, i32)*))
; CHECK: ret i32 %1
define i32 @simple_func2(i32 %x) {
  %sum = add i32 %x, 1
  %sum2 = add i32 %sum, 2
  %sum3 = add i32 %sum2, 3
  %r = call i32 @callee2(i32 %sum3, i32 42)
  ret i32 %r
}

define i32 @caller2() {
  %r = call i32 @simple_func2(i32 123)
  ret i32 %r
}

; CHECK-LABEL: define internal i32 @simple_func1Tm(i32 %0, i32 %1, i32 (i32, i32)* %2) {
; CHECK: [[R:%r[0-9]*]] = call i32 %2(i32 %sum3, i32 %1) [ "ptrauth"(i32 0, i64 [[DISCR]]) ]
; CHECK: ret i32 [[R]]

declare i32 @callee1(i32, i32)
declare i32 @callee2(i32, i32)

