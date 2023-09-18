// RUN: %target-swift-emit-ir %s -parse-stdlib -enable-experimental-feature Embedded -target arm64e-apple-none -Xcc -fptrauth-calls -module-name Swift | %FileCheck %s

// Windows does not have SwiftCompilerSources.
// XFAIL: OS=windows-msvc

// Some verification is blocked on string lookup succeeding.
struct String {}

public func test() { }

// CHECK-LABEL: define {{.*}}void @"$ss4testyyF"()