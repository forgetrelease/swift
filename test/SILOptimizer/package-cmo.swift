// RUN: %empty-directory(%t)
// RUN: %target-build-swift -O -wmo -Xfrontend -experimental-package-cmo -Xfrontend -experimental-allow-non-resilient-access -parse-as-library -emit-module -emit-module-path=%t/Submodule.swiftmodule -module-name=Submodule -package-name Pkg %S/Inputs/cross-module/default-submodule.swift -c -o %t/submodule.o
// RUN: %target-build-swift -O -wmo -Xfrontend -experimental-package-cmo -Xfrontend -experimental-allow-non-resilient-access -parse-as-library -emit-module -emit-module-path=%t/Module.swiftmodule -module-name=Module -package-name Pkg -I%t -I%S/Inputs/cross-module %S/Inputs/cross-module/default-module.swift -c -o %t/module.o
// RUN: %target-build-swift -O -wmo -Xfrontend -experimental-package-cmo -Xfrontend -experimental-allow-non-resilient-access -parse-as-library -emit-tbd -emit-tbd-path %t/ModuleTBD.tbd -emit-module -emit-module-path=%t/ModuleTBD.swiftmodule -module-name=ModuleTBD -package-name Pkg -I%t -I%S/Inputs/cross-module %S/Inputs/cross-module/default-module.swift -c -o %t/moduletbd.o -Xfrontend -tbd-install_name -Xfrontend module

// RUN: %target-build-swift -O -wmo -module-name=Main -package-name Pkg -I%t -I%S/Inputs/cross-module %s -emit-sil -o %t/Main.sil
// RUN: %FileCheck %s < %t/Main.sil

// RUN: %target-build-swift -O -wmo -module-name=Main -package-name Pkg -I%t -I%S/Inputs/cross-module %s -Xfrontend -serialization-failed -Xfrontend -verify

// REQUIRES: swift_in_compiler

import Module
import ModuleTBD

// CHECK-LABEL: sil_global public_external @$s6Module0A6StructV22privateFunctionPointeryS2icvpZ : $@callee_guaranteed (Int) -> Int{{$}}
public func callPrivateFunctionPointer(_ x: Int) -> Int {
  return Module.ModuleStruct.privateFunctionPointer(x)
}

// CHECK-LABEL: sil_global package_external @$s6Module03PkgA6StructV14closurePointeryS2icvpZ : $@callee_guaranteed (Int) -> Int{{$}}
package func callStaticPkgClosurePointer(_ x: Int) -> Int {
  return Module.PkgModuleStruct.closurePointer(x)
}

// CHECK-LABEL: sil_global public_external [serialized] @$s6Module0A6StructV21publicFunctionPointeryS2icvpZ : $@callee_guaranteed (Int) -> Int = {
  // function_ref incrementByThree(_:)
// CHECK:       [[REF:%.*]] = function_ref @$s6Module16incrementByThreeyS2iF : $@convention(thin) (Int) -> Int
// CHECK-NEXT:  [[INITVAL:%.*]] = thin_to_thick_function [[REF]] : $@convention(thin) (Int) -> Int to $@callee_guaranteed (Int) -> Int
// CHECK-NEXT: }

// CHECK-LABEL: sil_global package_external [serialized] @$s6Module03PkgA6StructV11funcPointeryS2icvpZ : $@callee_guaranteed (Int) -> Int = {
// CHECK:      [[REF:%.*]] = function_ref @$s6Module7pkgFuncyS2iF : $@convention(thin) (Int) -> Int
// CHECK-NEXT: [[INITVAL:%.*]] = thin_to_thick_function [[REF]] : $@convention(thin) (Int) -> Int to $@callee_guaranteed (Int) -> Int
// CHECK-NEXT: }

// CHECK-LABEL: sil @$s4Main25callPublicFunctionPointeryS2iF : $@convention(thin) (Int) -> Int {
// CHECK:         global_addr @$s6Module0A6StructV21publicFunctionPointeryS2icvpZ : $*@callee_guaranteed (Int) -> Int
// CHECK:         load
// CHECK:         apply
// CHECK:       } // end sil function '$s4Main25callPublicFunctionPointeryS2iF'
public func callPublicFunctionPointer(_ x: Int) -> Int {
  return Module.ModuleStruct.publicFunctionPointer(x)
}

