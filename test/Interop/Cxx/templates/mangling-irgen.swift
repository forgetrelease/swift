// RUN: %target-swift-emit-ir %s -I %S/Inputs -enable-cxx-interop | %FileCheck %s

import Mangling

public func recvInstantiation(_ i: inout WrappedMagicInt) {}

// CHECK: define {{(protected |dllexport )?}}swiftcc void @"$s4main17recvInstantiationyySo34__CxxTemplateInst12MagicWrapperIiEVzF"(%TSo34__CxxTemplateInst12MagicWrapperIiEV* nocapture dereferenceable(1) %0)

public func recvInstantiation(_ i: inout WrappedMagicBool) {}

// CHECK: define {{(protected |dllexport )?}}swiftcc void @"$s4main17recvInstantiationyySo34__CxxTemplateInst12MagicWrapperIbEVzF"(%TSo34__CxxTemplateInst12MagicWrapperIbEV* nocapture dereferenceable(1) %0)

public func returnInstantiation() -> WrappedMagicInt {
  return WrappedMagicInt()
}

// CHECK: define {{(protected |dllexport )?}}swiftcc void @"$s4main19returnInstantiationSo34__CxxTemplateInst12MagicWrapperIiEVyF"()

