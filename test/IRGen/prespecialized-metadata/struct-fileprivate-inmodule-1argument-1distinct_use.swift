// RUN: %swift  -target %module-target-future -emit-ir %s | %FileCheck %s -DINT=i%target-ptrsize -DALIGNMENT=%target-alignment

// REQUIRES: OS=macosx || OS=ios || OS=tvos || OS=watchos || OS=linux-gnu
// UNSUPPORTED: CPU=i386 && OS=ios
// UNSUPPORTED: CPU=armv7 && OS=ios
// UNSUPPORTED: CPU=armv7s && OS=ios

// CHECK: @"$s4main5Value[[UNIQUE_ID_1:[0-9A-Z_]+]]VySiGMf" = linkonce_odr hidden constant <{
// CHECK-SAME:    i8**,
// CHECK-SAME:    [[INT]],
// CHECK-SAME:    %swift.type_descriptor*,
// CHECK-SAME:    %swift.type*,
// CHECK-SAME:    i32{{(, \[4 x i8\])?}},
// CHECK-SAME:    i64
// CHECK-SAME: }> <{
//                i8** @"$sB[[INT]]_WV",
//                i8** getelementptr inbounds (%swift.vwtable, %swift.vwtable* @"$s4main5Value33_BD97D79156BC586FAA2AE8FB32F3D812LLVySiGWV", i32 0, i32 0),
// CHECK-SAME:    [[INT]] 512,
// CHECK-SAME:    %swift.type_descriptor* bitcast ({{.+}}$s4main5Value[[UNIQUE_ID_1:[0-9A-Z_]+]]VMn{{.+}} to %swift.type_descriptor*),
// CHECK-SAME:    %swift.type* @"$sSiN",
// CHECK-SAME:    i32 0{{(, \[4 x i8\] zeroinitializer)?}},
// CHECK-SAME:    i64 3
// CHECK-SAME: }>, align [[ALIGNMENT]]

fileprivate struct Value<First> {
  let first: First
}

@inline(never)
func consume<T>(_ t: T) {
  withExtendedLifetime(t) { t in
  }
}

// CHECK: define hidden swiftcc void @"$s4main4doityyF"() #{{[0-9]+}} {
// CHECK:   call swiftcc void @"$s4main7consumeyyxlF"(%swift.opaque* noalias nocapture %{{[0-9]+}}, %swift.type* getelementptr inbounds (%swift.full_type, %swift.full_type* bitcast (<{ i8**, [[INT]], %swift.type_descriptor*, %swift.type*, i32{{(, \[4 x i8\])?}}, i64 }>* @"$s4main5Value[[UNIQUE_ID_1]]VySiGMf" to %swift.full_type*), i32 0, i32 1))
// CHECK: }
func doit() {
  consume( Value(first: 13) )
}
doit()

// CHECK: ; Function Attrs: noinline nounwind readnone
// CHECK: define internal swiftcc %swift.metadata_response @"$s4main5Value[[UNIQUE_ID_1]]VMa"([[INT]] %0, %swift.type* %1) #{{[0-9]+}} {
// CHECK: entry:
// CHECK:   [[ERASED_TYPE:%[0-9]+]] = bitcast %swift.type* %1 to i8*
// CHECK:   br label %[[TYPE_COMPARISON_LABEL:[0-9]+]]
// CHECK: [[TYPE_COMPARISON_LABEL]]:
// CHECK:   [[EQUAL_TYPE:%[0-9]+]] = icmp eq i8* bitcast (%swift.type* @"$sSiN" to i8*), [[ERASED_TYPE]]
// CHECK:   [[EQUAL_TYPES:%[0-9]+]] = and i1 true, [[EQUAL_TYPE]]
// CHECK:   br i1 [[EQUAL_TYPES]], label %[[EXIT_PRESPECIALIZED:[0-9]+]], label %[[EXIT_NORMAL:[0-9]+]]
// CHECK: [[EXIT_PRESPECIALIZED]]:
// CHECK:   ret %swift.metadata_response { %swift.type* getelementptr inbounds (%swift.full_type, %swift.full_type* bitcast (<{ i8**, [[INT]], %swift.type_descriptor*, %swift.type*, i32{{(, \[4 x i8\])?}}, i64 }>* @"$s4main5Value[[UNIQUE_ID_1]]VySiGMf" to %swift.full_type*), i32 0, i32 1), [[INT]] 0 }
// CHECK: [[EXIT_NORMAL]]:
// CHECK:   {{%[0-9]+}} = call swiftcc %swift.metadata_response @__swift_instantiateGenericMetadata([[INT]] %0, i8* [[ERASED_TYPE]], i8* undef, i8* undef, %swift.type_descriptor* bitcast ({{.+}}$s4main5Value[[UNIQUE_ID_1]]VMn{{.+}} to %swift.type_descriptor*)) #{{[0-9]+}}
// CHECK:   ret %swift.metadata_response {{%[0-9]+}}
// CHECK: }
