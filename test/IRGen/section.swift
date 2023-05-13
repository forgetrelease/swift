// RUN: %target-swift-frontend -primary-file %s -emit-sil | %FileCheck %s --check-prefix=SIL --check-prefix=SIL-TOPLEVEL
// RUN: %target-swift-frontend -primary-file %s -emit-ir  | %FileCheck %s --check-prefix=IR --check-prefix=IR-TOPLEVEL
// RUN: %target-swift-frontend -primary-file %s -emit-sil -parse-as-library | %FileCheck %s --check-prefix=SIL --check-prefix=SIL-LIBRARY
// RUN: %target-swift-frontend -primary-file %s -emit-ir  -parse-as-library | %FileCheck %s --check-prefix=IR --check-prefix=IR-LIBRARY

// RUN: %target-swift-frontend -primary-file %s -S                   | %FileCheck %s --check-prefix=ASM --check-prefix ASM-%target-os
// RUN: %target-swift-frontend -primary-file %s -S -parse-as-library | %FileCheck %s --check-prefix=ASM --check-prefix ASM-%target-os

// REQUIRES: swift_in_compiler

@_section("__TEXT,__mysection") var g0: Int = 1
@_section("__TEXT,__mysection") var g1: (Int, Int) = (42, 43)
@_section("__TEXT,__mysection") var g2: Bool = true
@_section("__TEXT,__mysection") public var g3: Bool = true
@_section("__TEXT,__mysection") func foo() {}

// SIL:         @_section("__TEXT,__mysection") @_hasStorage @_hasInitialValue var g0: Int { get set }
// SIL:         @_section("__TEXT,__mysection") @_hasStorage @_hasInitialValue var g1: (Int, Int) { get set }
// SIL:         @_section("__TEXT,__mysection") @_hasStorage @_hasInitialValue var g2: Bool { get set }
// SIL:         @_section("__TEXT,__mysection") func foo()
// SIL-LIBRARY: sil private [global_init_once_fn] @$s7section2g0_WZ : $@convention(c)
// SIL-LIBRARY: sil hidden [global_init] @$s7section2g0Sivau : $@convention(thin)
// SIL-LIBRARY: sil private [global_init_once_fn] @$s7section2g1_WZ : $@convention(c)
// SIL-LIBRARY: sil hidden [global_init] @$s7section2g1Si_Sitvau : $@convention(thin)
// SIL-LIBRARY: sil private [global_init_once_fn] @$s7section2g2_WZ : $@convention(c)
// SIL-LIBRARY: sil hidden [global_init] @$s7section2g2Sbvau : $@convention(thin)
// SIL-LIBRARY: sil private [global_init_once_fn] @$s7section2g3_WZ : $@convention(c)
// SIL-LIBRARY: sil [global_init] @$s7section2g3Sbvau : $@convention(thin)
// SIL:         sil hidden [section "__TEXT,__mysection"] @$s7section3fooyyF : $@convention(thin)

// IR-LIBRARY:  @"$s7section2g0_Wz" = internal global i64 0

// IR-LIBRARY:  @"$s7section2g0Sivp" = hidden global %TSi <{ i64 1 }>, section "__TEXT,__mysection"
// IR-TOPLEVEL: @"$s7section2g0Sivp" = hidden global %TSi zeroinitializer, section "__TEXT,__mysection"

// IR-LIBRARY:  @"$s7section2g1_Wz" = internal global i64 0

// IR-LIBRARY:  @"$s7section2g1Si_Sitvp" = hidden global <{ %TSi, %TSi }> <{ %TSi <{ i64 42 }>, %TSi <{ i64 43 }> }>, section "__TEXT,__mysection"
// IR-TOPLEVEL: @"$s7section2g1Si_Sitvp" = hidden global <{ %TSi, %TSi }> zeroinitializer, section "__TEXT,__mysection"

// IR-LIBRARY:  @"$s7section2g2_Wz" = internal global i64 0

// IR-LIBRARY:  @"$s7section2g2Sbvp" = hidden global %TSb <{ i1 true }>, section "__TEXT,__mysection"
// IR-TOPLEVEL: @"$s7section2g2Sbvp" = hidden global %TSb zeroinitializer, section "__TEXT,__mysection"

// IR-LIBRARY:  @"$s7section2g3_Wz" = internal global i64 0

// IR-LIBRARY:  @"$s7section2g3Sbvp" = {{.*}}global %TSb <{ i1 true }>, section "__TEXT,__mysection"
// IR-TOPLEVEL: @"$s7section2g3Sbvp" = {{.*}}global %TSb zeroinitializer, section "__TEXT,__mysection"

// IR:          define {{.*}}@"$s7section3fooyyF"(){{.*}} section "__TEXT,__mysection"

// ASM: .section{{.*}}__TEXT,__mysection
// ASM-NOT: .section
// ASM: $s7section3fooyyF:
// ASM-linux-gnu: .section{{.*}}__TEXT,__mysection
// ASM-NOT: .section
// ASM: $s7section2g0Sivp:
// ASM-NOT: .section
// ASM: $s7section2g1Si_Sitvp:
// ASM-NOT: .section
// ASM: $s7section2g2Sbvp:
// ASM-NOT: .section
// ASM: $s7section2g3Sbvp:
