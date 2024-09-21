// RUN: %target-typecheck-verify-swift -disable-availability-checking -enable-experimental-feature NonescapableTypes
// REQUIRES: asserts

struct NE : ~Escapable {
  @lifetime(self) // expected-error{{invalid lifetime dependence on self in an initializer}}
  init() {}
}

@lifetime(nonexisting) // expected-error{{invalid parameter name specified 'nonexisting'}}
func invalidAttrOnNonExistingParam(_ ne: NE) -> NE {
  ne
}

@lifetime(self) // expected-error{{invalid lifetime dependence specifier on non-existent self}}
func invalidAttrOnNonExistingSelf(_ ne: NE) -> NE {
  ne
}

@lifetime(2) // expected-error{{invalid parameter index specified 2}}
func invalidAttrOnNonExistingParamIndex(_ ne: NE) -> NE {
  ne
}

@lifetime(ne, ne) // expected-error{{duplicate lifetime dependence specifier}}
func invalidDuplicateLifetimeDependence1(_ ne: borrowing NE) -> NE {
  ne
}

class Klass {}

@lifetime(x) // expected-error{{invalid use of lifetime dependence on an Escapable parameter with consuming ownership}}
func invalidDependence(_ x: consuming Klass) -> NE {
  NE()
}

