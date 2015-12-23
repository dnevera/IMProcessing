//
//  IMPColorWeightsAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 21.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Cocoa
import Accelerate

public class  IMPColorWeightsSolver: NSObject, IMPHistogramSolver {

    public struct ColorWeights{
        
        let reds:Float
        let yellows:Float
        let greens:Float
        let cyans:Float
        let blues:Float
        let magentas:Float
        
        internal init(weights:[Float]){
            reds = weights[0]
            yellows = weights[1]
            greens = weights[2]
            cyans = weights[3]
            blues = weights[4]
            magentas = weights[5]
        }        
    }
    
    public struct NeutralWeights{
        let saturated:Float
        let blacks:Float
        let whites:Float
        let neutrals:Float
        
        internal init(weights:[Float]){
            saturated = weights[0]
            blacks = weights[1]
            whites = weights[2]
            neutrals = weights[3]
        }
    }

    private var _colorWeights = ColorWeights(weights: [Float](count: 6, repeatedValue: 0))
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
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzer, histogram: IMPHistogram, imageSize: CGSize) {
        //
        // hues placed at start of channel W
        //
        var huesCircle = [Float](histogram.channels[3][0...5])

        //
        // normalize hues
        //
        normalize(A: &huesCircle)
        _colorWeights = ColorWeights(weights: huesCircle)
        
        //
        // weights of diferrent classes (neutral) brightness is placed at the and of channel W
        //
        var weights    = [Float](histogram.channels[3][252...255])
        
        //
        // normalize neutral weights
        //
        normalize(A: &weights)
        _neutralWeights = NeutralWeights(weights: weights)
    }
}

public class IMPColorWeightsAnalyzer: IMPHistogramAnalyzer {

    public static var defaultClipping = IMPColorWeightsClipping(saturation: 0.1, black: 0.1, white: 0.1)
    
    public var clipping:IMPColorWeightsClipping!{
        didSet{
            clippingBuffer = clippingBuffer ?? context.device.newBufferWithLength(sizeof(IMPColorWeightsClipping), options: .CPUCacheModeDefaultCache)
            if let b = clippingBuffer {
                memcpy(b.contents(), &clippingBuffer, b.length)
            }
            self.dirty = true
        }
    }
    
    public let solver = IMPColorWeightsSolver()
    
    private var clippingBuffer:MTLBuffer?
    
    public required init(context: IMPContext) {
        super.init(context: context, function: "kernel_impColorWeightsPartial")
        super.addSolver(solver)
        defer{
            clipping = IMPColorWeightsAnalyzer.defaultClipping
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        command.setBuffer(self.clippingBuffer, offset: 0, atIndex: 4)
    }
    
    override public func addSolver(solver: IMPHistogramSolver) {
        fatalError("IMPColorWeightsAnalyzer can't add new solver but internal")
    }
}
