// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
protocol p {
    class func g()
}
class h: p {
    class func g() { }
}
(h() as p).dynamicType.g()
protocol p {
}
protocol h : p {
}
protocol g : p {
}
protocol n {
  o t = p
}
struct h : n {
  t : n q m.t == m> (h: m) {
}
func q<t : n q t.t == g> (h: t) {
}
q(h())
func r(g: m) -> <s>(() -> s) -> n
func m<u>() -> (u, u -> u) -> u {
   p o p.s = {
}
 {
   u) eturn s(c, u)
    }
}
func n(r:-> t {
    r})
func p<p>() -> (p, p -> p) -> p {
  ) {
      (e: o,
