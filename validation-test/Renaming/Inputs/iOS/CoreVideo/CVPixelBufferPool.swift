
class CVPixelBufferPool {
}
@available(iOS 4.0, *)
let kCVPixelBufferPoolMinimumBufferCountKey: CFString
@available(iOS 4.0, *)
let kCVPixelBufferPoolMaximumBufferAgeKey: CFString
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolGetTypeID() -> CFTypeID
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolCreate(_ allocator: CFAllocator?, _ poolAttributes: CFDictionary?, _ pixelBufferAttributes: CFDictionary?, _ poolOut: UnsafeMutablePointer<CVPixelBufferPool?>) -> CVReturn
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolGetAttributes(_ pool: CVPixelBufferPool) -> Unmanaged<CFDictionary>?
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolGetPixelBufferAttributes(_ pool: CVPixelBufferPool) -> Unmanaged<CFDictionary>?
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolCreatePixelBuffer(_ allocator: CFAllocator?, _ pixelBufferPool: CVPixelBufferPool, _ pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn
@available(iOS 4.0, *)
@discardableResult
func CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(_ allocator: CFAllocator?, _ pixelBufferPool: CVPixelBufferPool, _ auxAttributes: CFDictionary?, _ pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn
@available(iOS 4.0, *)
let kCVPixelBufferPoolAllocationThresholdKey: CFString
@available(iOS 4.0, *)
let kCVPixelBufferPoolFreeBufferNotification: CFString
typealias CVPixelBufferPoolFlushFlags = CVOptionFlags
var kCVPixelBufferPoolFlushExcessBuffers: CVPixelBufferPoolFlushFlags { get }
func CVPixelBufferPoolFlush(_ pool: CVPixelBufferPool, _ options: CVPixelBufferPoolFlushFlags)
