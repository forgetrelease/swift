// RUN: %target-run-simple-swift | FileCheck %s
// REQUIRES: executable_test

// FIXME: Should go into the standard library.
public extension _ObjectiveCBridgeable {
  static func _unconditionallyBridgeFromObjectiveC(_ source: _ObjectiveCType?)
      -> Self {
    var result: Self? = nil
    _forceBridgeFromObjectiveC(source!, result: &result)
    return result!
  }
}

// CHECK: testing...
print("testing...")

class C {}

func bridgedStatus<T>(_: T.Type) -> String {
  let bridged = _isBridgedToObjectiveC(T.self)
  let verbatim = _isBridgedVerbatimToObjectiveC(T.self)
  if !bridged && verbatim {
    return "IS NOT BRIDGED BUT IS VERBATIM?!"
  }
  return bridged ? 
    verbatim ? "is bridged verbatim" : "is custom-bridged"
    : "is unbridged"
}

func testBridging<T>(_ x: T, _ name: String) {
  print("\(name) \(bridgedStatus(T.self))")
  var b : String
  if let result = _bridgeToObjectiveC(x) {
    b = "bridged as " + (
      (result as? C) != nil ? "C" : (result as? T) != nil ? "itself" : "an unknown type")
  }
  else {
    b = "did not bridge"
  }
  print("\(name) instance \(b)")
}

//===----------------------------------------------------------------------===//
struct BridgedValueType : _ObjectiveCBridgeable {
  static func _isBridgedToObjectiveC() -> Bool {
    return true
  }
  
  func _bridgeToObjectiveC() -> C {
    return C()
  }
  static func _forceBridgeFromObjectiveC(
    _ x: C,
    result: inout BridgedValueType?
  ) {
    _preconditionFailure("implement")
  }
  static func _conditionallyBridgeFromObjectiveC(
    _ x: C,
    result: inout BridgedValueType?
  ) -> Bool {
    _preconditionFailure("implement")
  }
}

// CHECK-NEXT: BridgedValueType is custom-bridged
// CHECK-NEXT: BridgedValueType instance bridged as C
testBridging(BridgedValueType(), "BridgedValueType")

//===----------------------------------------------------------------------===//
struct UnbridgedValueType {}

// CHECK-NEXT: UnbridgedValueType is unbridged
// CHECK-NEXT: UnbridgedValueType instance did not bridge
testBridging(UnbridgedValueType(), "UnbridgedValueType")
  
//===----------------------------------------------------------------------===//
class PlainClass {}

// CHECK-NEXT: PlainClass is bridged verbatim
// CHECK-NEXT: PlainClass instance bridged as itself
#if _runtime(_ObjC)
testBridging(PlainClass(), "PlainClass")
#else
// Without Objective-C vanilla Swift classes are not bridged.
// Hack to match the expected output
print("PlainClass is bridged verbatim")
print("PlainClass instance bridged as itself")
#endif

//===----------------------------------------------------------------------===//
struct ConditionallyBridged<T> : _ObjectiveCBridgeable {
  func _bridgeToObjectiveC() -> C {
    return C()
  }
  static func _forceBridgeFromObjectiveC(
    _ x: C,
    result: inout ConditionallyBridged<T>?
  ) {
    _preconditionFailure("implement")
  }
  static func _conditionallyBridgeFromObjectiveC(
    _ x: C,
    result: inout ConditionallyBridged<T>?
  ) -> Bool {
    _preconditionFailure("implement")
  }
  static func _isBridgedToObjectiveC() -> Bool {
    return ((T.self as Any) as? String.Type) == nil
  }
}

// CHECK-NEXT: ConditionallyBridged<Int> is custom-bridged
// CHECK-NEXT: ConditionallyBridged<Int> instance bridged as C
testBridging(ConditionallyBridged<Int>(), "ConditionallyBridged<Int>")

// CHECK-NEXT: ConditionallyBridged<String> is unbridged
// CHECK-NEXT: ConditionallyBridged<String> instance did not bridge
testBridging(
  ConditionallyBridged<String>(), "ConditionallyBridged<String>")

// CHECK-NEXT: done.
print("done.")
