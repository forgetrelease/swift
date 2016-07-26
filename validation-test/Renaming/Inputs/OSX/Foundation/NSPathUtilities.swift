
extension NSString {
  @discardableResult
  class func path(withComponents components: [String]) -> String
  var pathComponents: [String] { get }
  var isAbsolutePath: Bool { get }
  var lastPathComponent: String { get }
  var deletingLastPathComponent: String { get }
  @discardableResult
  func appendingPathComponent(_ str: String) -> String
  var pathExtension: String { get }
  var deletingPathExtension: String { get }
  @discardableResult
  func appendingPathExtension(_ str: String) -> String?
  var abbreviatingWithTildeInPath: String { get }
  var expandingTildeInPath: String { get }
  var standardizingPath: String { get }
  var resolvingSymlinksInPath: String { get }
  @discardableResult
  func strings(byAppendingPaths paths: [String]) -> [String]
  @discardableResult
  func completePath(into outputName: AutoreleasingUnsafeMutablePointer<NSString>?, caseSensitive flag: Bool, matchesInto outputArray: AutoreleasingUnsafeMutablePointer<NSArray>?, filterTypes filterTypes: [String]?) -> Int
  var fileSystemRepresentation: UnsafePointer<Int8> { get }
  @discardableResult
  func getFileSystemRepresentation(_ cname: UnsafeMutablePointer<Int8>, maxLength max: Int) -> Bool
}
extension NSArray {
  @discardableResult
  func pathsMatchingExtensions(_ filterTypes: [String]) -> [String]
}
@discardableResult
func NSUserName() -> String
@discardableResult
func NSFullUserName() -> String
@discardableResult
func NSHomeDirectory() -> String
@discardableResult
func NSHomeDirectoryForUser(_ userName: String?) -> String?
@discardableResult
func NSTemporaryDirectory() -> String
@discardableResult
func NSOpenStepRootDirectory() -> String
enum NSSearchPathDirectory : UInt {
  init?(rawValue rawValue: UInt)
  var rawValue: UInt { get }
  case applicationDirectory
  case demoApplicationDirectory
  case developerApplicationDirectory
  case adminApplicationDirectory
  case libraryDirectory
  case developerDirectory
  case userDirectory
  case documentationDirectory
  case documentDirectory
  case coreServiceDirectory
  @available(OSX 10.6, *)
  case autosavedInformationDirectory
  case desktopDirectory
  case cachesDirectory
  case applicationSupportDirectory
  @available(OSX 10.5, *)
  case downloadsDirectory
  @available(OSX 10.6, *)
  case inputMethodsDirectory
  @available(OSX 10.6, *)
  case moviesDirectory
  @available(OSX 10.6, *)
  case musicDirectory
  @available(OSX 10.6, *)
  case picturesDirectory
  @available(OSX 10.6, *)
  case printerDescriptionDirectory
  @available(OSX 10.6, *)
  case sharedPublicDirectory
  @available(OSX 10.6, *)
  case preferencePanesDirectory
  @available(OSX 10.8, *)
  case applicationScriptsDirectory
  @available(OSX 10.6, *)
  case itemReplacementDirectory
  case allApplicationsDirectory
  case allLibrariesDirectory
  @available(OSX 10.8, *)
  case trashDirectory
}
struct NSSearchPathDomainMask : OptionSet {
  init(rawValue rawValue: UInt)
  let rawValue: UInt
  static var userDomainMask: NSSearchPathDomainMask { get }
  static var localDomainMask: NSSearchPathDomainMask { get }
  static var networkDomainMask: NSSearchPathDomainMask { get }
  static var systemDomainMask: NSSearchPathDomainMask { get }
  static var allDomainsMask: NSSearchPathDomainMask { get }
}
@discardableResult
func NSSearchPathForDirectoriesInDomains(_ directory: NSSearchPathDirectory, _ domainMask: NSSearchPathDomainMask, _ expandTilde: Bool) -> [String]
