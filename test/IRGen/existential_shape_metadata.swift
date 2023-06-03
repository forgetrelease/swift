// RUN: %target-swift-frontend %use_no_opaque_pointers -emit-ir %s -swift-version 5 -disable-availability-checking | %IRGenFileCheck %s
// RUN: %target-swift-frontend -emit-ir %s -swift-version 5 -disable-availability-checking

// CHECK-LABEL: @"$sl26existential_shape_metadata2Q0_px1TRts_XPXGMq" = linkonce_odr hidden constant
// CHECK-SAME:  { i32 {{.*}}sub ([[INT]] ptrtoint (i8** @{{[0-9]+}} to [[INT]])
// CHECK-SAME:    i32 6400,
// CHECK-SAME:    i32 {{.*}} @"flat unique 26existential_shape_metadata2Q0_px1TAaBPRts_XP"
// CHECK-SAME:    i16 2, i16 2, i16 3, i16 0,
// CHECK-SAME:    i16 1, i16 0, i16 1, i16 0, i32 1,

// CHECK-LABEL: @"$sl26existential_shape_metadata2R033_881A0B6978EB4286E7CFF1E27030ACACLL_px1TRts_XPXG" = internal constant
// CHECK-SAME:  { i32 6400,
//   This could use a symbolic reference because this doesn't have to be uniqued.
// CHECK-SAME:    i32 {{.*}} @"flat unique 26existential_shape_metadata2R033_881A0B6978EB4286E7CFF1E27030ACACLL_px1TAabCLLPRts_XP"
// CHECK-SAME:    i16 2, i16 2, i16 3, i16 0,
// CHECK-SAME:    i16 1, i16 0, i16 1, i16 0, i32 1,

public protocol P0 {}
public protocol P1 {}

public protocol Q0<T> {
  associatedtype T
}
public protocol Q1<A> {
  associatedtype A
}
public protocol Q2<A, B>: Q1 {
  associatedtype A
  associatedtype B
}

private protocol R0<T> {
  associatedtype T
}

public struct B<T> {}
private struct C {}

// CHECK-LABEL: define{{.*}} @"$s26existential_shape_metadata12testConcrete
public func testConcrete() -> Any.Type {
  // CHECK: [[METADATA:%.*]] = call %swift.type* @__swift_instantiateConcreteTypeFromMangledName({ i32, i32 }* @"$s26existential_shape_metadata2Q0_pSi1TAaBPRts_XPMD")
  // CHECK: ret %swift.type* [[METADATA]]
  return (any Q0<Int>).self
}

//   Still the same shape with an application of a dependent type.
// CHECK-LABEL: define{{.*}} @"$s26existential_shape_metadata13testDependent
public func testDependent<T>(t: T.Type) -> Any.Type {
  // CHECK: [[ARGS:%.*]] = alloca [1 x i8*], align
  // CHECK: [[T0:%.*]] = getelementptr inbounds [1 x i8*], [1 x i8*]* [[ARGS]], i32 0, i32 0
  // CHECK: [[T1:%.*]] = bitcast %swift.type* %T to i8*
  // CHECK: store i8* [[T1]], i8** [[T0]], align
  // CHECK: [[T0:%.*]] = bitcast [1 x i8*]* [[ARGS]] to i8**
  // CHECK: [[METADATA:%.*]] = call %swift.type* @swift_getExtendedExistentialTypeMetadata({{.*}}@"$sl26existential_shape_metadata2Q0_px1TRts_XPXGMq{{(\.ptrauth)?}}" to i8*), i8** [[T0]])
  // CHECK: ret %swift.type* [[METADATA]]
  return (any Q0<T>).self
}

//   Still the same shape with an application of a complex type.
// CHECK-LABEL: define{{.*}} @"$s26existential_shape_metadata22testComplexApplication
public func testComplexApplication<T>(t: T.Type) -> Any.Type {
  // CHECK: [[ARGS:%.*]] = alloca [1 x i8*], align
  // CHECK: [[T0:%.*]] = call swiftcc %swift.metadata_response @"$s26existential_shape_metadata1BVMa"([[INT]] 255, %swift.type* %T)
  // CHECK: [[B_T:%.*]] = extractvalue %swift.metadata_response [[T0]], 0
  // CHECK: [[T0:%.*]] = getelementptr inbounds [1 x i8*], [1 x i8*]* [[ARGS]], i32 0, i32 0
  // CHECK: [[T1:%.*]] = bitcast %swift.type* [[B_T]] to i8*
  // CHECK: store i8* [[T1]], i8** [[T0]], align
  // CHECK: [[T0:%.*]] = bitcast [1 x i8*]* [[ARGS]] to i8**
  // CHECK: [[METADATA:%.*]] = call %swift.type* @swift_getExtendedExistentialTypeMetadata({{.*}}@"$sl26existential_shape_metadata2Q0_px1TRts_XPXGMq{{(\.ptrauth)?}}" to i8*), i8** [[T0]])
  // CHECK: ret %swift.type* [[METADATA]]
  return (any Q0<B<T>>).self
}

//   Private protocols make the shape private and unique.
// CHECK-LABEL: define{{.*}} @"$s26existential_shape_metadata12test_private
public func test_private<T>(t: T.Type) -> Any.Type {
  // CHECK: [[ARGS:%.*]] = alloca [1 x i8*], align
  // CHECK: [[T0:%.*]] = getelementptr inbounds [1 x i8*], [1 x i8*]* [[ARGS]], i32 0, i32 0
  // CHECK: [[T1:%.*]] = bitcast %swift.type* %T to i8*
  // CHECK: store i8* [[T1]], i8** [[T0]], align
  // CHECK: [[T0:%.*]] = bitcast [1 x i8*]* [[ARGS]] to i8**
  //   FIXME: this should be unique?
  // CHECK: [[METADATA:%.*]] = call %swift.type* @swift_getExtendedExistentialTypeMetadata_unique({{.*}}@"$sl26existential_shape_metadata2R033_881A0B6978EB4286E7CFF1E27030ACACLL_px1TRts_XPXG{{(\.ptrauth)?}}" to i8*), i8** [[T0]])
  // CHECK: ret %swift.type* [[METADATA]]
  return (any R0<T>).self
}

//   Applying private arguments to a public protocol does not
//   change anything: the shape is still public.
// CHECK-LABEL: define{{.*}} @"$s26existential_shape_metadata23test_privateApplication
public func test_privateApplication<T>(t: T.Type) -> Any.Type {
  // CHECK: [[METADATA:%.*]] = call %swift.type* @__swift_instantiateConcreteTypeFromMangledName({ i32, i32 }* @"$s26existential_shape_metadata2Q0_pAA1C33_881A0B6978EB4286E7CFF1E27030ACACLLV1TAaBPRts_XPMD")
  // CHECK: ret %swift.type* [[METADATA]]
  return (any Q0<C>).self
}
