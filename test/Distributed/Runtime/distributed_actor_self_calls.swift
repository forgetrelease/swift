// RUN: %target-swift-emit-silgen -enable-experimental-distributed -disable-availability-checking -parse-as-library %s | %FileCheck %s
// RUN: %target-run-simple-swift(-Xfrontend -enable-experimental-distributed -Xfrontend -disable-availability-checking -parse-as-library)

// REQUIRES: executable_test
// REQUIRES: concurrency
// REQUIRES: distributed

// rdar://76038845
// UNSUPPORTED: use_os_stdlib
// UNSUPPORTED: back_deployment_runtime

import _Distributed

distributed actor Philosopher {

  distributed func think() {
  }

  // CHECK: sil hidden [ossa] @$s28distributed_actor_self_calls11PhilosopherC10stopEatingyyF : $@convention(method) (@guaranteed Philosopher) -> () {
  func stopEating() { // NOTE: marking this async solves the issue; we find the async context then
    self.think()

    // Confirm we're calling the function directly, rather than the distributed thunk
    // Calling the thunk would crash, because it is async (and throws), and as we're not in an async function
    // trying to get the async context to call the async thunk would fail here.
    //
    // CHECK:        // function_ref Philosopher.think()
    // CHECK-NEXT:   [[E:%[0-9]+]] = function_ref @$s28distributed_actor_self_calls11PhilosopherC5thinkyyF : $@convention(method) (@guaranteed Philosopher) -> ()
  }
}


// ==== Fake Transport ---------------------------------------------------------

struct ActorAddress: Sendable, Hashable, Codable {
  let address: String
  init(parse address : String) {
    self.address = address
  }
}

struct FakeActorSystem: DistributedActorSystem {

  func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act?
      where Act: DistributedActor,
            Act.ID == ActorID {
    return nil
  }

  func assignID<Act>(_ actorType: Act.Type) -> AnyActorIdentity
      where Act: DistributedActor {
    .init(ActorAddress(parse: ""))
  }

  public func actorReady<Act>(_ actor: Act)
      where Act: DistributedActor {
    print("\(#function):\(actor)")
  }

  func resignID(_ id: AnyActorIdentity) {}
}

typealias DefaultDistributedActorSystem = FakeActorSystem

// ==== Execute ----------------------------------------------------------------

func test(transport: FakeActorSystem) async {
  _ = Philosopher(system: system)
}

@main struct Main {
  static func main() async {
    await test(transport: FakeActorSystem())
  }
}
