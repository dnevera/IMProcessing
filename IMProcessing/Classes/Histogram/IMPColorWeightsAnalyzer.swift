//
//  IMPColorWeightsAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 21.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import Accelerate

public class  IMPColorWeightsSolver: NSObject, IMPHistogramSolver {
    
    public struct ColorWeights{
        
        public let count = 6
        
        public var reds:Float {
            return weights[0]
        }
        public var yellows:Float {
            return weights[1]
        }
        public var greens:Float {
            return weights[2]
        }
        public var cyans:Float {
            return weights[3]
        }
        public var blues:Float {
            return weights[4]
        }
        public var magentas:Float {
            return weights[5]
        }

        public subscript(index:Int)-> Float {
            return weights[index]
        }
        
        internal init(weights:[Float]){
            self.weights = weights
        }
        
        private var weights:[Float]
    }
    
    public struct NeutralWeights{
        
        public let saturated:Float
        public let blacks:Float
        public let whites:Float
        public let neutrals:Float
        
        internal init(weights:[Float]){
            saturated = weights[0]
            blacks = weights[1]
            whites = weights[2]
            neutrals = weights[3]
        }
    }

    private var _colorWeights   = ColorWeights(weights: [Float](count: 6, repeatedValue: 0))
    private var _neutralWeights = NeutralWeights(weights: [Float](count: 4, repeatedValue: 0))

    public var colorWeights:ColorWeights{
        get{
            return _colorWeights
        }
    }
    
    public var neutralWeights:NeutralWeights{
        get{
            return _neutralWeights
        }
    }
    
    private func normalize(inout A A:[Float]){
        var n:Float = 0
        let sz = vDSP_Length(A.count)
        vDSP_sve(&A, 1, &n, sz);
        if n != 0 {
            vDSP_vsdiv(&A, 1, &n, &A, 1, sz);
        }
    }
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize) {
        //
        // hues placed at start of channel W
        //
        var huesCircle = [Float](histogram[.W][0...5])

        //
        // normalize hues
        //
        normalize(A: &huesCircle)
        _colorWeights = ColorWeights(weights: huesCircle)
        
        //
        // weights of diferrent classes (neutral) brightness is placed at the and of channel W
        //
        var weights    = [Float](histogram[analizer.hardware == .GPU ? .W : .Z][252...255])
        
        //
        // normalize neutral weights
        //
        normalize(A: &weights)
        _neutralWeights = NeutralWeights(weights: weights)
    }
}

public class IMPColorWeightsAnalyzer: IMPHistogramAnalyzer {

    public static var defaultClipping = IMPColorWeightsClipping(white: 0.1, black: 0.1, saturation: 0.1)
    
    public var clipping:IMPColorWeightsClipping!{
        didSet{
            clippingBuffer = clippingBuffer ?? context.device.newBufferWithLength(sizeof(IMPColorWeightsClipping), options: .CPUCacheModeDefaultCache)
            if let b = clippingBuffer {
                memcpy(b.contents(), &clipping, b.length)
            }
            self.dirty = true
        }
    }
    
    public let solver = IMPColorWeightsSolver()
    
    private var clippingBuffer:MTLBuffer?
    
    public required init(context: IMPContext, hardware:IMPHistogramAnalyzer.Hardware) {
        
        var function = "kernel_impColorWeightsPartial"

        if hardware == .DSP {
            function = "kernel_impColorWeightsVImage"
        }
        else if context.hasFastAtomic() {
            function = "kernel_impColorWeightsAtomic"
        }

        super.init(context: context, function: function, hardware: hardware)
                
        super.addSolver(solver)
        
        defer{
            clipping = IMPColorWeightsAnalyzer.defaultClipping
        }
    }
    
    convenience required public init(context: IMPContext) {
        self.init(context: context, hardware: .GPU)
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        command.setBuffer(self.clippingBuffer, offset: 0, atIndex: 4)
    }
    
    override public func addSolver(solver: IMPHistogramSolver) {
        fatalError("IMPColorWeightsAnalyzer can't add new solver but internal")
    }
}
