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

public class IMPHistogramView: IMPView {
    
    public class histogramLayerFilter: IMPFilter {
        
        public var analayzer:IMPHistogramAnalyzer!{
            didSet{
                self.dirty = true
            }
        }
        
        public var solver:IMPHistogramLayerSolver!{
            didSet{
                self.dirty = true
            }
        }
        
        public required init(context: IMPContext) {
            
            super.init(context: context)
                        
            solver = IMPHistogramLayerSolver(context: self.context)
            
            self.addFilter(solver)
            
            analayzer = IMPHistogramAnalyzer(context: self.context)
            analayzer.addSolver(solver)
            
            self.addSourceObserver{ (source:IMPImageProvider) -> Void in
                self.analayzer.source = source
            }
        }
        
        private var view:IMPHistogramView?
        
        required convenience public init(context: IMPContext, view:IMPHistogramView) {
            self.init(context: context)
            self.view = view
        }
        
        override public func apply() {
            if let v = view{
                var size = MTLSize(cgsize: v.bounds.size)*(v.scaleFactor,v.scaleFactor,1)
                size.depth = 1
                solver.destinationSize = size
            }
            super.apply()
        }
    }
    
    private var _filter:histogramLayerFilter!
    override public var filter:IMPFilter?{
        set(newFiler){}
        get{ return _filter }
    }
    
    public var histogram:histogramLayerFilter{
        get{
            return _filter
        }
    }
    
    override init(context contextIn: IMPContext, frame: NSRect) {
        super.init(context: contextIn, frame: frame)
        _filter = histogramLayerFilter(context: self.context, view: self)
        _filter.addDirtyObserver { () -> Void in
            self.layerNeedUpdate = true
        }
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        _filter = histogramLayerFilter(context: self.context, view: self)
        _filter.addDirtyObserver { () -> Void in
            self.layerNeedUpdate = true
        }
    }
}
