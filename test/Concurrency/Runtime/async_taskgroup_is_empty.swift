// RUN: %target-run-simple-swift(-Xfrontend -enable-experimental-concurrency) | %FileCheck %s --dump-input always
// REQUIRES: executable_test
// REQUIRES: concurrency
// REQUIRES: OS=macosx
// REQUIRES: CPU=x86_64

import Dispatch

// ==== ------------------------------------------------------------------------
// MARK: "Infrastructure" for the tests

extension DispatchQueue {
  func async<R>(operation: @escaping () async -> R) -> Task.Handle<R> {
    let handle = Task.runDetached(operation: operation)

    // Run the task
    _ = { self.async { handle.run() } }() // force invoking the non-async version

    return handle
  }
}

func asyncEcho(_ value: Int) async -> Int {
  value
}

// ==== ------------------------------------------------------------------------
// MARK: Tests

func test_taskGroup_isEmpty() {
  // CHECK: main task

  let taskHandle = DispatchQueue.main.async { () async -> Int in
    return await try! Task.withGroup(resultType: Int.self) { (group) async -> Int in
      // CHECK: before add: isEmpty=true
      print("before add: isEmpty=\(group.isEmpty)")

      await group.add {
        sleep(2)
        return await asyncEcho(1)
      }

      // CHECK: while add running, outside: isEmpty=false
      print("while add running, outside: isEmpty=\(group.isEmpty)")

      // CHECK: next: 1
      while let value = await try! group.next() {
        print("next: \(value)")
      }

      // CHECK: after draining tasks: isEmpty=true
      print("after draining tasks: isEmpty=\(group.isEmpty)")
      return 0
    }
  }

  DispatchQueue.main.async { () async in
    _ = await try! taskHandle.get()
    exit(0)
  }

  print("main task")
}

test_taskGroup_isEmpty()

dispatchMain()
