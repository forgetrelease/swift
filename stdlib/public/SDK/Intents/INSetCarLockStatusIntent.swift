//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - current Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@_exported import Intents
import Foundation

#if os(iOS) || os(watchOS)
@available(iOS 10.3, watchOS 3.2, *)
extension INSetCarLockStatusIntent {
    @nonobjc
    public convenience init(locked: Bool?, carName: INSpeakableString?) {
        self.init(__locked:locked as NSNumber?, carName:carName)
    }

    @nonobjc
    public final var locked: Bool? {
        return __locked?.boolValue
    }
}
#endif
