
@available(iOS 4.0, *)
let kCVImageBufferCGColorSpaceKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferCleanApertureKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferCleanApertureWidthKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferCleanApertureHeightKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferCleanApertureHorizontalOffsetKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferCleanApertureVerticalOffsetKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferPreferredCleanApertureKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldCountKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldDetailKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldDetailTemporalTopFirst: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldDetailTemporalBottomFirst: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldDetailSpatialFirstLineEarly: CFString
@available(iOS 4.0, *)
let kCVImageBufferFieldDetailSpatialFirstLineLate: CFString
@available(iOS 4.0, *)
let kCVImageBufferPixelAspectRatioKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferPixelAspectRatioHorizontalSpacingKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferPixelAspectRatioVerticalSpacingKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferDisplayDimensionsKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferDisplayWidthKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferDisplayHeightKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferGammaLevelKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferICCProfileKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferYCbCrMatrixKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferYCbCrMatrix_ITU_R_709_2: CFString
@available(iOS 4.0, *)
let kCVImageBufferYCbCrMatrix_ITU_R_601_4: CFString
@available(iOS 4.0, *)
let kCVImageBufferYCbCrMatrix_SMPTE_240M_1995: CFString
@available(iOS 9.0, *)
let kCVImageBufferYCbCrMatrix_DCI_P3: CFString
@available(iOS 9.0, *)
let kCVImageBufferYCbCrMatrix_P3_D65: CFString
@available(iOS 9.0, *)
let kCVImageBufferYCbCrMatrix_ITU_R_2020: CFString
@available(iOS 4.0, *)
let kCVImageBufferColorPrimariesKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferColorPrimaries_ITU_R_709_2: CFString
@available(iOS 4.0, *)
let kCVImageBufferColorPrimaries_EBU_3213: CFString
@available(iOS 4.0, *)
let kCVImageBufferColorPrimaries_SMPTE_C: CFString
@available(iOS 6.0, *)
let kCVImageBufferColorPrimaries_P22: CFString
@available(iOS 9.0, *)
let kCVImageBufferColorPrimaries_DCI_P3: CFString
@available(iOS 9.0, *)
let kCVImageBufferColorPrimaries_P3_D65: CFString
@available(iOS 9.0, *)
let kCVImageBufferColorPrimaries_ITU_R_2020: CFString
@available(iOS 4.0, *)
let kCVImageBufferTransferFunctionKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferTransferFunction_ITU_R_709_2: CFString
@available(iOS 4.0, *)
let kCVImageBufferTransferFunction_SMPTE_240M_1995: CFString
@available(iOS 4.0, *)
let kCVImageBufferTransferFunction_UseGamma: CFString
@available(iOS 9.0, *)
let kCVImageBufferTransferFunction_ITU_R_2020: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocationTopFieldKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocationBottomFieldKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_Left: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_Center: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_TopLeft: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_Top: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_BottomLeft: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_Bottom: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaLocation_DV420: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaSubsamplingKey: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaSubsampling_420: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaSubsampling_422: CFString
@available(iOS 4.0, *)
let kCVImageBufferChromaSubsampling_411: CFString
@available(iOS 8.0, *)
let kCVImageBufferAlphaChannelIsOpaque: CFString
typealias CVImageBuffer = CVBuffer
@available(iOS 4.0, *)
@discardableResult
func CVImageBufferGetEncodedSize(_ imageBuffer: CVImageBuffer) -> CGSize
@available(iOS 4.0, *)
@discardableResult
func CVImageBufferGetDisplaySize(_ imageBuffer: CVImageBuffer) -> CGSize
@available(iOS 4.0, *)
@discardableResult
func CVImageBufferGetCleanRect(_ imageBuffer: CVImageBuffer) -> CGRect
@available(iOS 4.0, *)
@discardableResult
func CVImageBufferIsFlipped(_ imageBuffer: CVImageBuffer) -> Bool
