
typealias CGBitmapContextReleaseDataCallback = @convention(c) (UnsafeMutablePointer<Void>?, UnsafeMutablePointer<Void>?) -> Void
extension CGContext {
  @available(tvOS 4.0, *)
  init?(bitmapWithData data: UnsafeMutablePointer<Void>?, width width: Int, height height: Int, bitsPerComponent bitsPerComponent: Int, bytesPerRow bytesPerRow: Int, space space: CGColorSpace?, bitmapInfo bitmapInfo: UInt32, releaseCallback releaseCallback: CGBitmapContextReleaseDataCallback?, releaseInfo releaseInfo: UnsafeMutablePointer<Void>?)
  @available(tvOS 2.0, *)
  init?(bitmapData data: UnsafeMutablePointer<Void>?, width width: Int, height height: Int, bitsPerComponent bitsPerComponent: Int, bytesPerRow bytesPerRow: Int, space space: CGColorSpace?, bitmapInfo bitmapInfo: UInt32)
  @available(tvOS 2.0, *)
  var bitmapData: UnsafeMutablePointer<Void>? { get }
  @available(tvOS 2.0, *)
  var bitmapWidth: Int { get }
  @available(tvOS 2.0, *)
  var bitmapHeight: Int { get }
  @available(tvOS 2.0, *)
  var bitmapBitsPerComponent: Int { get }
  @available(tvOS 2.0, *)
  var bitmapBitsPerPixel: Int { get }
  @available(tvOS 2.0, *)
  var bitmapBytesPerRow: Int { get }
  @available(tvOS 2.0, *)
  var bitmapColorSpace: CGColorSpace? { get }
  @available(tvOS 2.0, *)
  var bitmapAlphaInfo: CGImageAlphaInfo { get }
  @available(tvOS 2.0, *)
  var bitmapInfo: CGBitmapInfo { get }
  @available(tvOS 2.0, *)
  @discardableResult
  func makeImageFromBitmap() -> CGImage?
}
