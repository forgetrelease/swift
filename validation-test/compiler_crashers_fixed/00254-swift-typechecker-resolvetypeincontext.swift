// This source file is part of the Swift.org open source project
// See http://swift.org/LICENSE.txt for license information

// RUN: not %target-swift-frontend %s -parse
enum S<T> : > T {
       }
}
protocol P {
    func f<T>()(T)-> T
}
func b(c) -> <d>((d) {
}
ias h
