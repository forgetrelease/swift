// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
{enum S<T where B:C{struct B{var b=""enum a{var d=B?
