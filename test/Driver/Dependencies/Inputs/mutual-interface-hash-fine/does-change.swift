# Fine-grained v0
---
allNodes:
  - key:
      kind:            sourceFileProvide
      aspect:          interface
      context:         ''
      name:            does-change.swiftdeps
    fingerprint:     after
    sequenceNumber:  0
    defsIDependUpon: [ 10, 9, 4, 8, 2, 7, 6 ]
    isProvides:      true
  - key:
      kind:            sourceFileProvide
      aspect:          implementation
      context:         ''
      name:            does-change.swiftdeps
    fingerprint:     after
    sequenceNumber:  1
    defsIDependUpon: [  ]
    isProvides:      true
  - key:
      kind:            topLevel
      aspect:          interface
      context:         ''
      name:            A
    sequenceNumber:  2
    defsIDependUpon: [ 0 ]
    isProvides:      true
  - key:
      kind:            topLevel
      aspect:          implementation
      context:         ''
      name:            A
    sequenceNumber:  3
    defsIDependUpon: [  ]
    isProvides:      true
  - key:
      kind:            topLevel
      aspect:          interface
      context:         ''
      name:            b
    sequenceNumber:  4
    defsIDependUpon: [ 0 ]
    isProvides:      true
  - key:
      kind:            topLevel
      aspect:          implementation
      context:         ''
      name:            b
    sequenceNumber:  5
    defsIDependUpon: [  ]
    isProvides:      true
  - key:
      kind:            topLevel
      aspect:          interface
      context:         ''
      name:            a
    sequenceNumber:  6
    defsIDependUpon: [  ]
    isProvides:      false
  - key:
      kind:            topLevel
      aspect:          interface
      context:         ''
      name:            IntegerLiteralType
    sequenceNumber:  7
    defsIDependUpon: [  ]
    isProvides:      false
  - key:
      kind:            topLevel
      aspect:          interface
      context:         ''
      name:            FloatLiteralType
    sequenceNumber:  8
    defsIDependUpon: [  ]
    isProvides:      false
  - key:
      kind:            externalDepend
      aspect:          interface
      context:         ''
      name:            '/Users/ungar/s/fine2/build/Ninja-DebugAssert/swift-macosx-x86_64/lib/swift/macosx/Swift.swiftmodule/x86_64.swiftmodule'
    sequenceNumber:  9
    defsIDependUpon: [  ]
    isProvides:      false
  - key:
      kind:            externalDepend
      aspect:          interface
      context:         ''
      name:            '/Users/ungar/s/fine2/build/Ninja-DebugAssert/swift-macosx-x86_64/lib/swift/macosx/SwiftOnoneSupport.swiftmodule/x86_64.swiftmodule'
    sequenceNumber:  10
    defsIDependUpon: [  ]
    isProvides:      false
...
