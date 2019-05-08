// RUN: %target-typecheck-verify-swift

protocol P0 {
  func call(x: Self)
}

struct ConcreteType {
  func call<T, U>(_ x: T, _ y: U) -> (T, U) {
    return (x, y)
  }

  func call<T, U>(_ fn: @escaping (T) -> U) -> (T) -> U {
    return fn
  }
}

let concrete = ConcreteType()
_ = concrete(1, 3.0)
_ = concrete(concrete, concrete.call as ([Int], Float) -> ([Int], Float))

func generic<T, U>(_ x: T, _ y: U) {
  _ = concrete(x, x)
  _ = concrete(x, y)
}

struct GenericType<T : Collection> {
  let collection: T
  func call<U>(_ x: U) -> Bool where U == T.Element, U : Equatable {
    return collection.contains(x)
  }
}

// Test conditional conformance.
extension GenericType where T.Element : Numeric {
  func call(initialValue: T.Element) -> T.Element {
    return collection.reduce(initialValue, +)
  }
}

let genericString = GenericType<[String]>(collection: ["Hello", "world", "!"])
_ = genericString("Hello")
let genericInt = GenericType<Set<Int>>(collection: [1, 2, 3])
_ = genericInt(initialValue: 1)
