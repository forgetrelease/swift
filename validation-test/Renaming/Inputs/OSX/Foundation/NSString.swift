
typealias unichar = UInt16
struct NSStringCompareOptions : OptionSet {
  init(rawValue rawValue: UInt)
  let rawValue: UInt
  static var caseInsensitiveSearch: NSStringCompareOptions { get }
  static var literalSearch: NSStringCompareOptions { get }
  static var backwardsSearch: NSStringCompareOptions { get }
  static var anchoredSearch: NSStringCompareOptions { get }
  static var numericSearch: NSStringCompareOptions { get }
  @available(OSX 10.5, *)
  static var diacriticInsensitiveSearch: NSStringCompareOptions { get }
  @available(OSX 10.5, *)
  static var widthInsensitiveSearch: NSStringCompareOptions { get }
  @available(OSX 10.5, *)
  static var forcedOrderingSearch: NSStringCompareOptions { get }
  @available(OSX 10.7, *)
  static var regularExpressionSearch: NSStringCompareOptions { get }
}
var NSASCIIStringEncoding: UInt { get }
var NSNEXTSTEPStringEncoding: UInt { get }
var NSJapaneseEUCStringEncoding: UInt { get }
var NSUTF8StringEncoding: UInt { get }
var NSISOLatin1StringEncoding: UInt { get }
var NSSymbolStringEncoding: UInt { get }
var NSNonLossyASCIIStringEncoding: UInt { get }
var NSShiftJISStringEncoding: UInt { get }
var NSISOLatin2StringEncoding: UInt { get }
var NSUnicodeStringEncoding: UInt { get }
var NSWindowsCP1251StringEncoding: UInt { get }
var NSWindowsCP1252StringEncoding: UInt { get }
var NSWindowsCP1253StringEncoding: UInt { get }
var NSWindowsCP1254StringEncoding: UInt { get }
var NSWindowsCP1250StringEncoding: UInt { get }
var NSISO2022JPStringEncoding: UInt { get }
var NSMacOSRomanStringEncoding: UInt { get }
var NSUTF16StringEncoding: UInt { get }
var NSUTF16BigEndianStringEncoding: UInt { get }
var NSUTF16LittleEndianStringEncoding: UInt { get }
var NSUTF32StringEncoding: UInt { get }
var NSUTF32BigEndianStringEncoding: UInt { get }
var NSUTF32LittleEndianStringEncoding: UInt { get }
struct NSStringEncodingConversionOptions : OptionSet {
  init(rawValue rawValue: UInt)
  let rawValue: UInt
  static var allowLossy: NSStringEncodingConversionOptions { get }
  static var externalRepresentation: NSStringEncodingConversionOptions { get }
}
class NSString : NSObject, NSCopying, NSMutableCopying, NSSecureCoding {
  var length: Int { get }
  @discardableResult
  func character(at index: Int) -> unichar
}

extension NSString : StringLiteralConvertible {
}

extension NSString {
  convenience init(format format: NSString, _ args: CVarArg...)
  convenience init(format format: NSString, locale locale: NSLocale?, _ args: CVarArg...)
  @warn_unused_result
  class func localizedStringWithFormat(_ format: NSString, _ args: CVarArg...) -> Self
  @warn_unused_result
  func appendingFormat(_ format: NSString, _ args: CVarArg...) -> NSString
}

extension NSString {
  @objc(_swiftInitWithString_NSString:) convenience init(string aString: NSString)
}

