
class CGPDFPage {
}
enum CGPDFBox : Int32 {
  init?(rawValue rawValue: Int32)
  var rawValue: Int32 { get }
  case mediaBox
  case cropBox
  case bleedBox
  case trimBox
  case artBox
}
extension CGPDFPage {
  @available(iOS 2.0, *)
  var document: CGPDFDocument? { get }
  @available(iOS 2.0, *)
  var pageNumber: Int { get }
  @available(iOS 2.0, *)
  var boxRect: CGRect { get }
  @available(iOS 2.0, *)
  var rotationAngle: Int32 { get }
  @available(iOS 2.0, *)
  @discardableResult
  func getDrawingTransform(_ box: CGPDFBox, rect rect: CGRect, rotate rotate: Int32, preserveAspectRatio preserveAspectRatio: Bool) -> CGAffineTransform
  @available(iOS 2.0, *)
  var dictionary: CGPDFDictionaryRef? { get }
  @available(iOS 2.0, *)
  class var typeID: CFTypeID { get }
}