// CHECK-LABEL: sil package @$s4Main28callStaticPkgFunctionPointeryS2iF : $@convention(thin) (Int) -> Int {
// CHECK:         global_addr @$s6Module03PkgA6StructV11funcPointeryS2icvpZ : $*@callee_guaranteed (Int) -> Int
// CHECK:         load
// CHECK:         apply
// CHECK:       } // end sil function '$s4Main28callStaticPkgFunctionPointeryS2iF'
package func callStaticPkgFunctionPointer(_ x: Int) -> Int {
  return Module.PkgModuleStruct.funcPointer(x)
}

// CHECK-LABEL: sil @$s4Main24callPrivateCFuncInModuleSiyF : $@convention(thin) () -> Int {
// CHECK:         function_ref @$s6Module16callPrivateCFuncSiyF
// CHECK:       } // end sil function '$s4Main24callPrivateCFuncInModuleSiyF'
public func callPrivateCFuncInModule() -> Int {
  return Module.callPrivateCFunc() // expected-remark {{failed to serialize callee $s6Module16callPrivateCFuncSiyF}}
}

// CHECK-LABEL: sil @$s4Main22usePrivateCVarInModuleSiyF : $@convention(thin) () -> Int {
// CHECK:         function_ref @$s6Module14usePrivateCVarSiyF
// CHECK:       } // end sil function '$s4Main22usePrivateCVarInModuleSiyF'
public func usePrivateCVarInModule() -> Int {
  return Module.usePrivateCVar() // expected-remark {{failed to serialize callee $s6Module14usePrivateCVarSiyF}}
}

// CHECK-LABEL: sil @$s4Main11doIncrementyS2iF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main11doIncrementyS2iF'
// CHECK-LABEL: sil public_external @$s6Module16incrementByThreeyS2iF : $@convention(thin) (Int) -> Int {
public func doIncrement(_ x: Int) -> Int {
  return Module.incrementByThree(x)
}

// CHECK-LABEL: sil package @$s4Main11callPkgFuncyS2iF : $@convention(thin) (Int) -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main11callPkgFuncyS2iF'
// CHECK-LABEL: sil public_external @$s6Module7pkgFuncyS2iF : $@convention(thin) (Int) -> Int {
package func callPkgFunc(_ x: Int) -> Int {
  return Module.pkgFunc(x)
}

// CHECK-LABEL: sil @$s4Main19doIncrementWithCallyS2iF
// CHECK:         function_ref @$s9Submodule19incrementByOneNoCMOyS2iF
// CHECK:       } // end sil function '$s4Main19doIncrementWithCallyS2iF'
public func doIncrementWithCall(_ x: Int) -> Int {
  return Module.incrementByThreeWithCall(x)
}

// CHECK-LABEL: sil package @$s4Main16callPkgFuncNoCMOyS2iF : $@convention(thin) (Int) -> Int {
// CHECK:         function_ref @$s9Submodule15subPkgFuncNoCMOyS2iF
// CHECK:       } // end sil function '$s4Main16callPkgFuncNoCMOyS2iF'
package func callPkgFuncNoCMO(_ x: Int) -> Int {
  return Module.pkgFuncNoCMO(x)
}

// CHECK-LABEL: sil @$s4Main14doIncrementTBDyS2iF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main14doIncrementTBDyS2iF'
public func doIncrementTBD(_ x: Int) -> Int {
  return ModuleTBD.incrementByThree(x)
}

// CHECK-LABEL: sil package @$s4Main14callPkgFuncTBDyS2iF : $@convention(thin) (Int) -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main14callPkgFuncTBDyS2iF'
package func callPkgFuncTBD(_ x: Int) -> Int {
  return ModuleTBD.pkgFunc(x)
}

