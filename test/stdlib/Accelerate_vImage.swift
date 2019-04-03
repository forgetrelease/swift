// RUN: %target-run-simple-swift
// REQUIRES: executable_test

// REQUIRES: objc_interop
// UNSUPPORTED: OS=watchos

import StdlibUnittest
import Accelerate

var Accelerate_vImageTests = TestSuite("Accelerate_vImage")

if #available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *) {
    let width = UInt(48)
    let height = UInt(12)
    let widthi = 48
    let heighti = 12
    
    //===----------------------------------------------------------------------===//
    //
    //  MARK: Converter
    //
    //===----------------------------------------------------------------------===//
    
    Accelerate_vImageTests.test("vImage/CVConverters") {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let cgFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                            bitsPerPixel: 32,
                                            colorSpace: colorSpace,
                                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                            renderingIntent: .defaultIntent)!
        
        let cvFormat = vImageCVImageFormat.make(format: .format32ABGR,
                                                matrix: kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4.pointee,
                                                chromaSiting: .center,
                                                colorSpace: colorSpace,
                                                alphaIsOpaqueHint: false)!
        
        let coreVideoToCoreGraphics = vImageConverter.make(sourceFormat: cvFormat,
                                                           destinationFormat: cgFormat,
                                                           flags: .printDiagnosticsToConsole)
        
        let coreGraphicsToCoreVideo = vImageConverter.make(sourceFormat: cgFormat,
                                                           destinationFormat: cvFormat,
                                                           flags: .printDiagnosticsToConsole)
        
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        let sourceCGBuffer = vImage_Buffer(cgImage: image)!
        var intermediateCVBuffer = vImage_Buffer(width: widthi, height: heighti, bitsPerPixel: 32)!
        var destinationCGBuffer = vImage_Buffer(width: widthi, height: heighti, bitsPerPixel: 32)!
        
        coreGraphicsToCoreVideo?.convert(source: sourceCGBuffer,
                                         destination: &intermediateCVBuffer)
        
        coreVideoToCoreGraphics?.convert(source: intermediateCVBuffer,
                                         destination: &destinationCGBuffer)
        
        let destinationPixels: [UInt8] = arrayFromBuffer(buffer: destinationCGBuffer,
                                                         count: pixels.count)
        
        expectEqual(destinationPixels, pixels)
        
        expectEqual(coreVideoToCoreGraphics?.destinationBuffers(colorSpace: colorSpace),
                    coreGraphicsToCoreVideo?.sourceBuffers(colorSpace: colorSpace))
        
        expectEqual(coreVideoToCoreGraphics?.sourceBuffers(colorSpace: colorSpace),
                    coreGraphicsToCoreVideo?.destinationBuffers(colorSpace: colorSpace))
    }
    
    Accelerate_vImageTests.test("vImage/BufferOrder") {
        let sourceFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                bitsPerPixel: 32,
                                                colorSpace: CGColorSpaceCreateDeviceCMYK(),
                                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                                renderingIntent: .defaultIntent)!
        
        let destinationFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                     bitsPerPixel: 24,
                                                     colorSpace: CGColorSpace(name: CGColorSpace.genericLab)!,
                                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                                     renderingIntent: .defaultIntent)!
        
        let converter = vImageConverter.make(sourceFormat: sourceFormat,
                                             destinationFormat: destinationFormat)
        
        let sBuffers = converter?.sourceBuffers(colorSpace: sourceFormat.colorSpace.takeRetainedValue())
        let dBuffers = converter?.destinationBuffers(colorSpace: destinationFormat.colorSpace.takeRetainedValue())
        
        expectEqual(sBuffers, [.coreGraphics])
        expectEqual(dBuffers, [.coreGraphics])
    }
    
    Accelerate_vImageTests.test("vImage/AnyToAnyError") {
        var error = kvImageNoError
        
        let format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: CGColorSpaceCreateDeviceCMYK(),
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                          renderingIntent: .defaultIntent)!
        
        _ = vImageConverter.make(sourceFormat: format,
                                 destinationFormat: format,
                                 error: &error,
                                 flags: .imageExtend)
        
        expectEqual(error, kvImageUnknownFlagsBit)
    }
    
    Accelerate_vImageTests.test("vImage/AnyToAny") {
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        let sourceFormat = vImage_CGImageFormat(cgImage: image)!
        
        let destinationFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                     bitsPerPixel: 32,
                                                     colorSpace: CGColorSpaceCreateDeviceCMYK(),
                                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                                     renderingIntent: .defaultIntent)!
        
        let sourceBuffer = vImage_Buffer(cgImage: image)!
        var destinationBuffer = vImage_Buffer(width: widthi, height: heighti,
                                              bitsPerPixel: 32)!
        
        // New API
        
        let converter = vImageConverter.make(sourceFormat: sourceFormat,
                                             destinationFormat: destinationFormat)
        
        converter?.convert(source: sourceBuffer,
                           destination: &destinationBuffer)
        
        let mustOperateOutOfPlace = converter!.mustOperateOutOfPlace(source: sourceBuffer,
                                                                     destination: destinationBuffer)
        
        // Legacy API
        
        var legacyDestinationBuffer = vImage_Buffer(width: widthi, height: heighti,
                                                    bitsPerPixel: 32)!
        
        var legacyConverter: vImageConverter?
        
        withUnsafePointer(to: destinationFormat) { dest in
            withUnsafePointer(to: sourceFormat) { src in
                legacyConverter = vImageConverter_CreateWithCGImageFormat(
                    src,
                    dest,
                    nil,
                    vImage_Flags(kvImageNoFlags),
                    nil)?.takeRetainedValue()
            }
        }
        
        _ = withUnsafePointer(to: sourceBuffer) { src in
            vImageConvert_AnyToAny(legacyConverter!,
                                   src,
                                   &legacyDestinationBuffer,
                                   nil,
                                   vImage_Flags(kvImageNoFlags))
        }
        
        var e = kvImageNoError
        withUnsafePointer(to: sourceBuffer) { src in
            withUnsafePointer(to: destinationBuffer) { dest in
                e = vImageConverter_MustOperateOutOfPlace(legacyConverter!,
                                                          src,
                                                          dest,
                                                          vImage_Flags(kvImageNoFlags))
            }
        }
        let legacyMustOperateOutOfPlace = e == kvImageOutOfPlaceOperationRequired
        
        // Compare results
        
        let destinationPixels: [UInt8] = arrayFromBuffer(buffer: destinationBuffer,
                                                         count: pixels.count)
        let legacyDestinationPixels: [UInt8] = arrayFromBuffer(buffer: legacyDestinationBuffer,
                                                               count: pixels.count)
        
        expectTrue(legacyDestinationPixels.elementsEqual(destinationPixels))
        
        expectEqual(converter?.sourceBufferCount, 1)
        expectEqual(converter?.destinationBufferCount, 1)
        expectEqual(legacyMustOperateOutOfPlace, mustOperateOutOfPlace)
        
        sourceBuffer.free()
        destinationBuffer.free()
        legacyDestinationBuffer.free()
    }
    
    //===----------------------------------------------------------------------===//
    //
    //  MARK: Buffer
    //
    //===----------------------------------------------------------------------===//
    
    Accelerate_vImageTests.test("vImage/IllegalSize") {
        var error = kvImageNoError
        
        let buffer = vImage_Buffer(width: -1, height: -1,
                                   bitsPerPixel: 32,
                                   error: &error)
        
        expectEqual(error, kvImageInvalidParameter)
        expectTrue(buffer == nil)
    }
    
    Accelerate_vImageTests.test("vImage/IllegalSize") {
        var error = kvImageNoError
        
        let buffer = vImage_Buffer(width: 99999999, height: 99999999,
                                   bitsPerPixel: 99999999,
                                   error: &error,
                                   flags: .noFlags)
        
        expectEqual(error, kvImageMemoryAllocationError)
        expectTrue(buffer == nil)
    }
    
    Accelerate_vImageTests.test("vImage/InitWithInvalidImageFormat") {
        let pixels: [UInt8] = (0 ..< width * height).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makePlanar8Image(from: pixels,
                                     width: width,
                                     height: height)!
        
        let format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGBitmapInfo(rawValue: 0))!
        
        var error = kvImageNoError
        
        let buffer = vImage_Buffer(cgImage: image,
                                   format: format,
                                   error: &error)
        
        expectEqual(error, kvImageInvalidImageFormat)
        expectTrue(buffer == nil)
        
        buffer?.free()
    }
    
    Accelerate_vImageTests.test("vImage/CreateCGImage") {
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        let buffer = vImage_Buffer(cgImage: image)!
        
        let format = vImage_CGImageFormat(cgImage: image)!
        
        let bufferImage = buffer.createCGImage(format: format)!
        
        let imagePixels = imageToPixels(image: image)
        let bufferImagePixels = imageToPixels(image: bufferImage)
        
        expectTrue(imagePixels.elementsEqual(bufferImagePixels))
        
        buffer.free()
    }
    
    Accelerate_vImageTests.test("vImage/Copy") {
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        let source = vImage_Buffer(cgImage: image)!
        
        var destination = vImage_Buffer(width: widthi, height: heighti,
                                        bitsPerPixel: 32)!
        
        _ = source.copy(destinationBuffer: &destination)
        
        let sourcePixels: [UInt8] = arrayFromBuffer(buffer: source,
                                                    count: pixels.count)
        let destinationPixels: [UInt8] = arrayFromBuffer(buffer: destination,
                                                         count: pixels.count)
        
        expectTrue(sourcePixels.elementsEqual(destinationPixels))
        
        source.free()
        destination.free()
    }
    
    Accelerate_vImageTests.test("vImage/InitializeWithFormat") {
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        let format = vImage_CGImageFormat(cgImage: image)!
        
        let buffer = vImage_Buffer(cgImage: image,
                                   format:  format)!
        
        let bufferPixels: [UInt8] = arrayFromBuffer(buffer: buffer,
                                                    count: pixels.count)
        
        expectTrue(bufferPixels.elementsEqual(pixels))
        expectEqual(buffer.rowBytes, Int(width) * 4)
        expectEqual(buffer.width, width)
        expectEqual(buffer.height, height)
        
        buffer.free()
    }
    
    Accelerate_vImageTests.test("vImage/Alignment") {
        // New API
        
        var alignment = vImage_Buffer.preferredAlignmentAndRowBytes(width: widthi,
                                                                    height: heighti,
                                                                    bitsPerPixel: 32)!
        
        // Legacy API
        
        var legacyBuffer = vImage_Buffer()
        let legacyAlignment = vImageBuffer_Init(&legacyBuffer,
                                                height, width,
                                                32,
                                                vImage_Flags(kvImageNoAllocate))
        
        expectEqual(alignment.alignment, legacyAlignment)
        expectEqual(alignment.rowBytes, legacyBuffer.rowBytes)
        
        legacyBuffer.free()
    }
    
    Accelerate_vImageTests.test("vImage/CreateBufferFromCGImage") {
        let pixels: [UInt8] = (0 ..< width * height * 4).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makeRGBA8888Image(from: pixels,
                                      width: width,
                                      height: height)!
        
        // New API
        
        let buffer = vImage_Buffer(cgImage: image)!
        
        // Legacy API
        
        let legacyBuffer: vImage_Buffer = {
            var format = vImage_CGImageFormat(cgImage: image)!
            
            var buffer = vImage_Buffer()
            
            vImageBuffer_InitWithCGImage(&buffer,
                                         &format,
                                         nil,
                                         image,
                                         vImage_Flags(kvImageNoFlags))
            
            return buffer
        }()
        
        let bufferPixels: [UInt8] = arrayFromBuffer(buffer: buffer,
                                                    count: pixels.count)
        
        let legacyBufferPixels: [UInt8] = arrayFromBuffer(buffer: legacyBuffer,
                                                          count: pixels.count)
        
        expectTrue(bufferPixels.elementsEqual(legacyBufferPixels))
        
        expectEqual(buffer.width, legacyBuffer.width)
        expectEqual(buffer.height, legacyBuffer.height)
        expectEqual(buffer.rowBytes, legacyBuffer.rowBytes)
        
        expectEqual(buffer.size, CGSize(width: Int(width),
                                        height: Int(height)))
        
        buffer.free()
        free(legacyBuffer.data)
    }
    
    //===----------------------------------------------------------------------===//
    //
    //  MARK: CVImageFormat
    //
    //===----------------------------------------------------------------------===//
    
    Accelerate_vImageTests.test("vImage/MakeFromPixelBuffer") {
        let pixelBuffer = makePixelBuffer(pixelFormat: kCVPixelFormatType_420YpCbCr8Planar)!
        
        let format = vImageCVImageFormat.make(buffer: pixelBuffer)!
        
        expectEqual(format.channels, [vImage.BufferType.luminance,
                                      vImage.BufferType.Cb,
                                      vImage.BufferType.Cr])
    }
    
    Accelerate_vImageTests.test("vImage/MakeFormat4444YpCbCrA8") {
        let format = vImageCVImageFormat.make(format: .format4444YpCbCrA8,
                                              matrix: kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2.pointee,
                                              chromaSiting: .center,
                                              colorSpace: CGColorSpaceCreateDeviceRGB(),
                                              alphaIsOpaqueHint: false)!
        
        // test alphaIsOpaqueHint
        
        expectEqual(format.alphaIsOpaqueHint, false)
        
        format.alphaIsOpaqueHint = true
        
        expectEqual(format.alphaIsOpaqueHint, true)
        
        // test colorSpace
        
        expectEqual(String(format.colorSpace!.name!), "kCGColorSpaceDeviceRGB")
        
        format.colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        
        expectEqual(String(format.colorSpace!.name!), "kCGColorSpaceExtendedLinearSRGB")
        
        // test channel names
        
        let channels = format.channels
        
        expectEqual(channels,
                    [vImage.BufferType.Cb,
                     vImage.BufferType.luminance,
                     vImage.BufferType.Cr,
                     vImage.BufferType.alpha])
        
        let description = format.channelDescription(bufferType: channels.first!)
        
        expectEqual(description?.min, 0)
        expectEqual(description?.max, 255)
        expectEqual(description?.full, 240)
        expectEqual(description?.zero, 128)
    }
    
    Accelerate_vImageTests.test("vImage/MakeFormat420YpCbCr8Planar") {
        let format = vImageCVImageFormat.make(format: .format420YpCbCr8Planar,
                                              matrix: kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2.pointee,
                                              chromaSiting: .center,
                                              colorSpace: CGColorSpaceCreateDeviceRGB(),
                                              alphaIsOpaqueHint: false)!
        
        // test chromaSiting
        
        expectEqual(format.chromaSiting, vImageCVImageFormat.ChromaSiting.center)
        
        format.chromaSiting = .dv420
        
        expectEqual(format.chromaSiting, vImageCVImageFormat.ChromaSiting.dv420)
        
        // test formatCode
        
        expectEqual(format.formatCode, "y420")
        
        // test channelCount
        
        expectEqual(format.channelCount, 3)
    }
    
    //===----------------------------------------------------------------------===//
    //
    //  MARK: CGImageFormat
    //
    //===----------------------------------------------------------------------===//
    
    Accelerate_vImageTests.test("vImage/CGImageFormatIllegalValues") {
        
        let formatOne = vImage_CGImageFormat(bitsPerComponent: -1,
                                          bitsPerPixel: 32,
                                          colorSpace: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        
        let formatTwo = vImage_CGImageFormat(bitsPerComponent: 8,
                                             bitsPerPixel: -1,
                                             colorSpace: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        
        expectTrue(formatOne == nil)
        expectTrue(formatTwo == nil)
    }
    
    Accelerate_vImageTests.test("vImage/CGImageFormatFromCGImage") {
        let pixels: [UInt8] = (0 ..< width * height).map { _ in
            return UInt8.random(in: 0 ..< 255)
        }
        
        let image = makePlanar8Image(from: pixels,
                                     width: width,
                                     height: height)!
        
        let format = vImage_CGImageFormat(cgImage: image)!
        
        let legacyFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                bitsPerPixel: 8,
                                                colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
                                                bitmapInfo: CGBitmapInfo(rawValue: 0),
                                                version: 0,
                                                decode: nil,
                                                renderingIntent: .defaultIntent)
        
        expectTrue(format == legacyFormat)
    }
    
    Accelerate_vImageTests.test("vImage/CGImageFormatLightweightInit") {
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        let format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: colorspace,
                                          bitmapInfo: bitmapInfo)!
        
        let legacyFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                bitsPerPixel: 32,
                                                colorSpace: Unmanaged.passRetained(colorspace),
                                                bitmapInfo: bitmapInfo,
                                                version: 0,
                                                decode: nil,
                                                renderingIntent: renderingIntent)
        
        expectTrue(format == legacyFormat)
        expectTrue(format.componentCount == 4)
    }

    //===----------------------------------------------------------------------===//
    //
    //  MARK: Helper Functions
    //
    //===----------------------------------------------------------------------===//
    
    func makePixelBuffer(pixelFormat: OSType) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(kCFAllocatorDefault,
                            1,
                            1,
                            pixelFormat,
                            [:] as CFDictionary?,
                            &pixelBuffer)
        
        return pixelBuffer
    }
    
    func arrayFromBuffer<T>(buffer: vImage_Buffer, count: Int) -> Array<T> {
        let ptr = buffer.data.bindMemory(to: T.self, capacity: count)
        let buf = UnsafeBufferPointer(start: ptr, count: count)
        return Array(buf)
    }
    
    func imageToPixels(image: CGImage) -> [UInt8] {
        let pixelCount = image.width * image.height
        
        let pixelData = image.dataProvider?.data
        let pixels: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let buf = UnsafeBufferPointer(start: pixels, count: pixelCount)
        return Array(buf)
    }
    
    func makePlanar8Image(from pixels: [UInt8],
                          width: UInt,
                          height: UInt) -> CGImage? {
        
        if
            let outputData = CFDataCreate(nil, pixels, pixels.count),
            let cgDataProvider = CGDataProvider(data: outputData) {
            
            return CGImage(width: Int(width),
                           height: Int(height),
                           bitsPerComponent: 8,
                           bitsPerPixel: 8,
                           bytesPerRow: Int(width),
                           space: CGColorSpaceCreateDeviceGray(),
                           bitmapInfo: CGBitmapInfo(rawValue: 0),
                           provider: cgDataProvider,
                           decode: nil,
                           shouldInterpolate: false,
                           intent: CGColorRenderingIntent.defaultIntent)
            
        }
        return nil
    }
    
    func makeRGBA8888Image(from pixels: [UInt8],
                           width: UInt,
                           height: UInt) -> CGImage? {
        
        if
            let outputData = CFDataCreate(nil, pixels, pixels.count),
            let cgDataProvider = CGDataProvider(data: outputData) {
            
            return CGImage(width: Int(width),
                           height: Int(height),
                           bitsPerComponent: 8,
                           bitsPerPixel: 8 * 4,
                           bytesPerRow: Int(width) * 4,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                           provider: cgDataProvider,
                           decode: nil,
                           shouldInterpolate: false,
                           intent: CGColorRenderingIntent.defaultIntent)
            
        }
        return nil
    }
}
runAllTests()
