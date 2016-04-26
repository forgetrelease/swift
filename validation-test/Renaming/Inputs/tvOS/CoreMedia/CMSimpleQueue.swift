
var kCMSimpleQueueError_AllocationFailed: OSStatus { get }
var kCMSimpleQueueError_RequiredParameterMissing: OSStatus { get }
var kCMSimpleQueueError_ParameterOutOfRange: OSStatus { get }
var kCMSimpleQueueError_QueueIsFull: OSStatus { get }
class CMSimpleQueue {
}
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueGetTypeID() -> CFTypeID
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueCreate(_ allocator: CFAllocator?, _ capacity: Int32, _ queueOut: UnsafeMutablePointer<CMSimpleQueue?>) -> OSStatus
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueEnqueue(_ queue: CMSimpleQueue, _ element: UnsafePointer<Void>) -> OSStatus
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueDequeue(_ queue: CMSimpleQueue) -> UnsafePointer<Void>?
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueGetHead(_ queue: CMSimpleQueue) -> UnsafePointer<Void>?
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueReset(_ queue: CMSimpleQueue) -> OSStatus
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueGetCapacity(_ queue: CMSimpleQueue) -> Int32
@available(tvOS 5.0, *)
@discardableResult
func CMSimpleQueueGetCount(_ queue: CMSimpleQueue) -> Int32
