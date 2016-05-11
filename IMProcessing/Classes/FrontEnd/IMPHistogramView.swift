 //
//  IMPHistogramView.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPHistogramView: IMPViewBase, IMPContextProvider {
    
    public var context: IMPContext!
        
    public init(frame: NSRect, context contextIn: IMPContext, histogramHardware:IMPHistogramAnalyzer.Hardware) {
        super.init(frame: frame)
        self.context = contextIn
        self.histogramHardware = histogramHardware 
        self.autoresizesSubviews = true
        addSubview(imageView)
    }

    public convenience init(context contextIn: IMPContext, frame: NSRect) {
        self.init(frame: frame, context: contextIn, histogramHardware: .GPU)          
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var imageView:IMPView = { 
        let v = IMPView(filter: self.generator,frame: self.bounds)
        v.autoresizesSubviews = true
        v.autoresizingMask = [.ViewHeightSizable, .ViewWidthSizable]
        v.backgroundColor = IMPColor.clearColor()
        return v
    }()
    
    var histogramHardware = IMPHistogramAnalyzer.Hardware.GPU
    
    lazy var analizer:IMPHistogramAnalyzer = { 
        let a = IMPHistogramAnalyzer(context: self.context, hardware: self.histogramHardware)
        a.addUpdateObserver({ (histogram) in
            self.generator.histogram = histogram.pdf()            
        })       
        return a
    }()
    
    lazy var generator:IMPHistogramGenerator = { 
        let f = IMPHistogramGenerator(context: self.context, size: IMPSize(width: self.bounds.width, height: self.bounds.height))          
        return f
    }()
    
    public var filter:IMPFilter?{
        set(newFiler){
            fatalError("IMPHistogramView does not allow set new filter...")
        }
        get{ return analizer }
    }
}