// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
class S<T{func a<h{func b<T where h.a:a{{{}}}}class A:BooleanType
