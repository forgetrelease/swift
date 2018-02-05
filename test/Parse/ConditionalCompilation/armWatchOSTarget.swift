// RUN: %swift -typecheck %s -verify -D FOO -D BAR -target arm-apple-watchos2.0 -D FOO -parse-stdlib
// RUN: %swift-ide-test -test-input-complete -source-filename=%s -target arm-apple-watchos2.0

#if os(iOS)
// This block should not parse.
// os(tvOS) or os(watchOS) does not imply os(iOS).
let i: Int = "Hello"
#endif

#if arch(arm) && os(watchOS) && _runtime(_ObjC) && _endian(little) && _native_word_size(32)
class C {}
var x = C()
#endif
var y = x
