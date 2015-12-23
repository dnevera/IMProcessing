//
//  IMPAutoWBFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 23.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Cocoa

public struct IMPAutoWBAdjustment{
    var blending = IMPBlending.init(mode: IMPBlendingMode.NORMAL, opacity: 1)
}


public struct IMPAutoWBPreferences{
    var threshold  = Float(0.25)
    var clipping   = IMPColorWeightsClipping(white: 0.05, black: 0.1, saturation: 0.07)
    var hsvProfile = IMPHSVAdjustment(
        master: IMPHSVLevel.init(hue: 0, saturation: 0, value: 0),
        levels: (
            IMPHSVLevel(hue: 0, saturation: 0,     value: 0),
            IMPHSVLevel(hue: 0, saturation: -0.25, value: 0), // descrease yellow only in default AWB profile
            IMPHSVLevel(hue: 0, saturation: 0,     value: 0),
            IMPHSVLevel(hue: 0, saturation: 0,     value: 0),
            IMPHSVLevel(hue: 0, saturation: 0,     value: 0),
            IMPHSVLevel(hue: 0, saturation: 0,     value: 0)),
        blending: IMPBlending.init(mode: IMPBlendingMode.NORMAL, opacity: 1))
}

public class IMPAutoWBFilter:IMPFilter{
    
    public var preferences = IMPAutoWBPreferences() {
        didSet{
            colorWeightsAnalyzer.clipping = preferences.clipping
            self.dirty = true
        }
    }
    
    public var adjustment = IMPAutoWBAdjustment() {
        didSet{
            wbFilter.adjustment.blending = adjustment.blending
            hsvFilter.adjustment.blending = adjustment.blending
        }
    }
    
    public var colorWeights:IMPColorWeightsSolver.ColorWeights?{
        get{
            return colorWeightsAnalyzer.solver.colorWeights
        }
    }
    
    public var neutralWeights:IMPColorWeightsSolver.NeutralWeights?{
        get{
            return colorWeightsAnalyzer.solver.neutralWeights
        }
    }
    
    public var dominantColor:float4?{
        get{
            return dominantColorSolver.color
        }
    }
    
    public required init(context: IMPContext, optimization:IMPHSVFilter.optimizationLevel) {
        super.init(context: context)
        
        wbFilter = IMPWBFilter(context: context)
        self.addFilter(wbFilter)
        
        hsvFilter = IMPHSVFilter(context: context, optimization: optimization)
        self.addFilter(hsvFilter)
        
        dominantColorAnalayzer = IMPHistogramAnalyzer(context: context)
        dominantColorAnalayzer.addSolver(dominantColorSolver)
        
        colorWeightsAnalyzer = IMPColorWeightsAnalyzer(context: context)
        colorWeightsAnalyzer.clipping = preferences.clipping
        
        addSourceObserver { (source) -> Void in
            self.dominantColorAnalayzer.source = source
        }
        
        wbFilter.addDestinationObserver(destination: { (destination) -> Void in
            self.colorWeightsAnalyzer.source = destination
        })
        
        dominantColorAnalayzer.addUpdateObserver { (histogram) -> Void in
            self.wbFilter.adjustment.dominantColor = self.dominantColorSolver.color
        }
        
        colorWeightsAnalyzer.addUpdateObserver { (histogram) -> Void in
            let solver = self.colorWeightsAnalyzer.solver
            self.updateHsvProfile(solver)
        }
    }
    
    required public convenience init(context: IMPContext) {
        self.init(context:context, optimization:.NORMAL)
    }
    
    private func updateHsvProfile(solver:IMPColorWeightsSolver){
        
        if solver.neutralWeights.neutrals <= preferences.threshold {
            //
            // squre of neutrals < preferensed value ~ 25% by default
            //
            wbFilter.adjustment.blending.opacity = adjustment.blending.opacity * ( preferences.threshold - solver.neutralWeights.neutrals) / preferences.threshold
        }
        
        let hue = (dominantColor?.rgb.rgb_2_HSV().hue)! * 360
        
        var reds_yellows_weights =
        hue.overlapWeight(ramp: IMProcessing.hsv.reds, overlap: 1) +
            hue.overlapWeight(ramp: IMProcessing.hsv.yellows, overlap: 1)
        
        let other_colors = solver.colorWeights.cyans +
            solver.colorWeights.greens +
            solver.colorWeights.blues +
            solver.colorWeights.magentas
        
        if (other_colors < 0.03 /* 10% */) {
            reds_yellows_weights = 0.0; // it is a yellow/red image
        }
        
        //
        // descrease yellows
        //
        hsvFilter.adjustment.yellows = preferences.hsvProfile.yellows * reds_yellows_weights
    }
    
    private let dominantColorSolver = IMPHistogramDominantColorSolver()
    
    private var dominantColorAnalayzer:IMPHistogramAnalyzer!
    private var colorWeightsAnalyzer:IMPColorWeightsAnalyzer!
    
    private var hsvFilter:IMPHSVFilter!
    private var wbFilter:IMPWBFilter!
    
}
 