//
//  IMPHistogramAverageSolver.swift
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
/// Солвер доминантного цвета изображения в пространстве RGB(Y)
/// Вычисляет среднее значение интенсивностей каждого канала по гистограмме этих каналов
///
public class IMPHistogramDominantColorSolver: NSObject, IMPHistogramSolver {
    
    ///
    /// Доминантный (средний) цвет изображения. Используем векторный тип float4 из фреймворка 
    /// для работы с векторными типа данных simd
    ///
    public var color=float4()
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzer, histogram: IMPHistogram, imageSize: CGSize) {
        for i in 0..<histogram.channels.count{
            color[i] = histogram.mean(channel: i)
        }
    }
}
