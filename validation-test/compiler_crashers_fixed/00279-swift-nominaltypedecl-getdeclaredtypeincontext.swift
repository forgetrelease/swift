// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
struct i<f : f, g: f where g.i == f.i> { b = i) {
}
let i { f
