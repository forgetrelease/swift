
class CTRubyAnnotation {
}
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationGetTypeID() -> CFTypeID
@available(tvOS 8.0, *)
enum CTRubyAlignment : UInt8 {
  init?(rawValue rawValue: UInt8)
  var rawValue: UInt8 { get }
  case invalid
  case auto
  case start
  case center
  case end
  case distributeLetter
  case distributeSpace
  case lineEdge
}
@available(tvOS 8.0, *)
enum CTRubyOverhang : UInt8 {
  init?(rawValue rawValue: UInt8)
  var rawValue: UInt8 { get }
  case invalid
  case auto
  case start
  case end
  case none
}
@available(tvOS 8.0, *)
enum CTRubyPosition : UInt8 {
  init?(rawValue rawValue: UInt8)
  var rawValue: UInt8 { get }
  case before
  case after
  case interCharacter
  case inline
  case count
}
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationCreate(_ alignment: CTRubyAlignment, _ overhang: CTRubyOverhang, _ sizeFactor: CGFloat, _ text: UnsafeMutablePointer<Unmanaged<CFString>>!) -> CTRubyAnnotation
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationCreateCopy(_ rubyAnnotation: CTRubyAnnotation) -> CTRubyAnnotation
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationGetAlignment(_ rubyAnnotation: CTRubyAnnotation) -> CTRubyAlignment
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationGetOverhang(_ rubyAnnotation: CTRubyAnnotation) -> CTRubyOverhang
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationGetSizeFactor(_ rubyAnnotation: CTRubyAnnotation) -> CGFloat
@available(tvOS 8.0, *)
@discardableResult
func CTRubyAnnotationGetTextForPosition(_ rubyAnnotation: CTRubyAnnotation, _ position: CTRubyPosition) -> CFString?
