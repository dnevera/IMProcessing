//
//  IMPHistogramRangeSolver.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 01.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import simd

///
/// Солвер вычисляет диапазон интенсивностей для интересных нам условий клиппинга.
///
public class IMPHistogramRangeSolver: NSObject, IMPHistogramSolver {
    
    public struct clippingType {
        ///
        /// Клипинг теней (все тени, которые будут перекрыты растяжением), по умолчанию 0.1%
        ///
        public var shadows:Float = 0.1/100.0
        ///
        /// Клипинг светов, по умолчанию 0.1%
        ///
        public var highlights:Float = 0.1/100.0
    }
    
    public var clipping = clippingType()
    
    ///
    /// Минимальная интенсивность в пространстве RGB(Y)
    ///
    public var minimum = float4()
    ///
    /// Максимальная интенсивность в пространстве RGB(Y)
    ///
    public var maximum = float4()
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize) {
        for i in 0..<histogram.channels.count{
            let index = IMPHistogram.ChannelNo(rawValue: i)!
            minimum[i] = histogram.low(channel: index, clipping: clipping.shadows)
            maximum[i] = histogram.high(channel: index, clipping: clipping.highlights)
        }
   }
}