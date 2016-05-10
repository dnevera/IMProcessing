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
        
        public var histogram:IMPHistogram?{
            set{
                solver.histogram = histogram
            }
            get{
                return solver.histogram
            }
        }
        
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
        
        public required init(context: IMPContext, histogramHardware:IMPHistogramAnalyzer.Hardware = .GPU) {
            
            super.init(context: context)
                        
            solver = IMPHistogramLayerSolver(context: self.context)
            
            self.addFilter(solver)
            
            analayzer = IMPHistogramAnalyzer(context: self.context, hardware: histogramHardware)
            analayzer.addSolver(solver)
            
            self.addSourceObserver{ (source:IMPImageProvider) -> Void in
                self.analayzer.source = source
            }
        }
        
        private var view:IMPHistogramView?
        
        required convenience public init(context: IMPContext, view:IMPHistogramView, histogramHardware:IMPHistogramAnalyzer.Hardware = .GPU) {
            self.init(context: context, histogramHardware: histogramHardware)
            self.view = view
        }
        
        required public convenience init(context: IMPContext) {
            self.init(context: context, histogramHardware: .GPU)
        }
        
        override public func apply() -> IMPImageProvider {
            if let v = view{
                var size = MTLSize(cgsize: v.bounds.size)*(v.scaleFactor,v.scaleFactor,1)
                size.depth = 1
                solver.destinationSize = size
            }
            return super.apply()
        }
    }
    
//    override public var source:IMPImageProvider?{
//        didSet{
//            _filter.source = source
//            _filter.apply()
//        }
//    }
    
    private var _filter:histogramLayerFilter! {
        didSet{
            _filter.addDestinationObserver { (destination) -> Void in
                //self.currentDestination = destination
                self.layerNeedUpdate = true
            }
            
            _filter.addNewSourceObserver { (source) in
                self._filter.apply()
            }
        }
    }
    override public var filter:IMPFilter?{
        set(newFiler){
            fatalError("IMPHistogramView does not allow set new filter...")
        }
        get{ return _filter }
    }
    
    public var histogramLayer:histogramLayerFilter{
        get{
            return filter as! histogramLayerFilter
        }
    }
    
    public init(context contextIn: IMPContext, frame: NSRect, histogramHardware:IMPHistogramAnalyzer.Hardware) {
        super.init(context: contextIn, frame: frame)
        defer{
            _filter = histogramLayerFilter(context: self.context, view: self, histogramHardware: histogramHardware)
        }
    }

    override public convenience init(context contextIn: IMPContext, frame: NSRect) {
        self.init(context: contextIn, frame: frame, histogramHardware: .GPU)
    }

    convenience  public init(context contextIn: IMPContext) {
        self.init(context: contextIn, frame: CGRectZero)
        defer{
            _filter = histogramLayerFilter(context: self.context, view: self)
        }
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        defer{
            _filter = histogramLayerFilter(context: self.context, view: self)
        }
    }
}