extension NSString : CustomPlaygroundQuickLookable {
}
extension NSString {
  @discardableResult
  func substring(from from: Int) -> String
  @discardableResult
  func substring(to to: Int) -> String
  @discardableResult
  func substring(with range: NSRange) -> String
  func getCharacters(_ buffer: UnsafeMutablePointer<unichar>, range range: NSRange)
  @discardableResult
  func compare(_ string: String) -> NSComparisonResult
  @discardableResult
  func compare(_ string: String, options mask: NSStringCompareOptions = []) -> NSComparisonResult
  @discardableResult
  func compare(_ string: String, options mask: NSStringCompareOptions = [], range compareRange: NSRange) -> NSComparisonResult
  @discardableResult
  func compare(_ string: String, options mask: NSStringCompareOptions = [], range compareRange: NSRange, locale locale: AnyObject?) -> NSComparisonResult
  @discardableResult
  func caseInsensitiveCompare(_ string: String) -> NSComparisonResult
  @discardableResult
  func localizedCompare(_ string: String) -> NSComparisonResult
  @discardableResult
  func localizedCaseInsensitiveCompare(_ string: String) -> NSComparisonResult
  @available(OSX 10.6, *)
  @discardableResult
  func localizedStandardCompare(_ string: String) -> NSComparisonResult
  @discardableResult
  func isEqual(to aString: String) -> Bool
  @discardableResult
  func hasPrefix(_ str: String) -> Bool
  @discardableResult
  func hasSuffix(_ str: String) -> Bool
  @discardableResult
  func commonPrefix(with str: String, options mask: NSStringCompareOptions = []) -> String
  @available(OSX 10.10, *)
  @discardableResult
  func contains(_ str: String) -> Bool
  @available(OSX 10.10, *)
  @discardableResult
  func localizedCaseInsensitiveContains(_ str: String) -> Bool
  @available(OSX 10.11, *)
  @discardableResult
  func localizedStandardContains(_ str: String) -> Bool
  @available(OSX 10.11, *)
  @discardableResult
  func localizedStandardRange(of str: String) -> NSRange
  @discardableResult
  func range(of searchString: String) -> NSRange
  @discardableResult
  func range(of searchString: String, options mask: NSStringCompareOptions = []) -> NSRange
  @discardableResult
  func range(of searchString: String, options mask: NSStringCompareOptions = [], range searchRange: NSRange) -> NSRange
  @available(OSX 10.5, *)
  @discardableResult
  func range(of searchString: String, options mask: NSStringCompareOptions = [], range searchRange: NSRange, locale locale: NSLocale?) -> NSRange
  @discardableResult
  func rangeOfCharacter(from searchSet: NSCharacterSet) -> NSRange
  @discardableResult
  func rangeOfCharacter(from searchSet: NSCharacterSet, options mask: NSStringCompareOptions = []) -> NSRange
  @discardableResult
  func rangeOfCharacter(from searchSet: NSCharacterSet, options mask: NSStringCompareOptions = [], range searchRange: NSRange) -> NSRange
  @discardableResult
  func rangeOfComposedCharacterSequence(at index: Int) -> NSRange
  @available(OSX 10.5, *)
  @discardableResult
  func rangeOfComposedCharacterSequences(for range: NSRange) -> NSRange
  @discardableResult
  func appending(_ aString: String) -> String
  var doubleValue: Double { get }
  var floatValue: Float { get }
  var intValue: Int32 { get }
  @available(OSX 10.5, *)
  var integerValue: Int { get }
  @available(OSX 10.5, *)
  var longLongValue: Int64 { get }
  @available(OSX 10.5, *)
  var boolValue: Bool { get }
  var uppercased: String { get }
  var lowercased: String { get }
  var capitalized: String { get }
  @available(OSX 10.11, *)
  var localizedUppercase: String { get }
  @available(OSX 10.11, *)
  var localizedLowercase: String { get }
  @available(OSX 10.11, *)
  var localizedCapitalized: String { get }
  @available(OSX 10.8, *)
  @discardableResult
  func uppercased(with locale: NSLocale?) -> String
  @available(OSX 10.8, *)
  @discardableResult
  func lowercased(with locale: NSLocale?) -> String
  @available(OSX 10.8, *)
  @discardableResult
  func capitalized(with locale: NSLocale?) -> String
  func getLineStart(_ startPtr: UnsafeMutablePointer<Int>?, end lineEndPtr: UnsafeMutablePointer<Int>?, contentsEnd contentsEndPtr: UnsafeMutablePointer<Int>?, for range: NSRange)
  @discardableResult
  func lineRange(for range: NSRange) -> NSRange
  func getParagraphStart(_ startPtr: UnsafeMutablePointer<Int>?, end parEndPtr: UnsafeMutablePointer<Int>?, contentsEnd contentsEndPtr: UnsafeMutablePointer<Int>?, for range: NSRange)
  @discardableResult
  func paragraphRange(for range: NSRange) -> NSRange
  @available(OSX 10.6, *)
  func enumerateSubstrings(in range: NSRange, options opts: NSStringEnumerationOptions = [], using block: (String?, NSRange, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void)
  @available(OSX 10.6, *)
  func enumerateLines(_ block: (String, UnsafeMutablePointer<ObjCBool>) -> Void)
  var utf8String: UnsafePointer<Int8>? { get }
  var fastestEncoding: UInt { get }
  var smallestEncoding: UInt { get }
  @discardableResult
  func data(using encoding: UInt, allowLossyConversion lossy: Bool) -> NSData?
  @discardableResult
  func data(using encoding: UInt) -> NSData?
  @discardableResult
  func canBeConverted(to encoding: UInt) -> Bool
  @discardableResult
  func cString(using encoding: UInt) -> UnsafePointer<Int8>?
  @discardableResult
  func getCString(_ buffer: UnsafeMutablePointer<Int8>, maxLength maxBufferCount: Int, encoding encoding: UInt) -> Bool
  @discardableResult
  func getBytes(_ buffer: UnsafeMutablePointer<Void>?, maxLength maxBufferCount: Int, usedLength usedBufferCount: UnsafeMutablePointer<Int>?, encoding encoding: UInt, options options: NSStringEncodingConversionOptions = [], range range: NSRange, remaining leftover: NSRangePointer?) -> Bool
  @discardableResult
  func maximumLengthOfBytes(using enc: UInt) -> Int
  @discardableResult
  func lengthOfBytes(using enc: UInt) -> Int
  @discardableResult
  class func availableStringEncodings() -> UnsafePointer<UInt>
  @discardableResult
  class func localizedName(of encoding: UInt) -> String
  @discardableResult
  class func defaultCStringEncoding() -> UInt
  var decomposedStringWithCanonicalMapping: String { get }
  var precomposedStringWithCanonicalMapping: String { get }
  var decomposedStringWithCompatibilityMapping: String { get }
  var precomposedStringWithCompatibilityMapping: String { get }
  @discardableResult
  func components(separatedBy separator: String) -> [String]
  @available(OSX 10.5, *)
  @discardableResult
  func components(separatedBy separator: NSCharacterSet) -> [String]
  @discardableResult
  func trimmingCharacters(in set: NSCharacterSet) -> String
  @discardableResult
  func padding(toLength newLength: Int, withPad padString: String, startingAt padIndex: Int) -> String
  @available(OSX 10.5, *)
  @discardableResult
  func folding(_ options: NSStringCompareOptions = [], locale locale: NSLocale?) -> String
  @available(OSX 10.5, *)
  @discardableResult
  func replacingOccurrences(of target: String, with replacement: String, options options: NSStringCompareOptions = [], range searchRange: NSRange) -> String
  @available(OSX 10.5, *)
  @discardableResult
  func replacingOccurrences(of target: String, with replacement: String) -> String
  @available(OSX 10.5, *)
  @discardableResult
  func replacingCharacters(in range: NSRange, with replacement: String) -> String
  @available(OSX 10.11, *)
  @discardableResult
  func applyingTransform(_ transform: String, reverse reverse: Bool) -> String?
  func write(to url: NSURL, atomically useAuxiliaryFile: Bool, encoding enc: UInt) throws
  func write(toFile path: String, atomically useAuxiliaryFile: Bool, encoding enc: UInt) throws
  convenience init(charactersNoCopy characters: UnsafeMutablePointer<unichar>, length length: Int, freeWhenDone freeBuffer: Bool)
  convenience init(characters characters: UnsafePointer<unichar>, length length: Int)
  convenience init?(utf8String nullTerminatedCString: UnsafePointer<Int8>)
  convenience init(string aString: String)
  convenience init(format format: String, arguments argList: CVaListPointer)
  convenience init(format format: String, locale locale: AnyObject?, arguments argList: CVaListPointer)
  convenience init?(data data: NSData, encoding encoding: UInt)
  convenience init?(bytes bytes: UnsafePointer<Void>, length len: Int, encoding encoding: UInt)
  convenience init?(bytesNoCopy bytes: UnsafeMutablePointer<Void>, length len: Int, encoding encoding: UInt, freeWhenDone freeBuffer: Bool)
  convenience init?(cString nullTerminatedCString: UnsafePointer<Int8>, encoding encoding: UInt)
  convenience init(contentsOf url: NSURL, encoding enc: UInt) throws
  convenience init(contentsOfFile path: String, encoding enc: UInt) throws
  convenience init(contentsOf url: NSURL, usedEncoding enc: UnsafeMutablePointer<UInt>?) throws
  convenience init(contentsOfFile path: String, usedEncoding enc: UnsafeMutablePointer<UInt>?) throws
}
struct NSStringEnumerationOptions : OptionSet {
  init(rawValue rawValue: UInt)
  let rawValue: UInt
  static var byParagraphs: NSStringEnumerationOptions { get }
  static var byComposedCharacterSequences: NSStringEnumerationOptions { get }
  static var byWords: NSStringEnumerationOptions { get }
  static var bySentences: NSStringEnumerationOptions { get }
  static var reverse: NSStringEnumerationOptions { get }
  static var substringNotRequired: NSStringEnumerationOptions { get }
  static var localized: NSStringEnumerationOptions { get }
}
@available(OSX 10.11, *)
let NSStringTransformLatinToKatakana: String
@available(OSX 10.11, *)
let NSStringTransformLatinToHiragana: String
@available(OSX 10.11, *)
let NSStringTransformLatinToHangul: String
@available(OSX 10.11, *)
let NSStringTransformLatinToArabic: String
@available(OSX 10.11, *)
let NSStringTransformLatinToHebrew: String
@available(OSX 10.11, *)
let NSStringTransformLatinToThai: String
@available(OSX 10.11, *)
let NSStringTransformLatinToCyrillic: String
@available(OSX 10.11, *)
let NSStringTransformLatinToGreek: String
@available(OSX 10.11, *)
let NSStringTransformToLatin: String
@available(OSX 10.11, *)
let NSStringTransformMandarinToLatin: String
@available(OSX 10.11, *)
let NSStringTransformHiraganaToKatakana: String
@available(OSX 10.11, *)
let NSStringTransformFullwidthToHalfwidth: String
@available(OSX 10.11, *)
let NSStringTransformToXMLHex: String
@available(OSX 10.11, *)
let NSStringTransformToUnicodeName: String
@available(OSX 10.11, *)
let NSStringTransformStripCombiningMarks: String
@available(OSX 10.11, *)
let NSStringTransformStripDiacritics: String
extension NSString {
  @available(OSX 10.10, *)
  @discardableResult
  class func stringEncoding(for data: NSData, encodingOptions opts: [String : AnyObject]? = [:], convertedString string: AutoreleasingUnsafeMutablePointer<NSString?>?, usedLossyConversion usedLossyConversion: UnsafeMutablePointer<ObjCBool>?) -> UInt
}
@available(OSX 10.10, *)
let NSStringEncodingDetectionSuggestedEncodingsKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionDisallowedEncodingsKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionUseOnlySuggestedEncodingsKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionAllowLossyKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionFromWindowsKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionLossySubstitutionKey: String
@available(OSX 10.10, *)
let NSStringEncodingDetectionLikelyLanguageKey: String
class NSMutableString : NSString {
  func replaceCharacters(in range: NSRange, with aString: String)
}

extension NSMutableString {
  func appendFormat(_ format: NSString, _ args: CVarArg...)
}
extension NSMutableString {
  func insert(_ aString: String, at loc: Int)
  func deleteCharacters(in range: NSRange)
  func append(_ aString: String)
  func setString(_ aString: String)
  @discardableResult
  func replaceOccurrences(of target: String, with replacement: String, options options: NSStringCompareOptions = [], range searchRange: NSRange) -> Int
  @available(OSX 10.11, *)
  @discardableResult
  func applyTransform(_ transform: String, reverse reverse: Bool, range range: NSRange, updatedRange resultingRange: NSRangePointer?) -> Bool
  init(capacity capacity: Int)
}
let NSCharacterConversionException: String
let NSParseErrorException: String
extension NSString {
  @discardableResult
  func propertyList() -> AnyObject
  @discardableResult
  func propertyListFromStringsFileFormat() -> [NSObject : AnyObject]?
}
extension NSString {
  func getCharacters(_ buffer: UnsafeMutablePointer<unichar>)
}
var NSProprietaryStringEncoding: UInt { get }
class NSSimpleCString : NSString {
}
class NSConstantString : NSSimpleCString {
}
