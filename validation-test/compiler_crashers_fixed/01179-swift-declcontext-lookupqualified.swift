// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
class a<f : b, g : b where f.d == g> {
}
protocol b {
typealias d
}
struct c<h : b> : b {
typealias e = a<c<h>, d>
}
struct c<S: Sequence, T where Optional<T> == S.Iterator.Element
