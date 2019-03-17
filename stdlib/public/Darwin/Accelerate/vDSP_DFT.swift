//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Accelerate

//===----------------------------------------------------------------------===//
//
//  Discrete Fourier Transform
//
//===----------------------------------------------------------------------===//

extension vDSP {
    
    /// An enumeration that specifies whether to perform complex-to-complex or
    /// complex-to-real discrete Fourier transform.
    public enum DFTTransformType {
        /// Specifies complex-to-complex discrete Fourier transform, forward
        /// or inverse
        case complexComplex
        
        /// Specifies real-to-complex (forward) or complex-to-real (inverse)
        /// discrete Fourier transform.
        case complexReal
    }
    
    /// A class that provides single- and double-precision discrete Fourier transform.
    @available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
    public class DFT <T: vDSP_FloatingPointDiscreteFourierTransformable> {
        fileprivate let dftSetup: vDSP_DFT_Setup
        
        /// Initializes a new discrete Fourier transform structure.
        ///
        /// - Parameter previous: a previous vDSP_DFT instance to share data with.
        /// - Parameter count: the number of real elements to be transformed.
        /// - Parameter direction: Specifies the transform direction.
        /// - Parameter transformType: Specficies whether to forward transform is real-to-complex or complex-to-complex.
        public init?(previous: DFT? = nil,
                     count: Int,
                     direction: vDSP.FourierTransformDirection,
                     transformType: DFTTransformType,
                     ofType: T.Type) {
            
            guard let setup = T.DFTFunctions.makeDFTSetup(previous: previous,
                                                          count: count,
                                                          direction: direction,
                                                          transformType: transformType) else {
                                                            return nil
            }
            
            dftSetup = setup
        }
        
        /// Computes an out-of-place single-precision real discrete Fourier transform.
        ///
        /// - Parameter inputReal: Input vector - real part.
        /// - Parameter inputImaginary: Input vector - imaginary part.
        /// - Parameter outputReal: Output vector - real part.
        /// - Parameter outputImaginary: Output vector - imaginary part.
        ///
        /// When the `transformType` is `complexComplex`, each array (Ir, Ii,
        /// Or, and Oi) must have `count` elements.
        ///
        /// When the `transformType` is `complexReal`, each array (Ir, Ii,
        /// Or, and Oi) must have `count/2` elements.
        public func transform<U, V>(inputReal: U,
                                    inputImaginary: U,
                                    outputReal: inout V,
                                    outputImaginary: inout V)
            where
            U: _ContiguousCollection,
            V: _MutableContiguousCollection,
            U.Element == T, V.Element == T {
                
                T.DFTFunctions.transform(dftSetup: dftSetup,
                                         inputReal: inputReal,
                                         inputImaginary: inputImaginary,
                                         outputReal: &outputReal,
                                         outputImaginary: &outputImaginary)
        }
        
        deinit {
            T.DFTFunctions.destroySetup(dftSetup)
        }
    }
}

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
public protocol vDSP_FloatingPointDiscreteFourierTransformable: BinaryFloatingPoint {
    associatedtype DFTFunctions: vDSP_DFTFunctions where DFTFunctions.Scalar == Self
}

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
extension Float: vDSP_FloatingPointDiscreteFourierTransformable {
    public typealias DFTFunctions = vDSP.VectorizableFloat
}

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
extension Double: vDSP_FloatingPointDiscreteFourierTransformable {
    public typealias DFTFunctions = vDSP.VectorizableDouble
}

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
public protocol vDSP_DFTFunctions {
    associatedtype Scalar
    
    @inline(__always)
    static func makeDFTSetup<T>(previous: vDSP.DFT<T>?,
                                count: Int,
                                direction: vDSP.FourierTransformDirection,
                                transformType: vDSP.DFTTransformType) -> OpaquePointer?
    
    @inline(__always)
    static func transform<U, V>(dftSetup: OpaquePointer,
                                inputReal: U,
                                inputImaginary: U,
                                outputReal: inout V,
                                outputImaginary: inout V)
        where
        U: _ContiguousCollection,
        V: _MutableContiguousCollection,
        U.Element == Scalar, V.Element == Scalar
    
    @inline(__always)
    static func destroySetup(_ setup: OpaquePointer)
}

//===----------------------------------------------------------------------===//
//
//  Type-specific DFT function implementations
//
//===----------------------------------------------------------------------===//

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
extension vDSP.VectorizableFloat: vDSP_DFTFunctions {
    
