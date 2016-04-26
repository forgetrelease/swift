
@discardableResult
func UIGraphicsGetCurrentContext() -> CGContext?
func UIGraphicsPushContext(_ context: CGContext)
func UIGraphicsPopContext()
func UIRectFillUsingBlendMode(_ rect: CGRect, _ blendMode: CGBlendMode)
func UIRectFill(_ rect: CGRect)
func UIRectFrameUsingBlendMode(_ rect: CGRect, _ blendMode: CGBlendMode)
func UIRectFrame(_ rect: CGRect)
func UIRectClip(_ rect: CGRect)
func UIGraphicsBeginImageContext(_ size: CGSize)
@available(tvOS 4.0, *)
func UIGraphicsBeginImageContextWithOptions(_ size: CGSize, _ opaque: Bool, _ scale: CGFloat)
@discardableResult
func UIGraphicsGetImageFromCurrentImageContext() -> UIImage!
func UIGraphicsEndImageContext()
@available(tvOS 3.2, *)
@discardableResult
func UIGraphicsBeginPDFContextToFile(_ path: String, _ bounds: CGRect, _ documentInfo: [NSObject : AnyObject]?) -> Bool
@available(tvOS 3.2, *)
func UIGraphicsBeginPDFContextToData(_ data: NSMutableData, _ bounds: CGRect, _ documentInfo: [NSObject : AnyObject]?)
@available(tvOS 3.2, *)
func UIGraphicsEndPDFContext()
@available(tvOS 3.2, *)
func UIGraphicsBeginPDFPage()
@available(tvOS 3.2, *)
func UIGraphicsBeginPDFPageWithInfo(_ bounds: CGRect, _ pageInfo: [NSObject : AnyObject]?)
@available(tvOS 3.2, *)
@discardableResult
func UIGraphicsGetPDFContextBounds() -> CGRect
@available(tvOS 3.2, *)
func UIGraphicsSetPDFContextURLForRect(_ url: NSURL, _ rect: CGRect)
@available(tvOS 3.2, *)
func UIGraphicsAddPDFContextDestinationAtPoint(_ name: String, _ point: CGPoint)
@available(tvOS 3.2, *)
func UIGraphicsSetPDFContextDestinationForRect(_ name: String, _ rect: CGRect)
