//
//  IMPTestFilter.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa


class IMPTestFilter:IMPFilter {
    
    var sourceAnalayzer:IMPHistogramAnalyzer!
    var dominantAnalayzer:IMPHistogramAnalyzer!
    var colorAlizer:IMPColorWeightsAnalyzer!
    
    let dominantSolver = IMPHistogramDominantColorSolver()
    let rangeSolver = IMPHistogramRangeSolver()
    
    var wbFilter:IMPWBFilter!
    var contrastFilter:IMPContrastFilter!
    
    var hsvFilter:IMPHSVFilter!
    
    required init(context: IMPContext, histogramView:IMPView, histogramCDFView:IMPView) {
        
        super.init(context: context)
        
        addFunction(IMPFunction(context: self.context, name: IMPSTD_PASS_KERNEL))
        
        wbFilter = IMPWBFilter(context: self.context)
        hsvFilter = IMPHSVFilter(context: self.context, optimization:.HIGH)
        contrastFilter = IMPContrastFilter(context: self.context)        
        
        addFilter(contrastFilter)
        addFilter(wbFilter)
        addFilter(hsvFilter)

        dominantAnalayzer = IMPHistogramAnalyzer(context: self.context)
        dominantAnalayzer.addSolver(dominantSolver)
        
        sourceAnalayzer = IMPHistogramAnalyzer(context: self.context)
        sourceAnalayzer.addSolver(rangeSolver)
        
        colorAlizer = IMPColorWeightsAnalyzer(context: self.context)
        
        sourceAnalayzer.addUpdateObserver({ (histogram) -> Void in
            self.contrastFilter.adjustment.minimum = self.rangeSolver.minimum
            self.contrastFilter.adjustment.maximum = self.rangeSolver.maximum
        })
        
        dominantAnalayzer.addUpdateObserver { (histogram) -> Void in
            self.wbFilter.adjustment.dominantColor = self.dominantSolver.color
        }
        
        contrastFilter.addDestinationObserver { (destination) -> Void in
            self.dominantAnalayzer.source = destination
        }
        
        colorAlizer.addUpdateObserver { (histogram) -> Void in
            //print(" *** color weights = \(self.colorAlizer.solver.colorWeights, self.colorAlizer.solver.neutralWeights)")
        }
        
        addSourceObserver { (source) -> Void in
            self.sourceAnalayzer.source = source
        }
        
        addDestinationObserver { (destination) -> Void in
            histogramView.source = destination
            histogramCDFView.source = destination
            self.colorAlizer.source = destination
        }
    }
    
    required init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    var redraw: (()->Void)?
}
