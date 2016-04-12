//
//  IMPallete.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 31.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPPaletteView: IMPView {
    
    public class paletteLayerFilter: IMPFilter {
        
        public var analayzer:IMPHistogramCubeAnalyzer!{
            didSet{
                self.dirty = true
            }
        }
        
        public var solver:IMPPaletteLayerSolver!{
            didSet{
                self.dirty = true
            }
        }
        
        public required init(context: IMPContext) {
            
            super.init(context: context)
            
            solver = IMPPaletteLayerSolver(context: self.context)
            
            self.addFilter(solver)
            
            analayzer = IMPHistogramCubeAnalyzer(context: self.context)
            analayzer.addSolver(solver)
            
            self.addSourceObserver{ (source:IMPImageProvider) -> Void in
                self.analayzer.source = source
            }
        }
        
        private var view:IMPPaletteView?
        
        required convenience public init(context: IMPContext, view:IMPPaletteView) {
            self.init(context: context)
            self.view = view
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
    
    private var _filter:paletteLayerFilter!
    override public var filter:IMPFilter?{
        set(newFiler){}
        get{ return _filter }
    }
    
    public var palette:paletteLayerFilter{
        get{
            return _filter
        }
    }
    
    override init(context contextIn: IMPContext, frame: NSRect) {
        super.init(context: contextIn, frame: frame)
        _filter = paletteLayerFilter(context: self.context, view: self)
        _filter.addDestinationObserver { (destination) -> Void in
            self.layerNeedUpdate = true
        }
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        _filter = paletteLayerFilter(context: self.context, view: self)
        _filter.addDestinationObserver { (destination) -> Void in
            self.layerNeedUpdate = true
        }
    }
}
