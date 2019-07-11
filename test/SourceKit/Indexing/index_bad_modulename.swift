// RUN: %sourcekitd-test -req=index %s -- %s -module-name Swift %mcp_opt -target %target-triple %clang-importer-sdk | %sed_clean > %t.response1
// RUN: diff -u %s.response %t.response1
// RUN: %sourcekitd-test -req=index %s -- %s -module-name 12345 %mcp_opt -target %target-triple %clang-importer-sdk | %sed_clean > %t.response2
// RUN: diff -u %s.response %t.response2

import ObjectiveC
let v: NSObject?

// REQUIRES: objc_interop
