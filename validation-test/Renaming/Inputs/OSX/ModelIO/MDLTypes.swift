
@available(OSX 10.11, *)
let kUTTypeAlembic: String
@available(OSX 10.11, *)
let kUTType3dObject: String
@available(OSX 10.11, *)
let kUTTypePolygon: String
@available(OSX 10.11, *)
let kUTTypeStereolithography: String
enum MDLIndexBitDepth : UInt {
  init?(rawValue rawValue: UInt)
  var rawValue: UInt { get }
  case invalid
  case uInt8
  static var uint8: MDLIndexBitDepth { get }
  case uInt16
  static var uint16: MDLIndexBitDepth { get }
  case uInt32
  static var uint32: MDLIndexBitDepth { get }
}
enum MDLGeometryType : Int {
  init?(rawValue rawValue: Int)
  var rawValue: Int { get }
  case typePoints
  case typeLines
  case typeTriangles
  case typeTriangleStrips
  case typeQuads
  case typeVariableTopology
  static var kindPoints: MDLGeometryType { get }
  static var kindLines: MDLGeometryType { get }
  static var kindTriangles: MDLGeometryType { get }
  static var kindTriangleStrips: MDLGeometryType { get }
  static var kindQuads: MDLGeometryType { get }
}
@available(OSX 10.11, *)
protocol MDLNamed {
  var name: String { get set }
}
@available(OSX 10.11, *)
protocol MDLComponent : NSObjectProtocol {
}
@available(OSX 10.11, *)
protocol MDLObjectContainerComponent : MDLComponent, NSFastEnumeration {
  func add(_ object: MDLObject)
  func remove(_ object: MDLObject)
  var objects: [MDLObject] { get }
}
struct MDL_EXPORT_CPPCLASS {
  var maxBounds: vector_float3
  var minBounds: vector_float3
  init()
  init(maxBounds maxBounds: vector_float3, minBounds minBounds: vector_float3)
}
typealias MDLAxisAlignedBoundingBox = MDL_EXPORT_CPPCLASS
