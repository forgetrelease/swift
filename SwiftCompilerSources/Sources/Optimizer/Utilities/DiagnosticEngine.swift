//===--- DiagnosticEngine.swift -------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import ASTBridging

import Basic
import SIL

public typealias DiagID = BridgedDiagID

public protocol DiagnosticArgument {
  func _withBridgedDiagnosticArgument(_ fn: (BridgedDiagnosticArgument) -> Void)
}
extension String: DiagnosticArgument {
  public func _withBridgedDiagnosticArgument(_ fn: (BridgedDiagnosticArgument) -> Void) {
    _withBridgedStringRef { fn(BridgedDiagnosticArgument($0)) }
  }
}
extension Int: DiagnosticArgument {
  public func _withBridgedDiagnosticArgument(_ fn: (BridgedDiagnosticArgument) -> Void) {
    fn(BridgedDiagnosticArgument(self))
  }
}
extension Type: DiagnosticArgument {
  public func _withBridgedDiagnosticArgument(_ fn: (BridgedDiagnosticArgument) -> Void) {
    fn(bridged.asDiagnosticArgument())
  }
}
extension DeclRef: DiagnosticArgument {
  public func _withBridgedDiagnosticArgument(_ fn: (BridgedDiagnosticArgument) -> Void) {
    fn(bridged.asDiagnosticArgument())
  }
}

public struct DiagnosticFixIt {
  public let start: SourceLoc
  public let byteLength: Int
  public let text: String

  public init(start: SourceLoc, byteLength: Int, replacement text: String) {
    self.start = start
    self.byteLength = byteLength
    self.text = text
  }

  func withBridgedDiagnosticFixIt(_ fn: (BridgedDiagnosticFixIt) -> Void) {
    text._withBridgedStringRef { bridgedTextRef in
      let bridgedDiagnosticFixIt = BridgedDiagnosticFixIt(
        start.bridged, UInt32(byteLength),
        bridgedTextRef)
      fn(bridgedDiagnosticFixIt)
    }
  }
}

public struct DiagnosticEngine {
  private let bridged: BridgedDiagnosticEngine

  public init(bridged: BridgedDiagnosticEngine) {
    self.bridged = bridged
  }
  public init?(bridged: BridgedNullableDiagnosticEngine) {
    guard let raw = bridged.raw else {
      return nil
    }
    self.bridged = BridgedDiagnosticEngine(raw: raw)
  }

  public func diagnose(_ position: SourceLoc?,
                       _ id: DiagID,
                       _ args: [DiagnosticArgument],
                       highlight: CharSourceRange? = nil,
                       fixIts: [DiagnosticFixIt] = []) {

    let bridgedSourceLoc: BridgedSourceLoc = position.bridged
    let highlightStart: BridgedSourceLoc
    let highlightLength: UInt32
    if let highlight = highlight {
      highlightStart = highlight.start.bridged
      highlightLength = highlight.byteLength
    } else {
      highlightStart = BridgedSourceLoc()
      highlightLength = 0
    }
    var bridgedArgs: [BridgedDiagnosticArgument] = []
    var bridgedFixIts: [BridgedDiagnosticFixIt] = []

    // Build a higher-order function to wrap every 'withBridgedXXX { ... }'
    // calls, so we don't escape anything from the closure. 'bridgedArgs' and
    // 'bridgedFixIts' are temporary storage to store bridged values. So they
    // should not be used after the closure is executed.
 
    var closure: () -> Void = {
      bridgedArgs.withBridgedArrayRef { bridgedArgsRef in
        bridgedFixIts.withBridgedArrayRef { bridgedFixItsRef in
          bridged.diagnose(at: bridgedSourceLoc, id, bridgedArgsRef,
                           highlightAt: highlightStart,
                           highlightLength: highlightLength,
                           fixIts: bridgedFixItsRef)
        }
      }
    }
    // 'reversed()' because the closure should be wrapped in that order.
    for arg in args.reversed() {
      closure = { [closure, arg] in
        arg._withBridgedDiagnosticArgument { bridgedArg in
          bridgedArgs.append(bridgedArg)
          closure()
        }
      }
    }
    // 'reversed()' because the closure should be wrapped in that order.
    for fixIt in fixIts.reversed() {
      closure = { [closure, fixIt] in
        fixIt.withBridgedDiagnosticFixIt { bridgedFixIt in
          bridgedFixIts.append(bridgedFixIt)
          closure()
        }
      }
    }

    closure()
  }

  public func diagnose(_ position: SourceLoc?,
                       _ id: DiagID,
                       _ args: DiagnosticArgument...,
                       highlight: CharSourceRange? = nil,
                       fixIts: DiagnosticFixIt...) {
    diagnose(position, id, args, highlight: highlight, fixIts: fixIts)
  }
}
