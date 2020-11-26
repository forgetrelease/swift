////===----------------------------------------------------------------------===//
////
//// This source file is part of the Swift.org open source project
////
//// Copyright (c) 2020 Apple Inc. and the Swift project authors
//// Licensed under Apache License v2.0 with Runtime Library Exception
////
//// See https://swift.org/LICENSE.txt for license information
//// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
////
////===----------------------------------------------------------------------===//

import Swift
import Dispatch
@_implementationOnly import _SwiftConcurrencyShims

// ==== Task Group -------------------------------------------------------------

extension Task {

  /// Starts a new task group which provides a scope in which a dynamic number of
  /// tasks may be spawned.
  ///
  /// Tasks added to the group by `group.add()` will automatically be awaited on
  /// when the scope exits. If the group exits by throwing, all added tasks will
  /// be cancelled and their results discarded.
  ///
  /// ### Implicit awaiting
  /// When results of tasks added to the group need to be collected, one can
  /// gather their results using the following pattern:
  ///
  ///     while let result = await group.next() {
  ///       // some accumulation logic (e.g. sum += result)
  ///     }
  ///
  /// ### Thrown errors
  /// When tasks are added to the group using the `group.add` function, they may
  /// immediately begin executing. Even if their results are not collected explicitly
  /// and such task throws, and was not yet cancelled, it may result in the `withGroup`
  /// throwing.
  ///
  /// ### Cancellation
  /// If an error is thrown out of the task group, all of its remaining tasks
  /// will be cancelled and the `withGroup` call will rethrow that error.
  ///
  /// Individual tasks throwing results in their corresponding `try group.next()`
  /// call throwing, giving a chance to handle individual errors or letting the
  /// error be rethrown by the group.
  ///
  /// Postcondition:
  /// Once `withGroup` returns it is guaranteed that the `group` is *empty*.
  ///
  /// This is achieved in the following way:
  /// - if the body returns normally:
  ///   - the group will await any not yet complete tasks,
  ///     - if any of those tasks throws, the remaining tasks will be cancelled,
  ///   - once the `withGroup` returns the group is guaranteed to be empty.
  /// - if the body throws:
  ///   - all tasks remaining in the group will be automatically cancelled.
  // TODO: Do we have to add a different group type to accommodate throwing
  //       tasks without forcing users to use Result?  I can't think of how that
  //       could be propagated out of the callback body reasonably, unless we
  //       commit to doing multi-statement closure typechecking.
  public static func withGroup<TaskResult, BodyResult>(
    resultType: TaskResult.Type,
    returning returnType: BodyResult.Type = BodyResult.self,
    cancelOutstandingTasksOnReturn: Bool = false,
    body: @escaping ((inout Task.Group<TaskResult>) async throws -> BodyResult)
  ) async throws -> BodyResult {
    let drainPendingTasksOnSuccessfulReturn = !cancelOutstandingTasksOnReturn
    let parent = Builtin.getCurrentAsyncTask()

    // Set up the job flags for a new task.
    var groupFlags = JobFlags()
    groupFlags.kind = .task
    groupFlags.priority = getJobFlags(parent).priority
    groupFlags.isFuture = true
    groupFlags.isChildTask = true

    // 1. Prepare the Group task
    var group = Task.Group<TaskResult>(parentTask: parent)

    let (groupChannelTask, _) =
      Builtin.createAsyncTaskFuture(groupFlags.bits, parent) { () async throws -> BodyResult in
        await try body(&group)
      }
    let groupHandle = Handle<BodyResult>(task: groupChannelTask)

    // 2.0) Run the task!
    DispatchQueue.global(priority: .default).async { // FIXME: use executors when they land
      groupHandle.run()
    }

    // 2.1) ensure that if we fail and exit by throwing we will cancel all tasks,
    // if we succeed, there is nothing to cancel anymore so this is noop
    defer { group.cancelAll() }

    // 2.2) Await the group completing it's run ("until the withGroup returns")
    let result = await try groupHandle.get() // if we throw, so be it -- group tasks will be cancelled

// TODO: do drain before exiting
//    if drainPendingTasksOnSuccessfulReturn {
//      // drain all outstanding tasks
//      while await try group.next() != nil {
//        continue // awaiting all remaining tasks
//      }
//    }

    return result
  }

  /// A task group serves as storage for dynamically started tasks.
  ///
  /// Its intended use is with the `Task.withGroup` function.
  /* @unmoveable */
  public struct Group<TaskResult> {
    // private let parentTask: Builtin.NativeObject // TODO: maybe use the groupChannelTask as parent for all add()ed tasks instead and remove this one

    /// Channel task into which child tasks offer their results,
    /// and the `next()` function polls those results from.
    private let groupChannelTask: Builtin.NativeObject

    /// No public initializers
    init(parentTask: Builtin.NativeObject) {
      var flags = JobFlags()
      flags.kind = .task // TODO: taskGroup?
      flags.priority = getJobFlags(parentTask).priority
      flags.isChannel = true
      flags.isChildTask = true
      // TODO: make sure we inherit everything from the parent
      let (groupChannelTask, _) = Builtin.createAsyncTask(flags.bits, parentTask, { () async throws -> () in
        () // ...nothing...
      })
      self.groupChannelTask = groupChannelTask
    }

