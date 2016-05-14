//
//  IMPAutoWBFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 23.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

/// Should return opacity value
public typealias IMPAutoWBAnalyzeHandler =  ((solver:IMPColorWeightsSolver, opacity:Float, wbFilter:IMPWBFilter, hsvFilter:IMPHSVFilter) -> Float)

///  @brief AWB adjustment
public struct IMPAutoWBAdjustment{
    public var blending:IMPBlending    
    public init (blending: IMPBlending = IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)){
        self.blending = blending
    }
}

///
/// Auto white balance and color correction filer.
/// The main idea based on seeking a dominant color of the image and 
/// rearrange gamma of the image according to this dominant color. The image becames neutral-balanced.
///
public class IMPAutoWBFilter:IMPFilter{    
    
    public var analyzeDownScaleFactor:Float = 1 {
        didSet{
            colorWeightsAnalyzer.downScaleFactor = analyzeDownScaleFactor
            dominantColorAnalayzer.downScaleFactor = analyzeDownScaleFactor
            dirty = true
        }
    }
        
    ///  @brief Correction preferences
    public struct Preferences{
        /// Neutrals threshold
        /// In case when source analizer detects neutrals colors within area has weight greater then 25%
        /// AWB opacity becomes equal 0
        public var threshold  = Float(0.25)
        /// Clip whites and blacks regions
        public var clipping   = IMPColorWeightsClipping(white: 0.05, black: 0.1, saturation: 0.07)
        /// Color correction profile based in HSV
        public var hsvProfile = IMPHSVAdjustment(
            master: IMPHSVLevel.init(hue: 0, saturation: 0, value: 0),
            levels: (
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0),
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0), // descrease yellows in default AWB profile
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0),
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0),
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0),
                IMPHSVLevel(hue: 0, saturation:  0,     value: 0)),
            blending: IMPBlending.init(mode: IMPBlendingMode.NORMAL, opacity: 1))
    }

    /// AWB corrction preferences
    public var preferences:Preferences = Preferences() {
        didSet{
            colorWeightsAnalyzer.clipping = preferences.clipping
            self.dirty = true
        }
    }
    
    /// Default adjustment
    public static var defaultAdjustment = IMPAutoWBAdjustment(blending: IMPBlending.init(mode: IMPBlendingMode.NORMAL, opacity: 1))
    
    /// Current adjustment
    public var adjustment:IMPAutoWBAdjustment!{
        didSet{
            wbFilter.adjustment.blending = adjustment.blending
            hsvFilter.adjustment.blending = adjustment.blending
        }
    }
    
    /// Detected color weights
    public var colorWeights:IMPColorWeightsSolver.ColorWeights?{
        get{
            return colorWeightsAnalyzer.solver.colorWeights
        }
    }
    
    /// Detected neutral weights
    public var neutralWeights:IMPColorWeightsSolver.NeutralWeights?{
        get{
            return colorWeightsAnalyzer.solver.neutralWeights
        }
    }
    
    /// Detected dominant color
    public var dominantColor:float4?{
        get{
            return dominantColorSolver.color
        }
    }
    
    ///
    /// User defined color analyze extention.
    /// It can be used to redefine color correction prefrences at runtime
    ///
    public var colorsAnalyzeHandler:IMPAutoWBAnalyzeHandler?
    
    lazy var optimization:IMPHSVFilter.optimizationLevel = {
        return self.context.isLazy ? .HIGH : .NORMAL
    }()
    
    var histogramHardware = IMPHistogramAnalyzer.Hardware.GPU
    
    public required init(context: IMPContext,
                         optimization:IMPHSVFilter.optimizationLevel,
                         histogramHardware:IMPHistogramAnalyzer.Hardware
        ) {
        
        super.init(context: context)
        
        self.histogramHardware = histogramHardware
        self.optimization = optimization

        defer{
            adjustment = IMPAutoWBFilter.defaultAdjustment
        }
        
        addFilter(wbFilter)
        addFilter(hsvFilter)

        dominantColorAnalayzer.addSolver(dominantColorSolver)

        addSourceObserver { (source) -> Void in
            self.dominantColorAnalayzer.source = source
            self.colorWeightsAnalyzer.source = source
        }
        
        dominantColorAnalayzer.addUpdateObserver { (histogram) -> Void in
            self.wbFilter.adjustment.dominantColor = self.dominantColorSolver.color
        }

        colorWeightsAnalyzer.addUpdateObserver { (histogram) -> Void in
            let solver = self.colorWeightsAnalyzer.solver
            self.updateHsvProfile(solver)
        }
    }
    
    required public convenience init(context: IMPContext) {
        self.init(context:context, optimization: context.isLazy ? .HIGH : .NORMAL, histogramHardware: .GPU)
    }
    
    private func updateHsvProfile(solver:IMPColorWeightsSolver){
        
        var opacity:Float = 1
        
        if solver.neutralWeights.neutrals <= preferences.threshold {            
            //
            // squre of neutrals < preferensed value ~ 25% by default
            //
            opacity = adjustment.blending.opacity * ( preferences.threshold - solver.neutralWeights.neutrals) / preferences.threshold
        }
        else{
            //
            // do not apply awb if image has enough gray regions
            //
            opacity = 0;
        }
        
        
        if colorsAnalyzeHandler != nil {
            opacity = colorsAnalyzeHandler!(solver: solver, opacity:opacity, wbFilter: wbFilter, hsvFilter: hsvFilter)
        }
        
        //
        // apply final opacity
        //
        wbFilter.adjustment.blending.opacity = opacity
    }
    
    private let dominantColorSolver:IMPHistogramDominantColorSolver = IMPHistogramDominantColorSolver()
    private lazy var dominantColorAnalayzer:IMPHistogramAnalyzer = IMPHistogramAnalyzer(context: self.context, hardware: self.histogramHardware)
    
    private lazy var colorWeightsAnalyzer:IMPColorWeightsAnalyzer =  {
        let a = IMPColorWeightsAnalyzer(context: self.context, hardware: self.histogramHardware)
        a.clipping = self.preferences.clipping
        return a
    }()
    
    
    private lazy var hsvFilter:IMPHSVFilter = {
        let f = IMPHSVFilter(context: self.context, optimization: self.optimization)
        if self.optimization == .HIGH {
            f.rgbCubeSize = 16
        }
        return f
    }()
    private lazy var wbFilter:IMPWBFilter = IMPWBFilter(context: self.context)
    
}
 