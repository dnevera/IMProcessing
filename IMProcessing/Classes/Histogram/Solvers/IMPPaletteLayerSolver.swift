//
//  IMPPalleteLayerSolver.swift
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

public class IMPPaletteLayerSolver: IMPFilter, IMPHistogramCubeSolver {

    public var layer = IMPPaletteLayerBuffer(backgroundColor: float4([0,0,0,1]), backgroundSource: false) {
        didSet{
            memcpy(layerBuffer.contents(), &layer, layerBuffer.length)
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        
        layerBuffer = context.device.newBufferWithBytes(&layer, length: sizeof(IMPPaletteLayerBuffer), options: .CPUCacheModeDefaultCache)
        
        palleteBuffer =  context.device.newBufferWithLength(sizeof(IMPPaletteBuffer), options: .CPUCacheModeDefaultCache)
        memset(palleteBuffer.contents(), 0, palleteBuffer.length)

        palleteCountBuffer = context.device.newBufferWithLength(sizeof(uint), options: .CPUCacheModeDefaultCache)
        memset(palleteCountBuffer.contents(), 0, palleteCountBuffer.length)
        
        kernel = IMPFunction(context: self.context, name: "kernel_paletteLayer")
        self.addFunction(kernel)
    }
    
    public func analizerDidUpdate(analizer: IMPHistogramCubeAnalyzer, histogram: IMPHistogramCube, imageSize: CGSize) {
        let palette      = histogram.cube.palette(count: 8)
        var paletteLayer = [IMPPaletteBuffer](count: palette.count, repeatedValue: IMPPaletteBuffer(color: vector_float4()))
        for i in 0..<palette.count {
            paletteLayer[i].color = float4(rgb: palette[i], a: 1)
        }
        let length = palette.count * sizeof(IMPPaletteBuffer)
        var count = palette.count
        
        memcpy(palleteCountBuffer.contents(), &count, palleteCountBuffer.length)

        if palleteBuffer?.length != length {
            palleteBuffer = nil
        }
        palleteBuffer =  palleteBuffer ?? context.device.newBufferWithLength(length, options: .CPUCacheModeDefaultCache)
        memcpy(palleteBuffer.contents(), &paletteLayer, palleteBuffer.length)
    }
    
    override public func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if (kernel == function){
            command.setBuffer(palleteBuffer, offset: 0, atIndex: 0)
            command.setBuffer(palleteCountBuffer,  offset: 0, atIndex: 1)
            command.setBuffer(layerBuffer,     offset: 0, atIndex: 2)
        }
    }
    private var kernel:IMPFunction!
    private var palleteBuffer:MTLBuffer!
    private var palleteCountBuffer:MTLBuffer!
    private var layerBuffer:MTLBuffer!

}