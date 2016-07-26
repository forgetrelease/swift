
struct MKCoordinateSpan {
  var latitudeDelta: CLLocationDegrees
  var longitudeDelta: CLLocationDegrees
  init()
  init(latitudeDelta latitudeDelta: CLLocationDegrees, longitudeDelta longitudeDelta: CLLocationDegrees)
}
struct MKCoordinateRegion {
  var center: CLLocationCoordinate2D
  var span: MKCoordinateSpan
  init()
  init(center center: CLLocationCoordinate2D, span span: MKCoordinateSpan)
}
@discardableResult
func MKCoordinateSpanMake(_ latitudeDelta: CLLocationDegrees, _ longitudeDelta: CLLocationDegrees) -> MKCoordinateSpan
@discardableResult
func MKCoordinateRegionMake(_ centerCoordinate: CLLocationCoordinate2D, _ span: MKCoordinateSpan) -> MKCoordinateRegion
@available(tvOS 9.2, *)
@discardableResult
func MKCoordinateRegionMakeWithDistance(_ centerCoordinate: CLLocationCoordinate2D, _ latitudinalMeters: CLLocationDistance, _ longitudinalMeters: CLLocationDistance) -> MKCoordinateRegion
struct MKMapPoint {
  var x: Double
  var y: Double
  init()
  init(x x: Double, y y: Double)
}
struct MKMapSize {
  var width: Double
  var height: Double
  init()
  init(width width: Double, height height: Double)
}
struct MKMapRect {
  var origin: MKMapPoint
  var size: MKMapSize
  init()
  init(origin origin: MKMapPoint, size size: MKMapSize)
}
typealias MKZoomScale = CGFloat
@available(tvOS 9.2, *)
let MKMapSizeWorld: MKMapSize
@available(tvOS 9.2, *)
let MKMapRectWorld: MKMapRect
@available(tvOS 9.2, *)
@discardableResult
func MKMapPointForCoordinate(_ coordinate: CLLocationCoordinate2D) -> MKMapPoint
@available(tvOS 9.2, *)
@discardableResult
func MKCoordinateForMapPoint(_ mapPoint: MKMapPoint) -> CLLocationCoordinate2D
@available(tvOS 9.2, *)
@discardableResult
func MKMetersPerMapPointAtLatitude(_ latitude: CLLocationDegrees) -> CLLocationDistance
@available(tvOS 9.2, *)
@discardableResult
func MKMapPointsPerMeterAtLatitude(_ latitude: CLLocationDegrees) -> Double
@available(tvOS 9.2, *)
@discardableResult
func MKMetersBetweenMapPoints(_ a: MKMapPoint, _ b: MKMapPoint) -> CLLocationDistance
@available(tvOS 9.2, *)
let MKMapRectNull: MKMapRect
@discardableResult
func MKMapPointMake(_ x: Double, _ y: Double) -> MKMapPoint
@discardableResult
func MKMapSizeMake(_ width: Double, _ height: Double) -> MKMapSize
@discardableResult
func MKMapRectMake(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> MKMapRect
@discardableResult
func MKMapRectGetMinX(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetMinY(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetMidX(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetMidY(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetMaxX(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetMaxY(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetWidth(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapRectGetHeight(_ rect: MKMapRect) -> Double
@discardableResult
func MKMapPointEqualToPoint(_ point1: MKMapPoint, _ point2: MKMapPoint) -> Bool
@discardableResult
func MKMapSizeEqualToSize(_ size1: MKMapSize, _ size2: MKMapSize) -> Bool
@discardableResult
func MKMapRectEqualToRect(_ rect1: MKMapRect, _ rect2: MKMapRect) -> Bool
@discardableResult
func MKMapRectIsNull(_ rect: MKMapRect) -> Bool
@discardableResult
func MKMapRectIsEmpty(_ rect: MKMapRect) -> Bool
@discardableResult
func MKStringFromMapPoint(_ point: MKMapPoint) -> String
@discardableResult
func MKStringFromMapSize(_ size: MKMapSize) -> String
@discardableResult
func MKStringFromMapRect(_ rect: MKMapRect) -> String
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectUnion(_ rect1: MKMapRect, _ rect2: MKMapRect) -> MKMapRect
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectIntersection(_ rect1: MKMapRect, _ rect2: MKMapRect) -> MKMapRect
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectInset(_ rect: MKMapRect, _ dx: Double, _ dy: Double) -> MKMapRect
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectOffset(_ rect: MKMapRect, _ dx: Double, _ dy: Double) -> MKMapRect
@available(tvOS 9.2, *)
func MKMapRectDivide(_ rect: MKMapRect, _ slice: UnsafeMutablePointer<MKMapRect>, _ remainder: UnsafeMutablePointer<MKMapRect>, _ amount: Double, _ edge: CGRectEdge)
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectContainsPoint(_ rect: MKMapRect, _ point: MKMapPoint) -> Bool
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectContainsRect(_ rect1: MKMapRect, _ rect2: MKMapRect) -> Bool
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectIntersectsRect(_ rect1: MKMapRect, _ rect2: MKMapRect) -> Bool
@available(tvOS 9.2, *)
@discardableResult
func MKCoordinateRegionForMapRect(_ rect: MKMapRect) -> MKCoordinateRegion
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectSpans180thMeridian(_ rect: MKMapRect) -> Bool
@available(tvOS 9.2, *)
@discardableResult
func MKMapRectRemainder(_ rect: MKMapRect) -> MKMapRect
extension NSValue {
  @available(tvOS 9.2, *)
  /*not inherited*/ init(mkCoordinate coordinate: CLLocationCoordinate2D)
  @available(tvOS 9.2, *)
  /*not inherited*/ init(mkCoordinateSpan span: MKCoordinateSpan)
  @available(tvOS 9.2, *)
  var mkCoordinateValue: CLLocationCoordinate2D { get }
  @available(tvOS 9.2, *)
  var mkCoordinateSpanValue: MKCoordinateSpan { get }
}
