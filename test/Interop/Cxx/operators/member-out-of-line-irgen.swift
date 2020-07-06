// RUN: %target-swift-emit-ir %s -I %S/Inputs -enable-cxx-interop | %FileCheck %s
//
// We can't yet call member functions correctly on Windows (SR-13129).
// XFAIL: OS=windows-msvc

import MemberOutOfLine

public func add(_ lhs: inout IntBox, _ rhs: IntBox) -> IntBox { lhs + rhs }

// CHECK: call {{i32|i64}} [[NAME:@_ZN6IntBoxplES_]](%struct.IntBox* %{{[0-9]+}}, {{i32|\[1 x i32\]|i64}} %{{[0-9]+}})
// CHECK: declare {{(dso_local )?}}{{i32|i64}} [[NAME]](%struct.IntBox*, {{i32|\[1 x i32\]|i64}})
