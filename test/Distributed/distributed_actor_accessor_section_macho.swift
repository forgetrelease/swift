// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend-emit-module -emit-module-path %t/FakeDistributedActorSystems.swiftmodule -module-name FakeDistributedActorSystems -disable-availability-checking %S/Inputs/FakeDistributedActorSystems.swift
// RUN: %target-swift-frontend -emit-irgen -module-name distributed_actor_accessors -enable-experimental-distributed -disable-availability-checking -I %t 2>&1 %s | %IRGenFileCheck %s --dump-input=always

// UNSUPPORTED: back_deploy_concurrency
// REQUIRES: concurrency
// REQUIRES: distributed

// REQUIRES: VENDOR=apple

import _Distributed
import FakeDistributedActorSystems

@available(SwiftStdlib 5.5, *)
typealias DefaultDistributedActorSystem = FakeActorSystem

enum SimpleE : Codable {
case a
}

enum E : Codable {
case a, b, c
}

enum IndirectE : Codable {
  case empty
  indirect case test(_: Int)
}

final class Obj : Codable, Sendable {
  let x: Int

  init(x: Int) {
    self.x = x
  }
}

struct LargeStruct : Codable {
  var a: Int
  var b: Int
  var c: String
  var d: Double
}

@available(SwiftStdlib 5.7, *)
public distributed actor MyActor {
  distributed func simple1(_: Int) {
  }

  // `String` would be a direct result as a struct type
  distributed func simple2(_: Int) -> String {
    return ""
  }

  // `String` is an object that gets exploded into two parameters
  distributed func simple3(_: String) -> Int {
    return 42
  }

  // Enum with a single case are special because they have an empty
  // native schema so they are dropped from parameters/result.
  distributed func single_case_enum(_ e: SimpleE) -> SimpleE {
    return e
  }

  distributed func with_indirect_enums(_: IndirectE, _: Int) -> IndirectE {
    return .empty
  }

  // Combination of multiple arguments, reference type and indirect result
  //
  // Note: Tuple types cannot be used here is either position because they
  // cannot conform to protocols.
  distributed func complex(_: [Int], _: Obj, _: String?, _: LargeStruct) -> LargeStruct {
    fatalError()
  }
}

@available(SwiftStdlib 5.7, *)
public distributed actor MyOtherActor {
  distributed func empty() {
  }
}


/// ---> Let's check that distributed accessors and thunks are emitted as accessible functions

/// -> `MyActor.simple1`
             ///  s27distributed_actor_accessors7MyActorC7simple1yySiYaKFTE
// CHECK:      @"$s27distributed_actor_accessors7MyActorC7simple1yySiYaKFTE" = private constant
// CHECK-SAME: @"symbolic Si___________pIetMHygzo_ 27distributed_actor_accessors7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC7simple1yySiFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyActor.simple2`
// CHECK:      @"$s27distributed_actor_accessors7MyActorC7simple2ySSSiYaKFTE" = private constant
// CHECK-SAME: @"symbolic Si_____SS______pIetMHygozo_ 27distributed_actor_accessors7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC7simple2ySSSiFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyActor.simple3`
// CHECK:      @"$s27distributed_actor_accessors7MyActorC7simple3ySiSSYaKFTE" = private constant
// CHECK-SAME: @"symbolic SS_____Si______pIetMHggdzo_ 27distributed_actor_accessors7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC7simple3ySiSSFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyActor.single_case_enum`
// CHECK:      @"$s27distributed_actor_accessors7MyActorC16single_case_enumyAA7SimpleEOAFYaKFTE" = private constant
// CHECK-SAME: @"symbolic __________AA______pIetMHygdzo_ 27distributed_actor_accessors7SimpleEO AA7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC16single_case_enumyAA7SimpleEOAFFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyActor.with_indirect_enums`
// CHECK:      @"$s27distributed_actor_accessors7MyActorC19with_indirect_enumsyAA9IndirectEOAF_SitYaKFTE" = private constant
// CHECK-SAME: @"symbolic _____Si_____AA______pIetMHgygozo_ 27distributed_actor_accessors9IndirectEO AA7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC19with_indirect_enumsyAA9IndirectEOAF_SitFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyActor.complex`
// CHECK:      @"$s27distributed_actor_accessors7MyActorC7complexyAA11LargeStructVSaySiG_AA3ObjCSSSgAFtYaKFTE" = private constant
// CHECK-SAME: @"symbolic SaySiG_____SSSg__________AD______pIetMHgggngrzo_ 27distributed_actor_accessors3ObjC AA11LargeStructV AA7MyActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors7MyActorC7complexyAA11LargeStructVSaySiG_AA3ObjCSSSgAFtFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

/// -> `MyOtherActor.empty`
// CHECK:      @"$s27distributed_actor_accessors12MyOtherActorC5emptyyyYaKFTE" = private constant
// CHECK-SAME: @"symbolic ___________pIetMHgzo_ 27distributed_actor_accessors12MyOtherActorC s5ErrorP"
// CHECK-SAME: (%swift.async_func_pointer* @"$s27distributed_actor_accessors12MyOtherActorC5emptyyyFTETFTu" to i{{32|64}})
// CHECK-SAME: , section {{"swift5_accessible_functions"|".sw5acfn$B"|"__TEXT, __swift5_acfuncs, regular"}}

// CHECK:      @llvm.used = appending global [{{.*}} x i8*] [
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC7simple1yySiYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC7simple2ySSSiYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC7simple3ySiSSYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC16single_case_enumyAA7SimpleEOAFYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC19with_indirect_enumsyAA9IndirectEOAF_SitYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors7MyActorC7complexyAA11LargeStructVSaySiG_AA3ObjCSSSgAFtYaKFTE"
// CHECK-SAME: @"$s27distributed_actor_accessors12MyOtherActorC5emptyyyYaKFTE"
// CHECK-SAME: ], section "llvm.metadata"
