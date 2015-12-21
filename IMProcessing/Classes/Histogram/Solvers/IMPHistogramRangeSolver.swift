//
//  IMPHistogramRangeSolver.swift
//  ImageMetalling-05
//
//  Created by denis svinarchuk on 01.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import simd

///
/// Солвер вычисляет диапазон интенсивностей для интересных нам условий клиппинга.
///
public class IMPHistogramRangeSolver: NSObject, IMPHistogramSolver {
    
    public struct clippingType {
        ///
        /// Клипинг теней (все тени, которые будут перекрыты растяжением), по умолчанию 0.1%
        ///
        var shadows:Float = 0.1/100.0
        ///
        /// Клипинг светов, по умолчанию 0.1%
        ///
        var highlights:Float = 0.1/100.0
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
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzer, histogram: IMPHistogram, imageSize: CGSize) {
        for i in 0..<histogram.channels.count{
            minimum[i] = histogram.low(channel: i, clipping: clipping.shadows)
            maximum[i] = histogram.high(channel: i, clipping: clipping.highlights)
        }
   }
}