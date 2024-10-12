// RUN: %empty-directory(%t)
// RUN: %llvm-nm -g --defined-only -f just-symbols %stdlib_dir/arm64/libswiftObservation.dylib > %t/symbols
// RUN: %abi-symbol-checker %s %t/symbols
// RUN: diff -u %S/../../Inputs/macOS/arm64/observation/baseline %t/symbols

// REQUIRES: swift_stdlib_no_asserts
// REQUIRES: STDLIB_VARIANT=macosx-arm64

// *** DO NOT DISABLE OR XFAIL THIS TEST. *** (See comment below.)

// Welcome, Build Wrangler!
//
// This file lists APIs that have recently changed in a way that potentially
// indicates an ABI- or source-breaking problem.
//
// A failure in this test indicates that there is a potential breaking change in
// the Standard Library. If you observe a failure outside of a PR test, please
// reach out to the Standard Library team directly to make sure this gets
// resolved quickly! If your own PR fails in this test, you probably have an
// ABI- or source-breaking change in your commits. Please go and fix it.
//
// Please DO NOT DISABLE THIS TEST. In addition to ignoring the current set of
// ABI breaks, XFAILing this test also silences any future ABI breaks that may
// land on this branch, which simply generates extra work for the next person
// that picks up the mess.
//
// Instead of disabling this test, you'll need to extend the list of expected
// changes at the bottom. (You'll also need to do this if your own PR triggers
// false positives, or if you have special permission to break things.) You can
// find a diff of what needs to be added in the output of the failed test run.
// The order of lines doesn't matter, and you can also include comments to refer
// to any bugs you filed.
//
// Thank you for your help ensuring the stdlib remains compatible with its past!
//                                            -- Your friendly stdlib engineers

// Observation Symbols

// Observation.ObservationTracking.changed.getter : Swift.AnyKeyPath?
Added: _$s11Observation0A8TrackingV7changeds10AnyKeyPathCSgvg

// property descriptor for Observation.ObservationTracking.changed : Swift.AnyKeyPath?
Added: _$s11Observation0A8TrackingV7changeds10AnyKeyPathCSgvpMV

// Observation.ObservationTracking.changedPath.getter : Observation.ObservationTracking.Path?
Added: _$s11Observation0A8TrackingV11changedPathAC0D0VSgvg

// property descriptor for Observation.ObservationTracking.changedPath : Observation.ObservationTracking.Path?
Added: _$s11Observation0A8TrackingV11changedPathAC0D0VSgvpMV

// static Observation.ObservationTracking.Path.== infix(Observation.ObservationTracking.Path, Swift.AnyKeyPath) -> Swift.Bool
Added: _$s11Observation0A8TrackingV4PathV2eeoiySbAE_s06AnyKeyC0CtFZ

// static Observation.ObservationTracking.Path.== infix(Swift.AnyKeyPath, Observation.ObservationTracking.Path) -> Swift.Bool
Added: _$s11Observation0A8TrackingV4PathV2eeoiySbs06AnyKeyC0C_AEtFZ

// static Observation.ObservationTracking.Path.!= infix(Observation.ObservationTracking.Path, Swift.AnyKeyPath) -> Swift.Bool
Added: _$s11Observation0A8TrackingV4PathV2neoiySbAE_s06AnyKeyC0CtFZ

// static Observation.ObservationTracking.Path.!= infix(Swift.AnyKeyPath, Observation.ObservationTracking.Path) -> Swift.Bool
Added: _$s11Observation0A8TrackingV4PathV2neoiySbs06AnyKeyC0C_AEtFZ

// Observation.ObservationTracking.Path.rootType.getter : Any.Type
Added: _$s11Observation0A8TrackingV4PathV8rootTypeypXpvg

// property descriptor for Observation.ObservationTracking.Path.rootType : Any.Type
Added: _$s11Observation0A8TrackingV4PathV8rootTypeypXpvpMV

// Observation.ObservationTracking.Path.valueType.getter : Any.Type
Added: _$s11Observation0A8TrackingV4PathV9valueTypeypXpvg

// property descriptor for Observation.ObservationTracking.Path.valueType : Any.Type
Added: _$s11Observation0A8TrackingV4PathV9valueTypeypXpvpMV

// type metadata accessor for Observation.ObservationTracking.Path
Added: _$s11Observation0A8TrackingV4PathVMa

// nominal type descriptor for Observation.ObservationTracking.Path
Added: _$s11Observation0A8TrackingV4PathVMn

// type metadata for Observation.ObservationTracking.Path
Added: _$s11Observation0A8TrackingV4PathVN
