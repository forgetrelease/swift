// RUN: %target-swift-frontend -typecheck %s -swift-version 3
// RUN: rm -rf %t && mkdir -p %t && %target-swift-frontend -c -primary-file %s -emit-migrated-file-path %t/no_duplicate_aarch64_use_tbi.swift.result -swift-version 3 -Xllvm -aarch64-use-tbi -o /dev/null
// RUN: diff -u %s.expected %t/no_duplicate_aarch64_use_tbi.swift.result
// RUN: %target-swift-frontend -typecheck %s.expected -swift-version 4
// RUN: %target-swift-frontend -typecheck %t/no_duplicate_aarch64_use_tbi.swift.result -swift-version 4

public func foo(_ f: (Void) -> ()) {}
