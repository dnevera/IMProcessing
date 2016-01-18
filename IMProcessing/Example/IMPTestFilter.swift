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
    let rangeSolver = IMPHistogramRangeSolver()
    
    var contrastFilter:IMPContrastFilter!
    var awbFilter:IMPAutoWBFilter!
    var hsvFilter:IMPHSVFilter!
    
    var curveFilter:IMPCurvesFilter!
    
    //var blur:IMPIIRGaussianBlurFilter!
    var blur:IMPGaussianBlurFilter!
    
    required init(context: IMPContext, histogramView:IMPView, histogramCDFView:IMPView) {
        
        super.init(context: context)
        
        contrastFilter = IMPContrastFilter(context: self.context)
        awbFilter = IMPAutoWBFilter(context: self.context)
        hsvFilter = IMPHSVFilter(context: self.context, optimization:.NORMAL)
        curveFilter = IMPCurvesFilter(context: self.context)
        
        curveFilter.splines.compositeControls = [
            float2(0,0),
            float2(50,18),
            float2(128,128),
            float2(238,245),
            float2(255,255)
        ]
        
        //blur = IMPIIRGaussianBlurFilter(context: context)
        blur = IMPGaussianBlurFilter(context: context)

        addFilter(contrastFilter)
        addFilter(awbFilter)
        addFilter(hsvFilter)
        
        addFilter(curveFilter)
        addFilter(blur)
        
        sourceAnalayzer = IMPHistogramAnalyzer(context: self.context)
        sourceAnalayzer.addSolver(rangeSolver)
        
        sourceAnalayzer.addUpdateObserver({ (histogram) -> Void in
            self.contrastFilter.adjustment.minimum = self.rangeSolver.minimum
            self.contrastFilter.adjustment.maximum = self.rangeSolver.maximum
        })
        
        addSourceObserver { (source) -> Void in
            self.sourceAnalayzer.source = source
        }
        
        addDestinationObserver { (destination) -> Void in
            histogramView.source = destination
            histogramCDFView.source = destination
        }
    }
    
    required init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    var redraw: (()->Void)?
}
