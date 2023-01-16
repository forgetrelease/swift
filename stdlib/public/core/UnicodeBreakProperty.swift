//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftShims

extension Unicode {
  internal enum _GraphemeBreakProperty: UInt8 {
    // Values 0...4 are aligned with bit field values in generated data.
    case control = 0
    case extend = 1
    case prepend = 2
    case spacingMark = 3
    case extendedPictographic = 4
    case l = 5
    case lv = 6
    case lvt = 7
    case v = 8
    case t = 9
    case zwj = 10
    case regionalIndicator = 11
    case any = 12

    init(from scalar: Unicode.Scalar) {
      // FIXME: Reimplement this as a linear scan in a short lookup table
      switch scalar.value {
      // NOTE: CR-LF special case has already been checked.
      case 0x0 ... 0x1F:
        self = .control

      // Some fast paths for common characters.
      case 0x20 ... 0x7E, // ASCII
           // TODO: This doesn't generate optimal code, tune/re-write at a lower
           // level.
           //
           // NOTE: Order of case ranges affects codegen, and thus performance.
           // All things being equal, keep existing order below.

           // Unified CJK Han ideographs, common and some supplemental, amongst
           // others.
           0x3400...0xa4cf,
           // Latin characters.
           0x0100...0x02ff,
           // Non-combining kana.
           0x3041...0x3096,
           0x30a1...0x30fc,
           // Non-combining modern (and some archaic) Cyrillic.
           // (First half of Cyrillic block)
           0x0400...0x0482,
           // Modern Arabic, excluding extenders and prependers.
           0x061d...0x064a,
           // Common general use punctuation, excluding extenders.
           0x2010...0x2027,
           // CJK punctuation characters, excluding extenders.
           0x3000...0x3029:
        self = .any

      case 0x200D:
        self = .zwj
      case 0x1100 ... 0x115F,
           0xA960 ... 0xA97C:
        self = .l
      case 0x1160 ... 0x11A7,
           0xD7B0 ... 0xD7C6:
        self = .v
      case 0x11A8 ... 0x11FF,
           0xD7CB ... 0xD7FB:
        self = .t
      case 0xAC00 ... 0xD7A3:
        if scalar.value % 28 == 16 {
          self = .lv
        } else {
          self = .lvt
        }
      case 0x1F1E6 ... 0x1F1FF:
        self = .regionalIndicator
      case 0x1FC00 ... 0x1FFFD:
        self = .extendedPictographic
      case 0xE01F0 ... 0xE0FFF:
        self = .control
      default:
        // Otherwise, default to binary searching the data array.
        let rawEnumValue = _swift_stdlib_getGraphemeBreakProperty(scalar.value)

        switch rawEnumValue {
        case 0:
          self = .control
        case 1:
          self = .extend
        case 2:
          self = .prepend
        case 3:
          self = .spacingMark

        // Extended pictographic uses 2 values for its representation.
        case 4, 5:
          self = .extendedPictographic
        default:
          self = .any
        }
      }
    }
  }
}

extension Unicode {
  internal enum _WordBreakProperty {
    case aLetter
    case any
    case doubleQuote
    case extend
    case extendedPictographic
    case extendNumLet
    case format
    case hebrewLetter
    case katakana
    case midLetter
    case midNum
    case midNumLet
    case newlineCRLF
    case numeric
    case regionalIndicator
    case singleQuote
    case wSegSpace
    case zwj
    
    init(from scalar: Unicode.Scalar) {
      switch scalar.value {
      case 0xA ... 0xD,
           0x85,
           0x2028 ... 0x2029:
        self = .newlineCRLF
      case 0x22:
        self = .doubleQuote
      case 0x27:
        self = .singleQuote
      case 0x200D:
        self = .zwj
      case 0x1F1E6 ... 0x1F1FF:
        self = .regionalIndicator
      default:
        let rawValue = _swift_stdlib_getWordBreakProperty(scalar.value)
        
        switch rawValue {
        case 0:
          self = .extend
        case 1:
          self = .format
        case 2:
          self = .katakana
        case 3:
          self = .hebrewLetter
        case 4:
          self = .aLetter
        case 5:
          self = .midNumLet
        case 6:
          self = .midLetter
        case 7:
          self = .midNum
        case 8:
          self = .numeric
        case 9:
          self = .extendNumLet
        case 10:
          self = .wSegSpace
        case 11:
          self = .extendedPictographic
        default:
          self = .any
        }
      }
    }
  }
}
