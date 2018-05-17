// RUN: %target-swift-frontend -typecheck %s -swift-version 4
// RUN: %target-swift-frontend -typecheck -update-code -primary-file %s -emit-migrated-file-path %t.result -swift-version 4
// RUN: diff -u %s.expected %t.result
// RUN: %target-swift-frontend -typecheck %s.expected

_ = [1,2,3].flatMap { $0 < 2 ? nil : $0 }
func foo(x: UnsafeMutablePointer<Int>) {
  x.initialize(to: 2, count: 2)
}
