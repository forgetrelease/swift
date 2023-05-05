// RUN: %target-swift-emit-silgen -enable-experimental-feature NoImplicitCopy -module-name moveonly_closure %s | %FileCheck %s
// RUN: %target-swift-emit-sil -enable-experimental-feature NoImplicitCopy -module-name moveonly_closure -verify %s

@_moveOnly
struct Empty {}

@_moveOnly
struct SingleElt {
    var e = Empty()
}

func consumeVal(_ x: consuming SingleElt) {}
func borrowVal(_ x: borrowing SingleElt) {}
func borrowConsumeVal(_ x: borrowing SingleElt, _ y: consuming SingleElt) {}

/////////////////////////////
// MARK: Var Capture Tests //
/////////////////////////////

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure27testGlobalClosureCaptureVaryyF : $@convention(thin) () -> () {
// CHECK: [[GLOBAL:%.*]] = global_addr @$s16moveonly_closure23globalClosureCaptureVaryycvp
// CHECK: [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure27testGlobalClosureCaptureVaryyFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [dynamic] [[GLOBAL]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure27testGlobalClosureCaptureVaryyF'

// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure27testGlobalClosureCaptureVaryyFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] : @closureCapture
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure27testGlobalClosureCaptureVaryyFyycfU_'
var globalClosureCaptureVar: () -> () = {}
func testGlobalClosureCaptureVar() {
    var x = SingleElt()
    x = SingleElt()
    globalClosureCaptureVar = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1:29 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2:26 {{conflicting access is here}}
    }
    globalClosureCaptureVar()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure29testLocalLetClosureCaptureVaryyF : $@convention(thin) () -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: [[BORROW_PAI:%.*]] = begin_borrow [lexical] [[PAI]]
// CHECK: [[COPY_BORROW_PAI:%.*]] = copy_value [[BORROW_PAI]]
// CHECK: [[BORROW_COPY_BORROW_PAI:%.*]] = begin_borrow [[COPY_BORROW_PAI]]
// CHECK: apply [[BORROW_COPY_BORROW_PAI]]()
// CHECK: } // end sil function '$s16moveonly_closure29testLocalLetClosureCaptureVaryyF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure29testLocalLetClosureCaptureVaryyFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure29testLocalLetClosureCaptureVaryyFyycfU_'
func testLocalLetClosureCaptureVar() {
    var x = SingleElt() // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    // expected-error @-1 {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    // expected-error @-2 {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    x = SingleElt()
    let f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        borrowConsumeVal(x, x) // expected-note {{consuming use here}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure026testLocalVarClosureCaptureE0yyF : $@convention(thin) () -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: } // end sil function '$s16moveonly_closure026testLocalVarClosureCaptureE0yyF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure026testLocalVarClosureCaptureE0yyFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure026testLocalVarClosureCaptureE0yyFyycfU_'
func testLocalVarClosureCaptureVar() {
    var x = SingleElt()
    x = SingleElt()
    var f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f = {}
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure026testInOutVarClosureCaptureF0yyyyczF : $@convention(thin) (@inout @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[F:%.*]] : $*@callee_guaranteed () -> ()):
// CHECK: [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure026testInOutVarClosureCaptureF0yyyyczFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] [[F]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure026testInOutVarClosureCaptureF0yyyyczF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure026testInOutVarClosureCaptureF0yyyyczFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure026testInOutVarClosureCaptureF0yyyyczFyycfU_'
func testInOutVarClosureCaptureVar(_ f: inout () -> ()) {
    var x = SingleElt()
    x = SingleElt()
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureVaryyyyXEnF : $@convention(thin) (@owned @noescape @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @noescape @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureVaryyyyXEnFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[PROJECT]])
// CHECK:   [[NO_ESCAPE:%.*]] = convert_escape_to_noescape [not_guaranteed] [[PAI]]
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[NO_ESCAPE]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingNoEscapeClosureCaptureVaryyyyXEnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureVaryyyyXEnFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[CHECK:%.*]] = mark_must_check [consumable_and_assignable] [[ARG]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[CHECK]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[DEINIT_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingNoEscapeClosureCaptureVaryyyyXEnFyyXEfU_'
func testConsumingNoEscapeClosureCaptureVar(_ f: consuming () -> ()) {
    var x = SingleElt()
    // expected-error @-1 {{'x' used after consume}}
    // expected-error @-2 {{'x' used after consume}}
    // expected-error @-3 {{'x' consumed more than once}}
    x = SingleElt()
    f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
        borrowConsumeVal(x, x)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        // expected-note @-3 {{non-consuming use here}}
        // expected-error @-4 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-5 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure36testConsumingEscapeClosureCaptureVaryyyycnF : $@convention(thin) (@owned @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure36testConsumingEscapeClosureCaptureVaryyyycnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt })
// CHECK:   [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK:   mark_function_escape [[PROJECT]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[PAI]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure36testConsumingEscapeClosureCaptureVaryyyycnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure36testConsumingEscapeClosureCaptureVaryyyycnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure36testConsumingEscapeClosureCaptureVaryyyycnFyycfU_'
func testConsumingEscapeClosureCaptureVar(_ f: consuming @escaping () -> ()) {
    var x = SingleElt()
    x = SingleElt()
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f()
}

/////////////////////////////
// MARK: Let Capture Tests //
/////////////////////////////

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure27testGlobalClosureCaptureLetyyF : $@convention(thin) () -> () {
// CHECK: [[GLOBAL:%.*]] = global_addr @$s16moveonly_closure23globalClosureCaptureLetyycvp
// CHECK: [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure27testGlobalClosureCaptureLetyyFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [dynamic] [[GLOBAL]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure27testGlobalClosureCaptureLetyyF'

// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure27testGlobalClosureCaptureLetyyFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] : @closureCapture
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure27testGlobalClosureCaptureLetyyFyycfU_'
var globalClosureCaptureLet: () -> () = {}
func testGlobalClosureCaptureLet() {
    let x = SingleElt()
    globalClosureCaptureLet = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    globalClosureCaptureLet()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure026testLocalLetClosureCaptureE0yyF : $@convention(thin) () -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: [[BORROW_PAI:%.*]] = begin_borrow [lexical] [[PAI]]
// CHECK: [[COPY_BORROW_PAI:%.*]] = copy_value [[BORROW_PAI]]
// CHECK: [[BORROW_COPY_BORROW_PAI:%.*]] = begin_borrow [[COPY_BORROW_PAI]]
// CHECK: apply [[BORROW_COPY_BORROW_PAI]]()
// CHECK: } // end sil function '$s16moveonly_closure026testLocalLetClosureCaptureE0yyF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure026testLocalLetClosureCaptureE0yyFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure026testLocalLetClosureCaptureE0yyFyycfU_'
func testLocalLetClosureCaptureLet() {
    let x = SingleElt()
    // expected-error @-1 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    // expected-error @-2 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    // expected-error @-3 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    let f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        borrowConsumeVal(x, x) // expected-note {{consuming use here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure29testLocalVarClosureCaptureLetyyF : $@convention(thin) () -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: } // end sil function '$s16moveonly_closure29testLocalVarClosureCaptureLetyyF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure29testLocalVarClosureCaptureLetyyFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure29testLocalVarClosureCaptureLetyyFyycfU_'
func testLocalVarClosureCaptureLet() {
    let x = SingleElt()
    var f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f = {}
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure29testInOutVarClosureCaptureLetyyyyczF : $@convention(thin) (@inout @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[F:%.*]] : $*@callee_guaranteed () -> ()):
// CHECK: [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure29testInOutVarClosureCaptureLetyyyyczFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] [[F]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure29testInOutVarClosureCaptureLetyyyyczF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure29testInOutVarClosureCaptureLetyyyyczFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure29testInOutVarClosureCaptureLetyyyyczFyycfU_'
func testInOutVarClosureCaptureLet(_ f: inout () -> ()) {
    let x = SingleElt()
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureLetyyyyXEnF : $@convention(thin) (@owned @noescape @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @noescape @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureLetyyyyXEnFyyXEfU_ : $@convention(thin) (@guaranteed SingleElt) -> ()
// CHECK:   [[MARKED:%.*]] = mark_must_check [assignable_but_not_consumable] [[PROJECT]]
// CHECK:   [[LOADED_VALUE:%.*]] = load [copy] [[MARKED]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[LOADED_VALUE]])
// CHECK:   [[NO_ESCAPE:%.*]] = convert_escape_to_noescape [not_guaranteed] [[PAI]]
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[NO_ESCAPE]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingNoEscapeClosureCaptureLetyyyyXEnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure38testConsumingNoEscapeClosureCaptureLetyyyyXEnFyyXEfU_ : $@convention(thin) (@guaranteed SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ARG_COPY]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingNoEscapeClosureCaptureLetyyyyXEnFyyXEfU_'
func testConsumingNoEscapeClosureCaptureLet(_ f: consuming () -> ()) {
    let x = SingleElt() // expected-error {{'x' consumed and used at the same time}}
    f = {
        borrowVal(x)
        consumeVal(x)
        consumeVal(x)
        borrowConsumeVal(x, x) // expected-note {{consuming and non-consuming uses here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure36testConsumingEscapeClosureCaptureLetyyyycnF : $@convention(thin) (@owned @callee_guaranteed () -> ()) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure36testConsumingEscapeClosureCaptureLetyyyycnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt })
// CHECK:   [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK:   mark_function_escape [[PROJECT]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[PAI]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure36testConsumingEscapeClosureCaptureLetyyyycnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure36testConsumingEscapeClosureCaptureLetyyyycnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure36testConsumingEscapeClosureCaptureLetyyyycnFyycfU_'
func testConsumingEscapeClosureCaptureLet(_ f: consuming @escaping () -> ()) {
    let x = SingleElt()
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f()
}

///////////////////////
// MARK: InOut Tests //
///////////////////////

// NOTE: In the inout cases below, we often times emit the inout capture as if
// the inout cannot escape (even if the way the code is emitted it could) since
// we are going to emit an error saying that inout can not be captured by
// escaping closures. The diagnostic emission is validated with -verify to
// validate our presupposition.
//
// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure29testGlobalClosureCaptureInOutyyAA9SingleEltVzF : $@convention(thin) (@inout SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK: [[GLOBAL:%.*]] = global_addr @$s16moveonly_closure25globalClosureCaptureInOutyycvp :
// CHECK: [[MARKED:%.*]] = mark_must_check [consumable_and_assignable] [[ARG]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure29testGlobalClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[MARKED]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [dynamic] [[GLOBAL]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure29testGlobalClosureCaptureInOutyyAA9SingleEltVzF'

// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure29testGlobalClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure29testGlobalClosureCaptureInOutyyAA9SingleEltVzFyycfU_'
var globalClosureCaptureInOut: () -> () = {}
func testGlobalClosureCaptureInOut(_ x: inout SingleElt) {
    // expected-error @-1 {{'x' consumed but not reinitialized before end of function}}
    // expected-note @-2 {{'x' is declared 'inout'}}
    globalClosureCaptureInOut = { // expected-error {{escaping closure captures 'inout' parameter 'x'}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        borrowConsumeVal(x, x) // expected-note {{captured here}}
        // expected-note @-1 {{captured here}}
        // expected-error @-2 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-3 {{conflicting access is here}}
    }
    globalClosureCaptureInOut()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure31testLocalLetClosureCaptureInOutyyAA9SingleEltVzF : $@convention(thin) (@inout SingleElt) -> () {
// CHECK: [[MARKED:%.*]] = mark_must_check [consumable_and_assignable] [[ARG]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure31testLocalLetClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[MARKED]])
// CHECK: } // end sil function '$s16moveonly_closure31testLocalLetClosureCaptureInOutyyAA9SingleEltVzF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure31testLocalLetClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure31testLocalLetClosureCaptureInOutyyAA9SingleEltVzFyycfU_'
func testLocalLetClosureCaptureInOut(_ x: inout SingleElt) {
    // expected-note @-1 {{'x' is declared 'inout'}}
    // expected-error @-2 {{'x' consumed but not reinitialized before end of function}}
    let f = { // expected-error {{escaping closure captures 'inout' parameter 'x'}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        borrowConsumeVal(x, x) // expected-note {{captured here}}
        // expected-note @-1 {{captured here}}
        // expected-error @-2 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-3 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure31testLocalVarClosureCaptureInOutyyAA9SingleEltVzF : $@convention(thin) (@inout SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK: [[MARKED:%.*]] = mark_must_check [consumable_and_assignable] [[ARG]]
// CHECK: [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK: [[FUNC_BOX_BORROW:%.*]] = begin_borrow [lexical] [[FUNC_BOX]]
// CHECK: [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX_BORROW]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure31testLocalVarClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[MARKED]])
// CHECK: store [[PAI]] to [init] [[FUNC_PROJECT]]
// CHECK: } // end sil function '$s16moveonly_closure31testLocalVarClosureCaptureInOutyyAA9SingleEltVzF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure31testLocalVarClosureCaptureInOutyyAA9SingleEltVzFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure31testLocalVarClosureCaptureInOutyyAA9SingleEltVzFyycfU_'
func testLocalVarClosureCaptureInOut(_ x: inout SingleElt) {
    // expected-error @-1 {{'x' consumed but not reinitialized before end of function}}
    // expected-note @-2 {{'x' is declared 'inout'}}
    var f = { // expected-note {{consuming use here}}
        // expected-error @-1 {{escaping closure captures 'inout' parameter 'x'}}
        borrowVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        borrowConsumeVal(x, x)
        // expected-note @-1 {{captured here}}
        // expected-note @-2 {{captured here}}
        // expected-error @-3 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-4 {{conflicting access is here}}
    }
    f = {}
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure026testInOutVarClosureCapturedE0yyyycz_AA9SingleEltVztF : $@convention(thin) (@inout @callee_guaranteed () -> (), @inout SingleElt) -> () {
// CHECK: bb0([[F:%.*]] : $*@callee_guaranteed () -> (), [[PROJECT:%.*]] : $*SingleElt):
// CHECK: [[MARK:%.*]] = mark_must_check [consumable_and_assignable] [[PROJECT]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure026testInOutVarClosureCapturedE0yyyycz_AA9SingleEltVztFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[MARK]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] [[F]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure026testInOutVarClosureCapturedE0yyyycz_AA9SingleEltVztF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure026testInOutVarClosureCapturedE0yyyycz_AA9SingleEltVztFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure026testInOutVarClosureCapturedE0yyyycz_AA9SingleEltVztFyycfU_'
func testInOutVarClosureCaptureInOut(_ f: inout () -> (), _ x: inout SingleElt) {
    // expected-error @-1 {{'x' consumed but not reinitialized before end of function}}
    // expected-note @-2 {{'x' is declared 'inout'}}
    f = { // expected-error {{escaping closure captures 'inout' parameter 'x'}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        borrowConsumeVal(x, x)
        // expected-note @-1 {{captured here}}
        // expected-note @-2 {{captured here}}
        // expected-error @-3 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-4 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureInOutyyyyXEn_AA9SingleEltVztF : $@convention(thin) (@owned @noescape @callee_guaranteed () -> (), @inout SingleElt) -> () {
// CHECK: bb0([[OWNED_F:%.*]] : @_eagerMove @owned $@noescape @callee_guaranteed () -> (), [[PROJECT:%.*]] : $*SingleElt):
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @noescape @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[OWNED_F]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[MARKED_PROJECT:%.*]] = mark_must_check [consumable_and_assignable] [[PROJECT]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureInOutyyyyXEn_AA9SingleEltVztFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[MARKED_PROJECT]])
// CHECK:   [[NO_ESCAPE:%.*]] = convert_escape_to_noescape [not_guaranteed] [[PAI]]
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[NO_ESCAPE]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure40testConsumingNoEscapeClosureCaptureInOutyyyyXEn_AA9SingleEltVztF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureInOutyyyyXEn_AA9SingleEltVztFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
// CHECK:   [[MARKED:%.*]] = mark_must_check [consumable_and_assignable] [[PROJECT]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[MARKED]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[MARKED]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[MARKED]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[MARKED]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[MARKED]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure40testConsumingNoEscapeClosureCaptureInOutyyyyXEn_AA9SingleEltVztFyyXEfU_'
func testConsumingNoEscapeClosureCaptureInOut(_ f: consuming () -> (), _ x: inout SingleElt) {
    // expected-error @-1 {{'x' consumed but not reinitialized before end of function}}
    // expected-error @-2 {{'x' used after consume}}
    // expected-error @-3 {{'x' consumed more than once}}
    // expected-error @-4 {{'x' used after consume}}
    f = { // expected-note {{consuming use here}}
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
        borrowConsumeVal(x, x)
        // expected-error @-1 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
        // expected-note @-3 {{non-consuming use here}}
        // expected-note @-4 {{non-consuming use here}}
        // expected-note @-5 {{consuming use here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure38testConsumingEscapeClosureCaptureInOutyyyycn_AA9SingleEltVztF : $@convention(thin) (@owned @callee_guaranteed () -> (), @inout SingleElt) -> () {
// CHECK: bb0([[FUNC_ARG:%.*]] : @_eagerMove @owned $@callee_guaranteed () -> (), [[PROJECT:%.*]] : $*SingleElt):
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[FUNC_ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [consumable_and_assignable] [[PROJECT]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure38testConsumingEscapeClosureCaptureInOutyyyycn_AA9SingleEltVztFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[CHECK]])
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[PAI]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingEscapeClosureCaptureInOutyyyycn_AA9SingleEltVztF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure38testConsumingEscapeClosureCaptureInOutyyyycn_AA9SingleEltVztFyycfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[PROJECT:%.*]] : @closureCapture
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[TAKE_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[TAKE_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingEscapeClosureCaptureInOutyyyycn_AA9SingleEltVztFyycfU_'
func testConsumingEscapeClosureCaptureInOut(_ f: consuming @escaping () -> (), _ x: inout SingleElt) {
    // expected-note @-1 {{'x' is declared 'inout'}}
    // expected-error @-2 {{'x' consumed but not reinitialized before end of function}}
    f = { // expected-error {{escaping closure captures 'inout' parameter 'x'}}
        // expected-note @-1 {{consuming use here}}
        borrowVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        consumeVal(x) // expected-note {{captured here}}
        borrowConsumeVal(x, x)
        // expected-note @-1 {{captured here}}
        // expected-note @-2 {{captured here}}
        // expected-error @-3 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-4 {{conflicting access is here}}
    }
    f()
}

///////////////////////////
// MARK: Consuming Tests //
///////////////////////////

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure33testGlobalClosureCaptureConsumingyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[GLOBAL:%.*]] = global_addr @$s16moveonly_closure29globalClosureCaptureConsumingyycvp
// CHECK: [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure33testGlobalClosureCaptureConsumingyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [dynamic] [[GLOBAL]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure33testGlobalClosureCaptureConsumingyyAA9SingleEltVnF'

// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure33testGlobalClosureCaptureConsumingyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] : @closureCapture
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure33testGlobalClosureCaptureConsumingyyAA9SingleEltVnFyycfU_'
var globalClosureCaptureConsuming: () -> () = {}
func testGlobalClosureCaptureConsuming(_ x: consuming SingleElt) {
    globalClosureCaptureConsuming = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1:29 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2:26 {{conflicting access is here}}
    }
    globalClosureCaptureConsuming()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure35testLocalLetClosureCaptureConsumingyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: [[BORROW_PAI:%.*]] = begin_borrow [lexical] [[PAI]]
// CHECK: [[COPY_BORROW_PAI:%.*]] = copy_value [[BORROW_PAI]]
// CHECK: [[BORROW_COPY_BORROW_PAI:%.*]] = begin_borrow [[COPY_BORROW_PAI]]
// CHECK: apply [[BORROW_COPY_BORROW_PAI]]()
// CHECK: } // end sil function '$s16moveonly_closure35testLocalLetClosureCaptureConsumingyyAA9SingleEltVnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure35testLocalLetClosureCaptureConsumingyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure35testLocalLetClosureCaptureConsumingyyAA9SingleEltVnFyycfU_'
func testLocalLetClosureCaptureConsuming(_ x: consuming SingleElt) {
    // expected-error @-1 {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    // expected-error @-2 {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    // expected-error @-3 {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
    let f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        borrowConsumeVal(x, x) // expected-note {{consuming use here}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure35testLocalVarClosureCaptureConsumingyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: } // end sil function '$s16moveonly_closure35testLocalVarClosureCaptureConsumingyyAA9SingleEltVnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure35testLocalVarClosureCaptureConsumingyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure35testLocalVarClosureCaptureConsumingyyAA9SingleEltVnFyycfU_'
func testLocalVarClosureCaptureConsuming(_ x: consuming SingleElt) {
    var f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f = {}
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure035testConsumingNoEscapeClosureCaptureD0yyyyXEn_AA9SingleEltVntF : $@convention(thin) (@owned @noescape @callee_guaranteed () -> (), @owned SingleElt) -> () {
// CHECK: bb0([[F:%.*]] : @_eagerMove @owned $@noescape @callee_guaranteed () -> (),
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @noescape @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[F]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure035testConsumingNoEscapeClosureCaptureD0yyyyXEn_AA9SingleEltVntFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> ()
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[PROJECT]])
// CHECK:   [[NO_ESCAPE:%.*]] = convert_escape_to_noescape [not_guaranteed] [[PAI]]
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[NO_ESCAPE]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure035testConsumingNoEscapeClosureCaptureD0yyyyXEn_AA9SingleEltVntF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure035testConsumingNoEscapeClosureCaptureD0yyyyXEn_AA9SingleEltVntFyyXEfU_ : $@convention(thin) (@inout_aliasable SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[CHECK:%.*]] = mark_must_check [consumable_and_assignable] [[ARG]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED:%.*]] = load [take] [[ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[CHECK]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[READ_ACCESS]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[CHECK]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[DEINIT_ACCESS]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure035testConsumingNoEscapeClosureCaptureD0yyyyXEn_AA9SingleEltVntFyyXEfU_'
func testConsumingNoEscapeClosureCaptureConsuming(_ f: consuming () -> (),
                                                  _ x: consuming SingleElt) {
    // expected-error @-1 {{'x' consumed more than once}}
    // expected-error @-2 {{'x' used after consume}}
    // expected-error @-3 {{'x' used after consume}}
    f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        // expected-note @-1 {{consuming use here}}
        borrowConsumeVal(x, x)
        // expected-note @-1 {{consuming use here}}
        // expected-note @-2 {{consuming use here}}
        // expected-note @-3 {{non-consuming use here}}
        // expected-error @-4 {{overlapping accesses to 'x', but deinitialization requires exclusive access}}
        // expected-note @-5 {{conflicting access is here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure033testConsumingEscapeClosureCaptureD0yyyycn_AA9SingleEltVntF : $@convention(thin) (@owned @callee_guaranteed () -> (), @owned SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned $@callee_guaranteed () -> (),
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ var SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure033testConsumingEscapeClosureCaptureD0yyyycn_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> ()
// CHECK:   [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK:   mark_function_escape [[PROJECT]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[PAI]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure033testConsumingEscapeClosureCaptureD0yyyycn_AA9SingleEltVntF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure033testConsumingEscapeClosureCaptureD0yyyycn_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { var SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   destroy_value [[LOADED]]
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[ACCESS]]
// CHECK:   [[LOADED:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_access [[ACCESS]]
//
// CHECK:   [[READ_ACCESS:%.*]] = begin_access [read] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[READ_ACCESS]]
// CHECK:   [[LOADED_READ:%.*]] = load [copy] [[CHECK]]
// CHECK:   [[DEINIT_ACCESS:%.*]] = begin_access [deinit] [unknown] [[PROJECT]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [assignable_but_not_consumable] [[DEINIT_ACCESS]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [take] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_access [[DEINIT_ACCESS]]
// CHECK:   destroy_value [[LOADED_READ]]
// CHECK:   end_access [[READ_ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure033testConsumingEscapeClosureCaptureD0yyyycn_AA9SingleEltVntFyycfU_'
func testConsumingEscapeClosureCaptureConsuming(_ f: consuming @escaping () -> (), _ x: consuming SingleElt) {
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable mutable capture of an escaping closure. One can only read from it or assign over it}}
        // expected-error @-1 {{overlapping accesses, but deinitialization requires exclusive access}}
        // expected-note @-2 {{conflicting access is here}}
    }
    f()
}

///////////////////////
// MARK: Owned Tests //
///////////////////////

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure29testGlobalClosureCaptureOwnedyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[GLOBAL:%.*]] = global_addr @$s16moveonly_closure25globalClosureCaptureOwnedyycvp
// CHECK: [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure29testGlobalClosureCaptureOwnedyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [dynamic] [[GLOBAL]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure29testGlobalClosureCaptureOwnedyyAA9SingleEltVnF'

// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure29testGlobalClosureCaptureOwnedyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] : @closureCapture
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure29testGlobalClosureCaptureOwnedyyAA9SingleEltVnFyycfU_'
var globalClosureCaptureOwned: () -> () = {}
func testGlobalClosureCaptureOwned(_ x: __owned SingleElt) {
    globalClosureCaptureOwned = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    globalClosureCaptureOwned()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure31testLocalLetClosureCaptureOwnedyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: [[BORROW_PAI:%.*]] = begin_borrow [lexical] [[PAI]]
// CHECK: [[COPY_BORROW_PAI:%.*]] = copy_value [[BORROW_PAI]]
// CHECK: [[BORROW_COPY_BORROW_PAI:%.*]] = begin_borrow [[COPY_BORROW_PAI]]
// CHECK: apply [[BORROW_COPY_BORROW_PAI]]()
// CHECK: } // end sil function '$s16moveonly_closure31testLocalLetClosureCaptureOwnedyyAA9SingleEltVnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure31testLocalLetClosureCaptureOwnedyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK: } // end sil function '$s16moveonly_closure31testLocalLetClosureCaptureOwnedyyAA9SingleEltVnFyycfU_'
func testLocalLetClosureCaptureOwned(_ x: __owned SingleElt) {
    // expected-error @-1 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    // expected-error @-2 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    // expected-error @-3 {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    let f = {
        borrowVal(x)
        consumeVal(x) // expected-note {{consuming use here}}
        consumeVal(x) // expected-note {{consuming use here}}
        borrowConsumeVal(x, x) // expected-note {{consuming use here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure31testLocalVarClosureCaptureOwnedyyAA9SingleEltVnF : $@convention(thin) (@owned SingleElt) -> () {
// CHECK: [[BOX:%.*]] = alloc_box
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: mark_function_escape [[PROJECT]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] {{%.*}}([[BOX_COPY]])
// CHECK: } // end sil function '$s16moveonly_closure31testLocalVarClosureCaptureOwnedyyAA9SingleEltVnF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure31testLocalVarClosureCaptureOwnedyyAA9SingleEltVnFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure31testLocalVarClosureCaptureOwnedyyAA9SingleEltVnFyycfU_'
func testLocalVarClosureCaptureOwned(_ x: __owned SingleElt) {
    var f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f = {}
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure31testInOutVarClosureCaptureOwnedyyyycz_AA9SingleEltVntF : $@convention(thin) (@inout @callee_guaranteed () -> (), @owned SingleElt) -> () {
// CHECK: bb0([[F:%.*]] : $*@callee_guaranteed () -> (),
// CHECK: [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK: [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK: [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure31testInOutVarClosureCaptureOwnedyyyycz_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> ()
// CHECK: [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK: [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] [[F]]
// CHECK: assign [[PAI]] to [[ACCESS]]
// CHECK: end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure31testInOutVarClosureCaptureOwnedyyyycz_AA9SingleEltVntF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure31testInOutVarClosureCaptureOwnedyyyycz_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure31testInOutVarClosureCaptureOwnedyyyycz_AA9SingleEltVntFyycfU_'
func testInOutVarClosureCaptureOwned(_ f: inout () -> (), _ x: __owned SingleElt) {
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureOwnedyyyyXEn_AA9SingleEltVntF : $@convention(thin) (@owned @noescape @callee_guaranteed () -> (), @owned SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned $@noescape @callee_guaranteed () -> (),
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @noescape @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureOwnedyyyyXEn_AA9SingleEltVntFyyXEfU_ : $@convention(thin) (@guaranteed SingleElt) -> ()
// CHECK:   [[MARKED:%.*]] = mark_must_check [assignable_but_not_consumable] [[PROJECT]]
// CHECK:   [[LOADED_VALUE:%.*]] = load [copy] [[MARKED]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[LOADED_VALUE]])
// CHECK:   [[NO_ESCAPE:%.*]] = convert_escape_to_noescape [not_guaranteed] [[PAI]]
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[NO_ESCAPE]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure40testConsumingNoEscapeClosureCaptureOwnedyyyyXEn_AA9SingleEltVntF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure40testConsumingNoEscapeClosureCaptureOwnedyyyyXEn_AA9SingleEltVntFyyXEfU_ : $@convention(thin) (@guaranteed SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[ARG_COPY]]
// CHECK: } // end sil function '$s16moveonly_closure40testConsumingNoEscapeClosureCaptureOwnedyyyyXEn_AA9SingleEltVntFyyXEfU_'
func testConsumingNoEscapeClosureCaptureOwned(_ f: consuming () -> (),
                                              _ x: __owned SingleElt) {
    // expected-error @-1 {{'x' consumed and used at the same time}}
    f = {
        borrowVal(x)
        consumeVal(x)
        consumeVal(x)
        borrowConsumeVal(x, x) // expected-note {{consuming and non-consuming uses here}}
    }
    f()
}

// CHECK-LABEL: sil hidden [ossa] @$s16moveonly_closure38testConsumingEscapeClosureCaptureOwnedyyyycn_AA9SingleEltVntF : $@convention(thin) (@owned @callee_guaranteed () -> (), @owned SingleElt) -> () {
// CHECK: bb0([[ARG:%.*]] : @_eagerMove @owned $@callee_guaranteed () -> (),
// CHECK:   [[FUNC_BOX:%.*]] = alloc_box ${ var @callee_guaranteed () -> () }
// CHECK:   [[FUNC_PROJECT:%.*]] = project_box [[FUNC_BOX]]
// CHECK:   store [[ARG]] to [init] [[FUNC_PROJECT]]
//
// CHECK:   [[BOX:%.*]] = alloc_box ${ let SingleElt }
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
// CHECK:   [[CLOSURE:%.*]] = function_ref @$s16moveonly_closure38testConsumingEscapeClosureCaptureOwnedyyyycn_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> ()
// CHECK:   [[BOX_COPY:%.*]] = copy_value [[BOX]]
// CHECK:   mark_function_escape [[PROJECT]]
// CHECK:   [[PAI:%.*]] = partial_apply [callee_guaranteed] [[CLOSURE]]([[BOX_COPY]])
// CHECK:   [[ACCESS:%.*]] = begin_access [modify] [unknown] [[FUNC_PROJECT]]
// CHECK:   assign [[PAI]] to [[ACCESS]]
// CHECK:   end_access [[ACCESS]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingEscapeClosureCaptureOwnedyyyycn_AA9SingleEltVntF'
//
// CHECK-LABEL: sil private [ossa] @$s16moveonly_closure38testConsumingEscapeClosureCaptureOwnedyyyycn_AA9SingleEltVntFyycfU_ : $@convention(thin) (@guaranteed { let SingleElt }) -> () {
// CHECK: bb0([[BOX:%.*]] :
// CHECK:   [[PROJECT:%.*]] = project_box [[BOX]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load_borrow [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
// CHECK:   end_borrow [[LOADED]]
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED]])
//
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_READ:%.*]] = load_borrow [[CHECK]]
// CHECK:   [[CHECK:%.*]] = mark_must_check [no_consume_or_assign] [[PROJECT]]
// CHECK:   [[LOADED_TAKE:%.*]] = load [copy] [[CHECK]]
// CHECK:   apply {{%.*}}([[LOADED_READ]], [[LOADED_TAKE]])
// CHECK:   end_borrow [[LOADED_READ]]
// CHECK: } // end sil function '$s16moveonly_closure38testConsumingEscapeClosureCaptureOwnedyyyycn_AA9SingleEltVntFyycfU_'
func testConsumingEscapeClosureCaptureOwned(_ f: consuming @escaping () -> (),
                                            _ x: __owned SingleElt) {
    f = {
        borrowVal(x)
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        consumeVal(x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
        borrowConsumeVal(x, x) // expected-error {{'x' was consumed but it is illegal to consume a noncopyable immutable capture of an escaping closure. One can only read from it}}
    }
    f()
}
