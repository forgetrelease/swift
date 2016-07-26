
typealias CGPDFContentStreamRef = OpaquePointer
@available(watchOS 2.0, *)
@discardableResult
func CGPDFContentStreamCreateWithPage(_ page: CGPDFPage!) -> CGPDFContentStreamRef!
@available(watchOS 2.0, *)
@discardableResult
func CGPDFContentStreamCreateWithStream(_ stream: CGPDFStreamRef!, _ streamResources: CGPDFDictionaryRef!, _ parent: CGPDFContentStreamRef!) -> CGPDFContentStreamRef!
@available(watchOS 2.0, *)
@discardableResult
func CGPDFContentStreamRetain(_ cs: CGPDFContentStreamRef!) -> CGPDFContentStreamRef!
@available(watchOS 2.0, *)
func CGPDFContentStreamRelease(_ cs: CGPDFContentStreamRef!)
@available(watchOS 2.0, *)
@discardableResult
func CGPDFContentStreamGetStreams(_ cs: CGPDFContentStreamRef!) -> CFArray!
@available(watchOS 2.0, *)
@discardableResult
func CGPDFContentStreamGetResource(_ cs: CGPDFContentStreamRef!, _ category: UnsafePointer<Int8>!, _ name: UnsafePointer<Int8>!) -> CGPDFObjectRef!
