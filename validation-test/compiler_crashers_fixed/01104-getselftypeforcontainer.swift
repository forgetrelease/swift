// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
struct l<l : d> : d {
i j i() {
}
}
protocol f {
}
protocol d : f {
struct c<d : Sequence> {
}
func a<d>() -> [c<d>] {
}
func a<T>() -> (T, T -> T) -> T {
}
func r<t>() {
f f {
}
}
struct i<o : u> {
}
func r<o>() -> [i<o>] {
}
class g<t : g> {
}
class g: g {
}
class n : h {
}
protocol g {
func i() -> l  func o() -> m {
}
}
func j<t k t: g, t: n>(s: t) {
}
protocol r {
}
protocol f : r {
