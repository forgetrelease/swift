// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
struct S<T where g:T{{}struct d{class A{}class c:A{enum S{struct c{class A{struct T
