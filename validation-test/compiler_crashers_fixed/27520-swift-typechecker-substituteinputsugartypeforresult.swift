// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
{
struct Q<T where g:C{class b
let f=0
var f=b{
