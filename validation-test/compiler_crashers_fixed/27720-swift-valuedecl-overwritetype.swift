// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
{struct B<T where I:T{class A{let a=1
}
class a
struct B{struct B{
let f=