    /// Returns a setup structure to perform a discrete Fourier transform
    @inline(__always)
    public static func makeDFTSetup<T>(previous: vDSP.DFT<T>? = nil,
                                       count: Int,
                                       direction: vDSP.FourierTransformDirection,
                                       transformType: vDSP.DFTTransformType) -> OpaquePointer?
        where T : vDSP_FloatingPointDiscreteFourierTransformable {
            
            switch transformType {
            case .complexComplex:
                return vDSP_DFT_zop_CreateSetup(previous?.dftSetup,
                                                vDSP_Length(count),
                                                direction.dftDirection)
            case .complexReal:
                return vDSP_DFT_zrop_CreateSetup(previous?.dftSetup,
                                                 vDSP_Length(count),
                                                 direction.dftDirection)
            }
    }
    
    /// Computes an out-of-place single-precision real discrete Fourier transform.
    ///
    /// - Parameter dftSetup: A DCT setup object.
    /// - Parameter inputReal: Input vector - real part.
    /// - Parameter inputImaginary: Input vector - imaginary part.
    /// - Parameter outputReal: Output vector - real part.
    /// - Parameter outputImaginary: Output vector - imaginary part.
    @inline(__always)
    public static func transform<U, V>(dftSetup: OpaquePointer,
                                       inputReal: U,
                                       inputImaginary: U,
                                       outputReal: inout V,
                                       outputImaginary: inout V)
        where
        U : _ContiguousCollection,
        V : _MutableContiguousCollection,
        U.Element == Float, V.Element == Float {
            
            inputReal.withUnsafeBufferPointer { Ir in
                inputImaginary.withUnsafeBufferPointer { Ii in
                    outputReal.withUnsafeMutableBufferPointer { Or in
                        outputImaginary.withUnsafeMutableBufferPointer { Oi in
                            
                            vDSP_DFT_Execute(dftSetup,
                                             Ir.baseAddress!,
                                             Ii.baseAddress!,
                                             Or.baseAddress!,
                                             Oi.baseAddress!)
                        }
                    }
                }
            }
    }
    
    /// Releases a DFT setup object.
    @inline(__always)
    public static func destroySetup(_ setup: OpaquePointer) {
        vDSP_DFT_DestroySetup(setup)
    }
}

@available(iOS 9999, OSX 9999, tvOS 9999, watchOS 9999, *)
extension vDSP.VectorizableDouble: vDSP_DFTFunctions {
    
    /// Returns a data structure for use with to perform a discrete Fourier transform
    @inline(__always)
    public static func makeDFTSetup<T>(previous: vDSP.DFT<T>? = nil,
                                       count: Int,
                                       direction: vDSP.FourierTransformDirection,
                                       transformType: vDSP.DFTTransformType) -> OpaquePointer?
        where T : vDSP_FloatingPointDiscreteFourierTransformable {
            
            switch transformType {
            case .complexComplex:
                return vDSP_DFT_zop_CreateSetupD(previous?.dftSetup,
                                                 vDSP_Length(count),
                                                 direction.dftDirection)
            case .complexReal:
                return vDSP_DFT_zrop_CreateSetupD(previous?.dftSetup,
                                                  vDSP_Length(count),
                                                  direction.dftDirection)
            }
    }
    
    /// Computes an out-of-place single-precision real discrete Fourier transform.
    ///
    /// - Parameter dftSetup: A DCT setup object.
    /// - Parameter inputReal: Input vector - real part.
    /// - Parameter inputImaginary: Input vector - imaginary part.
    /// - Parameter outputReal: Output vector - real part.
    /// - Parameter outputImaginary: Output vector - imaginary part.
    @inline(__always)
    public static func transform<U, V>(dftSetup: OpaquePointer,
                                       inputReal: U, inputImaginary: U,
                                       outputReal: inout V, outputImaginary: inout V)
        where
        U : _ContiguousCollection,
        V : _MutableContiguousCollection,
        U.Element == Double, V.Element == Double {
            
            inputReal.withUnsafeBufferPointer { Ir in
                inputImaginary.withUnsafeBufferPointer { Ii in
                    outputReal.withUnsafeMutableBufferPointer { Or in
                        outputImaginary.withUnsafeMutableBufferPointer { Oi in
                            
                            vDSP_DFT_ExecuteD(dftSetup,
                                              Ir.baseAddress!,
                                              Ii.baseAddress!,
                                              Or.baseAddress!,
                                              Oi.baseAddress!)
                        }
                    }
                }
            }
    }
    
    /// Releases a DFT setup object.
    @inline(__always)
    public static func destroySetup(_ setup: OpaquePointer) {
        vDSP_DFT_DestroySetupD(setup)
    }
}