    // Swift will statically prevent this type from being copied or moved.
    // For now, that implies that it cannot be used with generics.

    /// Add a child task to the group.
    ///
    /// ### Error handling
    /// Operations are allowed to `throw`, in which case the `await try next()`
    /// invocation corresponding to the failed task will re-throw the given task.
    ///
    /// The `add` function will never (re-)throw errors from the `operation`.
    /// Instead, the corresponding `next()` call will throw the error when necessary.
    ///
    /// - Parameters:
    ///   - overridingPriority: override priority of the operation task
    ///   - operation: operation to execute and add to the group
    @discardableResult
    public mutating func add(
      overridingPriority: Priority? = nil,
      operation: @escaping () async throws -> TaskResult,
      file: String = #file, line: UInt = #line
    ) async -> Task.Handle<TaskResult> {
      var flags = JobFlags()
      flags.kind = .task
      flags.priority = overridingPriority ?? getJobFlags(groupChannelTask).priority
      flags.isFuture = true
      flags.isChildTask = true
      flags.isGroupChild = true

      let (childTask, _) =
        Builtin.createAsyncTaskFuture(flags.bits, groupChannelTask, operation)
      taskChannelAddPending(groupChannelTask, childTask)
      let handle = Handle<TaskResult>(task: childTask)

      // FIXME: use executors or something else to launch the task
      DispatchQueue.global(priority: .default).async {
        // print(">>> run (task added at \(file):\(line))")
        handle.run()
      }

      return handle
    }

    /// Wait for a child task to complete and return the result it returned,
    /// or else return.
    ///
    /// Order of completions is *not* guaranteed to be same as submission order,
    /// rather the order of `next()` calls completing is by completion order of
    /// the tasks. This differentiates task groups from streams (
    public mutating func next() async throws -> TaskResult? {
      // We reuse the taskFutureWait -> swift_task_future_wait since it seems to have special sauce,
      // but actually we
      print("error: next[\(#line)]: invoked\n")
      let rawResult = await taskFutureWait(on: self.groupChannelTask)
//      let rawResult = await taskChannelPoll(on: self.groupChannelTask) // TODO: consider if we can implement this way

//      guard rawResult.storage == nil else {
//        // Polling returned "no result", it means there is nothing to await on anymore
//        // i.e. there are no more pending tasks / "we drained all tasks"
//        print("\(#function): return nil")
//        return nil
//      }

      if rawResult.hadErrorResult {
        // Throw the result on error.
        print("error: next[\(#line)]: after await, error: \(rawResult)");
        throw unsafeBitCast(rawResult.storage, to: Error.self)
      }

      // Take the value on success
      print("error: next[\(#line)]: after await, result: \(rawResult)");
      let storagePtr =
        rawResult.storage.bindMemory(to: Optional<TaskResult>.self, capacity: 1)
      return UnsafeMutablePointer<Optional<TaskResult>>(mutating: storagePtr).pointee
    }

    /// Query whether the group has any remaining tasks.
    ///
    /// Task groups are always empty upon entry to the `withGroup` body, and
    /// become empty again when `withGroup` returns (either by awaiting on all
    /// pending tasks or cancelling them).
    ///
    /// - Returns: `true` if the group has no pending tasks, `false` otherwise.
    public var isEmpty: Bool {
      taskChannelIsEmpty(self.groupChannelTask)
    }

    /// Cancel all the remaining tasks in the group.
    ///
    /// A cancelled group will not will NOT accept new tasks being added into it.
    ///
    /// Any results, including errors thrown by tasks affected by this
    /// cancellation, are silently discarded.
    ///
    /// - SeeAlso: `Task.addCancellationHandler`
    public mutating func cancelAll() {
      taskCancel(groupChannelTask) // TODO: do we also have to go over all child tasks and cancel there?
    }
  }
}

/// ==== -----------------------------------------------------------------------

//@_silgen_name("swift_task_channel_offer")
//func taskChannelOffer(
//  channel: Builtin.NativeObject,
//  completedTask: Builtin.NativeObject
//)

/// SeeAlso: ChannelPollResult
struct RawChannelPollResult {
  let status: ChannelPollStatus
  let storage: UnsafeRawPointer

  var hadAnyResult: Bool {
    status != .waiting
  }
}

enum ChannelPollStatus: Int {
  case empty   = 0
  case waiting = 1
  case success = 2
  case error   = 3
}

@_silgen_name("swift_task_channel_poll")
func taskChannelPoll(
  on channelTask: Builtin.NativeObject
) async -> RawTaskFutureWaitResult
// ) async -> RawChannelPollResult

@_silgen_name("swift_task_channel_is_empty")
func taskChannelIsEmpty(
  _ channelTask: Builtin.NativeObject
) -> Bool

@_silgen_name("swift_task_channel_add_pending")
func taskChannelAddPending(
  _ channelTask: Builtin.NativeObject,
  _ childTask: Builtin.NativeObject
)
