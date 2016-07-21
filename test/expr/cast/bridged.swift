// RUN: %target-parse-verify-swift

// Test casting through a class type to a bridged value type.

// FIXME: Should go into the standard library.
public extension _ObjectiveCBridgeable {
  static func _unconditionallyBridgeFromObjectiveC(_ source: _ObjectiveCType?)
      -> Self {
    var result: Self? = nil
    _forceBridgeFromObjectiveC(source!, result: &result)
    return result!
  }
}

class NSObject { }

class BridgedClass : NSObject { 
}

class SubclassOfBridgedClass : BridgedClass { }

struct BridgedStruct : _ObjectiveCBridgeable {
  static func _isBridgedToObjectiveC() -> Bool {
    return true
  }
  
  func _bridgeToObjectiveC() -> BridgedClass {
    return BridgedClass()
  }

  static func _forceBridgeFromObjectiveC(
    _ x: BridgedClass,
    result: inout BridgedStruct?
  ) {
  }
  static func _conditionallyBridgeFromObjectiveC(
    _ x: BridgedClass,
    result: inout BridgedStruct?
  ) -> Bool {
    return true
  }
}

func testBridgeDowncast(_ obj: AnyObject, objOpt: AnyObject?, 
                        objImplicitOpt: AnyObject!) -> BridgedStruct? {
  let s1Opt = obj as? BridgedStruct
  var s2Opt = objOpt as? BridgedStruct
  var s3Opt = objImplicitOpt as? BridgedStruct

  // Make sure we seem to have the right result type.
  if s1Opt != nil { return s1Opt }
  s2Opt = s1Opt
  s2Opt = s3Opt
  s3Opt = s1Opt
  _ = s2Opt

  return s1Opt
}

func testBridgeIsa(_ obj: AnyObject, objOpt: AnyObject?, 
                   objImplicitOpt: AnyObject!) {
  if obj is BridgedStruct { }
  if objOpt is BridgedStruct { }
  if objImplicitOpt is BridgedStruct { }
}

func testBridgeDowncastSuperclass(_ obj: NSObject, objOpt: NSObject?,
                                  objImplicitOpt: NSObject!) 
       -> BridgedStruct? {
  _ = obj as? BridgedStruct
  _ = objOpt as? BridgedStruct
  _ = objImplicitOpt as? BridgedStruct
}

func testBridgeDowncastExact(_ obj: BridgedClass, objOpt: BridgedClass?,
                             objImplicitOpt: BridgedClass!) -> BridgedStruct? {
  _ = obj as? BridgedStruct // expected-warning{{conditional cast from 'BridgedClass' to 'BridgedStruct' always succeeds}}
  _ = objOpt as? BridgedStruct
  _ = objImplicitOpt as? BridgedStruct // expected-warning{{conditional cast from 'BridgedClass!' to 'BridgedStruct' always succeeds}}
}

func testExplicitBridging(_ object: BridgedClass, value: BridgedStruct) {
  var object = object
  var value = value
  object = value as BridgedClass
  value = object as BridgedStruct
}

func testBridgingFromSubclass(_ obj: SubclassOfBridgedClass) {
  _ = obj as! BridgedStruct // expected-warning{{forced cast from 'SubclassOfBridgedClass' to 'BridgedStruct' always succeeds; did you mean to use 'as'?}} {{11-14=as}}
  _ = obj as BridgedStruct
}
