// RUN: %target-typecheck-verify-swift

@available(*, deprecated)
func deprecatedFunc() {}

@available(*, deprecated)
func deprecatedFuncWithReturnValue() -> Int {
    return 3
}

@available(*, deprecated)
func deprecatedFuncWithReturnValue2() -> String {
    return ""
}

@available(*, deprecated)
var deprecatedVariable = ""

@available(*, deprecated)
struct deprecatedType {}

@ignoreDeprecationWarnings
func x() {
    deprecatedFunc()
}

let instanceThatSouldProduceWarning = deprecatedType() // expected-warning {{'deprecatedType' is deprecated}}

var s = deprecatedVariable // expected-warning {{'deprecatedVariable' is deprecated}}

func funcThatShouldProduceWarning() {
    deprecatedFunc() // expected-warning {{'deprecatedFunc()' is deprecated}}
}

struct A {
    @ignoreDeprecationWarnings let x = deprecatedFuncWithReturnValue()
    let shouldWarn = deprecatedFuncWithReturnValue() // expected-warning {{'deprecatedFuncWithReturnValue()' is deprecated}}
}

@ignoreDeprecationWarnings
extension A {
    func aFunc() -> Int {
        deprecatedFuncWithReturnValue()
    }
}

@ignoreDeprecationWarnings
class anotherType {
    func a() {
        _ = deprecatedFuncWithReturnValue()
    }

    let shouldntWarn1 = deprecatedType()
    let shouldntWarn2 = deprecatedFuncWithReturnValue2()
}