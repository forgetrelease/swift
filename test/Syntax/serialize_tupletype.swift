// RUN: %swift-syntax-test -input-source-filename %s -serialize-raw-tree > %t.result
// RUN: diff -u %s.result %t.result

typealias x = (_ b: Int, _: String)
