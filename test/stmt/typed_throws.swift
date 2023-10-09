// RUN: %target-typecheck-verify-swift -enable-experimental-feature TypedThrows

enum MyError: Error {
case failed
case epicFailed
}

enum HomeworkError: Error {
case dogAteIt
case forgot
}

func processMyError(_: MyError) { }

func doSomething() throws(MyError) { }
func doHomework() throws(HomeworkError) { }

func testDoCatchErrorTyped() {
  #if false
  // FIXME: Deal with throws directly in the do...catch blocks.
  do {
    throw MyError.failed
  } catch {
    assert(error == .failed)
    processMyError(error)
  }
  #endif

  // Throwing a typed error in a do...catch catches the error with that type.
  do {
    try doSomething()
  } catch {
    assert(error == .failed)
    processMyError(error)
  }

  // Throwing a typed error in a do...catch lets us pattern-match against that
  // type.
  do {
    try doSomething()
  } catch .failed {
    // okay, matches one of the cases of MyError
  } catch {
    assert(error == .epicFailed)
  }

  // Rethrowing an error because the catch is not exhaustive.
  do {
    try doSomething()
    // expected-error@-1{{errors thrown from here are not handled because the enclosing catch is not exhaustive}}
  } catch .failed {
  }

  // "as X" errors are never exhaustive.
  do {
    try doSomething()
    // FIXME: should error errors thrown from here are not handled because the enclosing catch is not exhaustive
  } catch let error as MyError { // expected-warning{{'as' test is always true}}
    _ = error
  }

    // Rethrowing an error because the catch is not exhaustive.
  do {
    try doSomething()
    // expected-error@-1{{errors thrown from here are not handled because the enclosing catch is not exhaustive}}
  } catch is HomeworkError {
    // expected-warning@-1{{cast from 'MyError' to unrelated type 'HomeworkError' always fails}}
  }
}

func testDoCatchMultiErrorType() {
  // Throwing different typed errors results in 'any Error'
  do {
    try doSomething()
    try doHomework()
  } catch .failed { // expected-error{{type 'any Error' has no member 'failed'}}
    
  } catch {
    let _: Int = error // expected-error{{cannot convert value of type 'any Error' to specified type 'Int'}}
  }  
}

func testDoCatchRethrowsUntyped() throws {
  do {
    try doSomething()
  } catch .failed {
  } // okay, rethrows with a conversion to 'any Error'
}

func testDoCatchRethrowsTyped() throws(HomeworkError) {
  do {
    try doHomework()
  } catch .dogAteIt {
  } // okay, rethrows

  do {
    try doSomething()
  } catch .failed {
    
  } // expected-error{{thrown expression type 'MyError' cannot be converted to error type 'HomeworkError'}}

  do {
    try doSomething()
    try doHomework()
  } catch let e as HomeworkError {
    _ = e
  } // expected-error{{thrown expression type 'any Error' cannot be converted to error type 'HomeworkError'}}

  do {
    try doSomething()
    try doHomework()
  } catch {

  } // okay, the thrown 'any Error' has been caught
}

func testTryIncompatibleTyped() throws(HomeworkError) {
  try doHomework() // okay

  try doSomething() // FIXME: should error
}
