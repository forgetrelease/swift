// RUN: %target-swift-emit-silgen -enable-sil-ownership-verifier -import-objc-header %S/Inputs/array_typedef.h %s | %FileCheck %s

// CHECK-LABEL: sil shared [transparent] [serializable] @$SSo4NameV{{[_0-9a-zA-Z]*}}fC : $@convention(method) (UInt8, UInt8, UInt8, UInt8, @thin Name.Type) -> Name
func useImportedArrayTypedefInit() -> Name {
  return Name(name: (0, 0, 0, 0))
}
