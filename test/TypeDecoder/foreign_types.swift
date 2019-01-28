// RUN: %empty-directory(%t)

// RUN: %target-build-swift -I %S/../ClangImporter/Inputs/custom-modules -I %S/../Inputs/custom-modules -emit-executable -emit-module %s -g -o %t/foreign_types
// RUN: sed -ne '/\/\/ *DEMANGLE: /s/\/\/ *DEMANGLE: *//p' < %s > %t/input
// RUN: %lldb-moduleimport-test-with-sdk %t/foreign_types -type-from-mangled=%t/input | %FileCheck %s

// REQUIRES: objc_interop
// REQUIRES: SR9782

import Foundation
import CoreCooling
import ErrorEnums

/*
do {
    let x1 = CCRefrigeratorCreate(kCCPowerStandard)
    let x2 = MyError.good
    let x3 = MyError.Code.good
    let x4 = RenamedError.good
    let x5 = RenamedError.Code.good
    let x6 = Wrapper.MemberEnum.A
    let x7 = WrapperByAttribute(0)
    let x8 = NSSize(width: 0, height: 0)
}

do {
    let x1 = CCRefrigerator.self
    let x2 = MyError.self
    let x3 = MyError.Code.self
    let x4 = RenamedError.self
    let x5 = RenamedError.Code.self
    let x6 = Wrapper.MemberEnum.self
    let x7 = WrapperByAttribute.self
    let x8 = NSSize.self
}
*/

// DEMANGLE: $sSo17CCRefrigeratorRefaD
// DEMANGLE: $sSo7MyErrorVD
// DEMANGLE: $sSo7MyErrorLeVD
// DEMANGLE: $sSo14MyRenamedErrorVD
// DEMANGLE: $sSo14MyRenamedErrorLeVD
// DEMANGLE: $sSo12MyMemberEnumVD
// DEMANGLE: $sSo18WrapperByAttributeaD
// DEMANGLE: $sSo6NSSizeaD
// DEMANGLE: $sSo6CGSizeVD

// CHECK: CCRefrigerator
// CHECK: MyError.Code
// CHECK: MyError
// CHECK: RenamedError.Code
// CHECK: RenamedError
// CHECK: Wrapper.MemberEnum
// CHECK: WrapperByAttribute
// CHECK: NSSize
// CHECK: CGSize

// DEMANGLE: $sSo17CCRefrigeratorRefamD
// DEMANGLE: $sSo7MyErrorVmD
// DEMANGLE: $sSC7MyErrorLeVmD
// DEMANGLE: $sSo14MyRenamedErrorVmD
// DEMANGLE: $sSC14MyRenamedErrorLeVmD
// DEMANGLE: $sSo12MyMemberEnumVmD
// DEMANGLE: $sSo18WrapperByAttributeamD
// DEMANGLE: $sSo6NSSizeamD
// DEMANGLE: $sSo6CGSizeVmD

// CHECK: CCRefrigerator.Type
// CHECK: MyError.Code.Type
// CHECK: MyError.Type
// CHECK: RenamedError.Code.Type
// CHECK: RenamedError.Type
// CHECK: Wrapper.MemberEnum.Type
// CHECK: WrapperByAttribute.Type
// CHECK: NSSize.Type
// CHECK: CGSize.Type