// CHECK-LABEL: sil @$s4Main22doIncrementTBDWithCallyS2iF
// CHECK:         function_ref @$s9ModuleTBD24incrementByThreeWithCallyS2iF
// CHECK:       } // end sil function '$s4Main22doIncrementTBDWithCallyS2iF'
// CHECK-LABEL: sil @$s9ModuleTBD24incrementByThreeWithCallyS2iF : $@convention(thin) (Int) -> Int
public func doIncrementTBDWithCall(_ x: Int) -> Int {
  return ModuleTBD.incrementByThreeWithCall(x) // expected-remark {{failed to serialize callee $s9ModuleTBD24incrementByThreeWithCallyS2iF}}
}

// CHECK-LABEL: sil package @$s4Main19callPkgFuncNoCMOTBDyS2iF : $@convention(thin) (Int) -> Int {
// CHECK:         function_ref @$s9ModuleTBD12pkgFuncNoCMOyS2iF
// CHECK:       } // end sil function '$s4Main19callPkgFuncNoCMOTBDyS2iF'
// FIXME: should package_external be package?
// CHECK-LABEL: sil package_external @$s9ModuleTBD12pkgFuncNoCMOyS2iF : $@convention(thin) (Int) -> Int
package func callPkgFuncNoCMOTBD(_ x: Int) -> Int {
  return ModuleTBD.pkgFuncNoCMO(x)
}

// CHECK-LABEL: sil @$s4Main23getSubmoduleKlassMemberSiyF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main23getSubmoduleKlassMemberSiyF'
public func getSubmoduleKlassMember() -> Int {
  return Module.submoduleKlassMember()
}

// CHECK-LABEL: sil package @$s4Main26getPkgSubmoduleKlassMemberSiyF : $@convention(thin) () -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main26getPkgSubmoduleKlassMemberSiyF'
package func getPkgSubmoduleKlassMember() -> Int {
  return Module.pkgSubmoduleKlassMember()
}

// CHECK-LABEL: sil @$s4Main26getSubmoduleKlassMemberTBDSiyF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main26getSubmoduleKlassMemberTBDSiyF'
public func getSubmoduleKlassMemberTBD() -> Int {
  return ModuleTBD.submoduleKlassMember()
}

// CHECK-LABEL: sil package @$s4Main29getPkgSubmoduleKlassMemberTBDSiyF : $@convention(thin) () -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main29getPkgSubmoduleKlassMemberTBDSiyF'
package func getPkgSubmoduleKlassMemberTBD() -> Int {
  return ModuleTBD.pkgSubmoduleKlassMember()
}

// CHECK-LABEL: sil @$s4Main20getModuleKlassMemberSiyF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main20getModuleKlassMemberSiyF'
public func getModuleKlassMember() -> Int {
  return Module.moduleKlassMember()
}

// CHECK-LABEL: sil package @$s4Main23getPkgModuleKlassMemberSiyF : $@convention(thin) () -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main23getPkgModuleKlassMemberSiyF'
package func getPkgModuleKlassMember() -> Int {
  return Module.pkgModuleKlassMember()
}

// CHECK-LABEL: sil @$s4Main23getModuleKlassMemberTBDSiyF
// CHECK-NOT:     function_ref 
// CHECK-NOT:     apply 
// CHECK:       } // end sil function '$s4Main23getModuleKlassMemberTBDSiyF'
public func getModuleKlassMemberTBD() -> Int {
  return ModuleTBD.moduleKlassMember()
}

// CHECK-LABEL: sil package @$s4Main26getPkgModuleKlassMemberTBDSiyF : $@convention(thin) () -> Int {
// CHECK-NOT:     function_ref
// CHECK-NOT:     apply
// CHECK:       } // end sil function '$s4Main26getPkgModuleKlassMemberTBDSiyF'
package func getPkgModuleKlassMemberTBD() -> Int {
  return ModuleTBD.pkgModuleKlassMember()
}


// CHECK-LABEL: sil [_semantics "optimize.no.crossmodule"] @$s9Submodule19incrementByOneNoCMOyS2iF : $@convention(thin) (Int) -> Int

// CHECK-LABEL: sil package_external [_semantics "optimize.no.crossmodule"] @$s9Submodule15subPkgFuncNoCMOyS2iF : $@convention(thin) (Int) -> Int
