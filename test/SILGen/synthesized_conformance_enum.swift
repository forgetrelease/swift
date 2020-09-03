// RUN: %target-swift-frontend -emit-silgen %s -swift-version 4 | %FileCheck -check-prefix CHECK -check-prefix CHECK-FRAGILE %s
// RUN: %target-swift-frontend -emit-silgen %s -swift-version 4 -enable-library-evolution | %FileCheck -check-prefix CHECK -check-prefix CHECK-RESILIENT %s

enum Enum<T> {
    case a(T), b(T)
}
// CHECK-LABEL: enum Enum<T> {
// CHECK:   case a(T), b(T)
// CHECK: }

enum NoValues {
    case a, b
}
// CHECK-LABEL: enum NoValues {
// CHECK:   case a, b
// CHECK:   var hashValue: Int { get }
// CHECK-FRAGILE:   @_implements(Equatable, ==(_:_:)) static func __derived_enum_equals(_ a: NoValues, _ b: NoValues) -> Bool
// CHECK:   func hash(into hasher: inout Hasher)
// CHECK-RESILIENT: static func == (a: NoValues, b: NoValues) -> Bool
// CHECK: }

// CHECK-LABEL: extension Enum : Equatable where T : Equatable {
// CHECK-FRAGILE:   @_implements(Equatable, ==(_:_:)) static func __derived_enum_equals(_ a: Enum<T>, _ b: Enum<T>) -> Bool
// CHECK-RESILIENT: static func == (a: Enum<T>, b: Enum<T>) -> Bool
// CHECK: }
// CHECK-LABEL: extension Enum : Hashable where T : Hashable {
// CHECK:   var hashValue: Int { get }
// CHECK:   func hash(into hasher: inout Hasher)
// CHECK: }

// CHECK-LABEL: extension NoValues : CaseIterable {
// CHECK:   typealias AllCases = [NoValues]
// CHECK:   static var allCases: [NoValues] { get }
// CHECK: }


extension Enum: Equatable where T: Equatable {}
// CHECK-FRAGILE-LABEL: // static Enum<A>.__derived_enum_equals(_:_:)
// CHECK-FRAGILE-NEXT: sil hidden [ossa] @$s28synthesized_conformance_enum4EnumOAASQRzlE010__derived_C7_equalsySbACyxG_AEtFZ : $@convention(method) <T where T : Equatable> (@in_guaranteed Enum<T>, @in_guaranteed Enum<T>, @thin Enum<T>.Type) -> Bool {
// CHECK-RESILIENT-LABEL: // static Enum<A>.== infix(_:_:)
// CHECK-RESILIENT-NEXT: sil hidden [ossa] @$s28synthesized_conformance_enum4EnumOAASQRzlE2eeoiySbACyxG_AEtFZ : $@convention(method) <T where T : Equatable> (@in_guaranteed Enum<T>, @in_guaranteed Enum<T>, @thin Enum<T>.Type) -> Bool {

extension Enum: Hashable where T: Hashable {}
// CHECK-LABEL: // Enum<A>.hashValue.getter
// CHECK-NEXT: sil hidden [ossa] @$s28synthesized_conformance_enum4EnumOAASHRzlE9hashValueSivg : $@convention(method) <T where T : Hashable> (@in_guaranteed Enum<T>) -> Int {

// CHECK-LABEL: // Enum<A>.hash(into:)
// CHECK-NEXT: sil hidden [ossa] @$s28synthesized_conformance_enum4EnumOAASHRzlE4hash4intoys6HasherVz_tF : $@convention(method) <T where T : Hashable> (@inout Hasher, @in_guaranteed Enum<T>) -> () {

extension NoValues: CaseIterable {}
// CHECK-LABEL: // static NoValues.allCases.getter
// CHECK-NEXT: sil hidden [ossa] @$s28synthesized_conformance_enum8NoValuesO8allCasesSayACGvgZ : $@convention(method) (@thin NoValues.Type) -> @owned Array<NoValues> {


// Witness tables for Enum

// CHECK-LABEL: sil_witness_table hidden <T where T : Equatable> Enum<T>: Equatable module synthesized_conformance_enum {
// CHECK-NEXT:   method #Equatable."==": <Self where Self : Equatable> (Self.Type) -> (Self, Self) -> Bool : @$s28synthesized_conformance_enum4EnumOyxGSQAASQRzlSQ2eeoiySbx_xtFZTW	// protocol witness for static Equatable.== infix(_:_:) in conformance <A> Enum<A>
// CHECK-NEXT:   conditional_conformance (T: Equatable): dependent
// CHECK-NEXT: }

// CHECK-LABEL: sil_witness_table hidden <T where T : Hashable> Enum<T>: Hashable module synthesized_conformance_enum {
// CHECK-DAG:   base_protocol Equatable: <T where T : Equatable> Enum<T>: Equatable module synthesized_conformance_enum
// CHECK-DAG:   method #Hashable.hashValue!getter: <Self where Self : Hashable> (Self) -> () -> Int : @$s28synthesized_conformance_enum4EnumOyxGSHAASHRzlSH9hashValueSivgTW	// protocol witness for Hashable.hashValue.getter in conformance <A> Enum<A>
// CHECK-DAG:   method #Hashable.hash: <Self where Self : Hashable> (Self) -> (inout Hasher) -> () : @$s28synthesized_conformance_enum4EnumOyxGSHAASHRzlSH4hash4intoys6HasherVz_tFTW	// protocol witness for Hashable.hash(into:) in conformance <A> Enum<A>
// CHECK-DAG:   method #Hashable._rawHashValue: <Self where Self : Hashable> (Self) -> (Int) -> Int : @$s28synthesized_conformance_enum4EnumOyxGSHAASHRzlSH13_rawHashValue4seedS2i_tFTW // protocol witness for Hashable._rawHashValue(seed:) in conformance <A> Enum<A>
// CHECK-DAG:   conditional_conformance (T: Hashable): dependent
// CHECK: }

// Witness tables for NoValues

// CHECK-LABEL: sil_witness_table hidden NoValues: CaseIterable module synthesized_conformance_enum {
// CHECK-NEXT:   associated_type_protocol (AllCases: Collection): [NoValues]: specialize <NoValues> (<Element> Array<Element>: Collection module Swift)
// CHECK-NEXT:   associated_type AllCases: Array<NoValues>
// CHECK-NEXT:   method #CaseIterable.allCases!getter: <Self where Self : CaseIterable> (Self.Type) -> () -> Self.AllCases : @$s28synthesized_conformance_enum8NoValuesOs12CaseIterableAAsADP8allCases03AllI0QzvgZTW // protocol witness for static CaseIterable.allCases.getter in conformance NoValues
// CHECK-NEXT: }


