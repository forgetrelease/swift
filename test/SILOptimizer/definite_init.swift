// RUN: %target-swift-frontend -parse-stdlib -emit-sil %s -o /dev/null

class SomeClass {}

// These are tests for values that are only initialized on some path through the
// CFG.
func partialInit() {

  // Value of trivial type.
  func trivial(ni : Int) {
    var n = ni
    while (n > 0) {
      n -= 1
      var x : Int
      if (n > 2) { continue }
      x = 1
      _ = x
    }
  }
  
  // Tuple with only some elements specified.
  func trivial_tuple() {
    var a : (Int, Int)
    a.1 = 1
    _ = a.1
  }


  func tuple_test(cond : Bool) {
    var x : (SomeClass, SomeClass)

    if cond {
      x.0 = SomeClass()
    } else {
      x.1 = SomeClass()
      _ = x.1
    }
  }
}

func tuple_test() -> Int {
  var t : (Int, Int)

  t.1 = 4

  for _ in 0..<45 {
  }

  t.0 = 1

  for _ in 0..<45 {
  }
  
  return t.1+t.0  // No diagnostic, everything is fully initialized.
}
