// RUN: %target-swift-frontend %s -O -emit-sil

// Make sure we are not crashing on this one.

var a : [String] = ["foo"]

preconditionFailure("unreachable")
for i in 0...a.count {
  let x = 0
}

REQUIRES: updating_for_owned_noescape
