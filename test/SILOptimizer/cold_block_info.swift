// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -module-name main -emit-sil -o %t/output.sil %s -O \
// RUN:   -enable-noreturn-prediction \
// RUN:   -enable-throws-prediction \
// RUN:   -Xllvm --debug-only=cold-block-info 2> %t/debug.txt

// RUN: %FileCheck %s --input-file=%t/debug.txt

enum MyError: Error { case err; case number(Int) }

@inline(never)
func dump(_ s: String) { print(s) }

@inline(never)
func random() -> Int { return Int.random(in: 0..<1024) }

@inline(never)
func listenForConnections() -> Never {
  while true {
    dump("listening!")
  }
}

// CHECK-LABEL: --> Final for $s4main14createLauncheryyF
// CHECK: {
// CHECK-NEXT: $s4main14createLauncheryyF::bb0 -> cold
// CHECK-NEXT: STATISTICS: warm 0 | cold 1
// CHECK-NEXT: }
public func createLauncher() {
  dump("getting ready!")
  listenForConnections()
}

// CHECK-LABEL: --> Final for $s4main6goBoomyS2iSgF
// CHECK: {
// CHECK-NEXT: $s4main6goBoomyS2iSgF::bb1 -> cold
// CHECK-NEXT: STATISTICS: warm 0 | cold 1
// CHECK-NEXT: }
public func goBoom(_ i: Int?) -> Int {
  return i!
}


// CHECK-LABEL: --> Final for $s4main19goBoom_preconditionyySbF
// CHECK: {
// CHECK-NEXT: STATISTICS: warm 0 | cold 0
// CHECK-NEXT: }
public func goBoom_precondition(_ b: Bool) {
  // NOTE: cond_fail instructions aren't terminators, so there's nothing cold.
  precondition(b)
}

// CHECK-LABEL: --> Final for $s4main17goBoom_fatalErroryySiF
// CHECK: {
// CHECK-DAG: $s4main17goBoom_fatalErroryySiF::bb1 -> cold
// CHECK-DAG: $s4main17goBoom_fatalErroryySiF::bb0 -> cold
// CHECK-DAG: $s4main17goBoom_fatalErroryySiF::bb3 -> cold
// CHECK-DAG: $s4main17goBoom_fatalErroryySiF::bb2 -> cold
// CHECK-NEXT: STATISTICS: warm 0
// CHECK: }
public func goBoom_fatalError(_ i: Int) {
  for i in 0..<i {
    dump("do something")
  }
  fatalError("kablam")
}


// CHECK-LABEL: --> Final for $s4main13sirThrowsALotyS2iKF
// CHECK: {
// CHECK-DAG: $s4main13sirThrowsALotyS2iKF::bb3 -> cold
// CHECK-DAG: $s4main13sirThrowsALotyS2iKF::bb2 -> cold
// CHECK-DAG: $s4main13sirThrowsALotyS2iKF::bb4 -> cold
// CHECK-DAG: $s4main13sirThrowsALotyS2iKF::bb5 -> cold
// CHECK-NEXT: STATISTICS: warm 0
// CHECK: }
@inline(never)
public func sirThrowsALot(_ i: Int) throws -> Int {
  dump("entry")
  switch i {
    case 0:
      dump("case 0")
      return random()
    case 1:
      dump("case 1")
      throw MyError.err
    default:
      dump("case n")
      throw MyError.number(i)
  }
}

// CHECK-LABEL: --> Final for $s4main22catchTheseThrowsSimpleyS2iF
// CHECK: {
// CHECK-DAG: $s4main22catchTheseThrowsSimpleyS2iF::bb1 -> warm
// CHECK-DAG: $s4main22catchTheseThrowsSimpleyS2iF::bb2 -> cold
// CHECK: }
public func catchTheseThrowsSimple(_ i: Int) -> Int {
  if let ans = try? sirThrowsALot(i) {
    return ans
  } else {
    dump("did throw!")
    return random()
  }
}

// Make sure there's at least 3 cold blocks and no warm ones.
// Inlining and multiple runs of the analysis, and especially platform
// differences, can yield different numbers of blocks being analyzed!

// CHECK-LABEL: --> Final for $s4main012pleasePleaseC0yySiKF
// CHECK-COUNT-3: -> cold
// CHECK: STATISTICS: warm 0
// CHECK: }
public func pleasePleasePlease(_ i: Int) throws {
  if i > random() {
    fatalError("oof")
  } else {
    throw MyError.number(i)
  }
}
