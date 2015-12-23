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

public class IMPAutoWBFilter:IMPFilter{
    
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
        
        addSourceObserver { (source) -> Void in
            self.dominantColorAnalayzer.source = source
        }
        
        wbFilter.addDestinationObserver(destination: { (destination) -> Void in
            self.colorWeightsAnalyzer.source = destination
        })
        
        dominantColorAnalayzer.addUpdateObserver { (histogram) -> Void in
            self.wbFilter.adjustment.dominantColor = self.dominantColorSolver.color
            print(" *** dominant color: \(self.wbFilter.adjustment.dominantColor)")
        }
        
        colorWeightsAnalyzer.addUpdateObserver { (histogram) -> Void in
            let solver = self.colorWeightsAnalyzer.solver
            print(" *** color weights = \(solver.colorWeights, solver.neutralWeights)")
        }
    }

    required public convenience init(context: IMPContext) {
        self.init(context:context, optimization:.NORMAL)
    }
    
    private let dominantColorSolver = IMPHistogramDominantColorSolver()
    
    private var dominantColorAnalayzer:IMPHistogramAnalyzer!
    private var colorWeightsAnalyzer:IMPColorWeightsAnalyzer!
    
    private var hsvFilter:IMPHSVFilter!
    private var wbFilter:IMPWBFilter!
    
}
 