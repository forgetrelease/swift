// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -emit-sil %s -verify
// -- Check that we can successfully round-trip.
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -D IRGEN -emit-ir %s >/dev/null

// REQUIRES: objc_interop

import Foundation
import user_objc

// NS_ENUM
var mince = NSRuncingMode.mince
var quince = NSRuncingMode.quince

var rawMince: UInt = NSRuncingMode.mince.rawValue
var rawFoo: CInt = NSUnderlyingType.foo.rawValue
var rawNegativeOne: CUnsignedInt
  = NSUnsignedUnderlyingTypeNegativeValue.negativeOne.rawValue

var rawWordBreakA: Int = NSPrefixWordBreak.banjo.rawValue
var rawWordBreakB: Int = NSPrefixWordBreak.bandana.rawValue

var rawWordBreak2A: Int = NSPrefixWordBreak2.breakBarBas.rawValue
var rawWordBreak2B: Int = NSPrefixWordBreak2.breakBareBass.rawValue

var rawWordBreak3A: Int = NSPrefixWordBreak3.break1Bob.rawValue
var rawWordBreak3B: Int = NSPrefixWordBreak3.break1Ben.rawValue

var singleConstant = NSSingleConstantEnum.value

var myCoolWaterMelon = MyCoolEnum.waterMelon

var hashMince: Int = NSRuncingMode.mince.hashValue
if NSRuncingMode.mince != .quince { }

var numberBehavior: NSNumberFormatterBehavior = .behaviorDefault
numberBehavior = .behavior10_4
var postingStyle: NSPostingStyle = .postWhenIdle
postingStyle = .postASAP

func handler(_ formatter: NSByteCountFormatter) {
	// Ensure that the Equality protocol is properly added to an
	// imported ObjC enum type before the type is referenced by name
    if (formatter.countStyle == .file) {}
}

// Unfortunate consequence of treating runs of capitals as a single word.
// See <rdar://problem/16768954>.
var pathStyle: CFURLPathStyle = .cfurlposixPathStyle
pathStyle = .cfurlWindowsPathStyle
var URLOrUTI: CFURLOrUTI = .cfurlKind
URLOrUTI = .cfutiKind

let magnitude: Magnitude = .k2
let magnitude2: MagnitudeWords = .two

let objcABI: objc_abi = .v2
let underscoreSuffix: ALL_CAPS_ENUM = .ENUM_CASE_ONE
let underscoreSuffix2: ALL_CAPS_ENUM2 = .CASE_TWO

var alias1 = NSAliasesEnum.bySameValue
var alias2 = NSAliasesEnum.byEquivalentValue
var alias3 = NSAliasesEnum.byName
var aliasOriginal = NSAliasesEnum.original

switch aliasOriginal {
case .original:
  break
case .differentValue:
  break
}
switch aliasOriginal {
case .original:
  break
default:
  break
}

switch aliasOriginal {
case .bySameValue:
  break
case .differentValue:
  break
}
switch aliasOriginal {
case .bySameValue:
  break
default:
  break
}

switch aliasOriginal {
case NSAliasesEnum.bySameValue:
  break
case NSAliasesEnum.differentValue:
  break
}

extension NSAliasesEnum {
  func test() {
    switch aliasOriginal {
    case .bySameValue:
      break
    case .differentValue:
      break
    }
  }
}

// Test NS_SWIFT_NAME:
_ = NSXMLNodeKind.DTDKind == .invalidKind

_ = NSPrefixWordBreakCustom.problemCase == .deprecatedGoodCase // expected-warning {{deprecated}}

_ = NSPrefixWordBreak2Custom.problemCase == .goodCase
_ = NSPrefixWordBreak2Custom.problemCase == .PrefixWordBreak2DeprecatedBadCase // expected-warning {{deprecated}}
_ = NSPrefixWordBreak2Custom.problemCase == .deprecatedGoodCase // expected-warning {{deprecated}}

_ = NSPrefixWordBreakReversedCustom.problemCase == .deprecatedGoodCase // expected-warning {{deprecated}}

_ = NSPrefixWordBreakReorderedCustom.problemCase == .goodCase
_ = NSPrefixWordBreakReorderedCustom.problemCase == .PrefixWordBreakReorderedDeprecatedBadCase // expected-warning {{deprecated}}
_ = NSPrefixWordBreakReorderedCustom.problemCase == .deprecatedGoodCase // expected-warning {{deprecated}}

_ = NSPrefixWordBreakReordered2Custom.problemCase == .goodCase
_ = NSPrefixWordBreakReordered2Custom.problemCase == .PrefixWordBreakReordered2DeprecatedBadCase // expected-warning {{deprecated}}
_ = NSPrefixWordBreakReordered2Custom.problemCase == .deprecatedGoodCase // expected-warning {{deprecated}}

_ = NSSwiftNameAllTheThings.Foo == .Bar
_ = NSSwiftNameBad.`class`


#if !IRGEN
var qualifiedName = NSRuncingMode.mince
var topLevelCaseName = NSRuncingMince // expected-error{{}}
#endif

// NS_OPTIONS
var withMince: NSRuncingOptions = .enableMince
var withQuince: NSRuncingOptions = .enableQuince

// When there is a single enum constant, compare it against the type name to
// derive the namespaced name.
var singleValue: NSSingleOptions = .value

// Check OptionSet conformance.
var minceAndQuince: NSRuncingOptions = NSRuncingOptions.enableMince.intersection(NSRuncingOptions.enableQuince)
var minceOrQuince: NSRuncingOptions = [.enableMince, .enableQuince]
minceOrQuince.formIntersection(minceAndQuince)
minceOrQuince.formUnion(minceAndQuince)

var minceValue: UInt = minceAndQuince.rawValue
var minceFromMask: NSRuncingOptions = []

// Strip leading 'k' in "kConstant".
let calendarUnit: CFCalendarUnit = [.year, .weekday]
// ...unless the next character is a non-identifier.
let curve3D: AU3DMixerAttenuationCurve = .k3DMixerAttenuationCurve_Exponential

// Match various plurals.
let observingOpts: NSKeyValueObservingOptions = [.new, .old]
let bluetoothProps: CBCharacteristicProperties = [.write, .writeWithoutResponse]
let buzzFilter: AlertBuzzes = [.funk, .sosumi]

// Match multi-capital acronym.
let bitmapFormat: NSBitmapFormat = [.NSAlphaFirstBitmapFormat, .NS32BitBigEndianBitmapFormat];
let bitmapFormatR: NSBitmapFormatReversed = [.NSAlphaFirstBitmapFormatR, .NS32BitBigEndianBitmapFormatR];
let bitmapFormat2: NSBitmapFormat2  = [.NSU16a  , .NSU32a]
let bitmapFormat3: NSBitmapFormat3  = [.NSU16b  , .NSS32b]
let bitmapFormat4: NSUBitmapFormat4 = [.NSU16c  , .NSU32c]
let bitmapFormat5: NSABitmapFormat5 = [.NSAA16d , .NSAB32d]

// Drop trailing underscores when possible.
let timeFlags: CMTimeFlags = [.valid , .hasBeenRounded]
let timeFlags2: CMTimeFlagsWithNumber = [._Valid, ._888]
let audioComponentOpts: AudioComponentInstantiationOptions = [.loadOutOfProcess]
let audioComponentFlags: AudioComponentFlags = [.sandboxSafe]
let audioComponentFlags2: FakeAudioComponentFlags = [.loadOutOfProcess]

let objcFlags: objc_flags = [.taggedPointer, .swiftRefcount]

let optionsWithSwiftName: NSOptionsAlsoGetSwiftName = .Case
