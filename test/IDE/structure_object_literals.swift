// RUN: %swift-ide-test -structure -source-filename %s | FileCheck %s

struct S: _ColorLiteralConvertible {
  init(red: Float, green: Float, blue: Float, alpha: Float) {}
}

// CHECK: <gvar>let <name>y</name>: S = <object-literal-expression>[#<name>colorLiteral</name>(<param><name>red</name>: 1</param>, <param><name>green</name>: 0</param>, <param><name>blue</name>: 0</param>, <param><name>alpha</name>: 1</param>)#]</object-literal-expression></gvar>
let y: S = [#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)#]

struct I: _ImageLiteralConvertible {
  init?(imageLiteral: String) {}
}

// CHECK: <gvar>let <name>z</name>: I? = <object-literal-expression>[#<name>Image</name>(<param><name>imageLiteral</name>: "hello.png"</param>)#]</object-literal-expression></gvar>
let z: I? = [#Image(imageLiteral: "hello.png")#]
