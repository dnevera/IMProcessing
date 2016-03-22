//
//  IMPHistogramLayerSolver.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 18.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPHistogramLayerSolver: IMPFilter, IMPHistogramSolver {
    
    public enum IMPHistogramType{
        case PDF
        case CDF
    }
    
    public var layer = IMPHistogramLayer(
        components: (
            IMPHistogramLayerComponent(color: float4([1,0,0,0.5]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,1,0,0.6]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,0,1,0.7]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.8,0.8,0.8,0.8]), width: Float(UInt32.max))),
        backgroundColor: float4([0.1, 0.1, 0.1, 0.7]),
        backgroundSource: false){
        didSet{
            memcpy(layerUniformBiffer.contents(), &layer, layerUniformBiffer.length)
        }
    }
    
    public var histogramType:(type:IMPHistogramType,power:Float) = (type:.PDF,power:1){
        didSet{
            self.dirty = true;
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_histogramLayer")
        self.addFunction(kernel)
        channelsUniformBuffer = self.context.device.newBufferWithLength(sizeof(UInt), options: .CPUCacheModeDefaultCache)
        histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramFloatBuffer), options: .CPUCacheModeDefaultCache)
        layerUniformBiffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramLayer), options: .CPUCacheModeDefaultCache)
        memcpy(layerUniformBiffer.contents(), &layer, layerUniformBiffer.length)
    }
    
    public var histogram:IMPHistogram?{
        didSet{
            update(histogram!)
        }
    }
    
    func update(histogram: IMPHistogram){
        
        var pdf:IMPHistogram;
        
        switch(histogramType.type){
        case .PDF:
            pdf = histogram.pdf()
        case .CDF:
            pdf = histogram.cdf(1, power: histogramType.power)
        }
        
        for c in 0..<pdf.channels.count{
            let address =  UnsafeMutablePointer<Float>(histogramUniformBuffer.contents())+c*pdf.size
            memcpy(address, pdf.channels[c], sizeof(Float)*pdf.size)
        }
        
        var channels = pdf.channels.count
        memcpy(channelsUniformBuffer.contents(), &channels, sizeof(UInt))
        
        self.dirty = true;
    }
    
    public func analizerDidUpdate(analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize) {
        self.histogram = histogram
    }
    
    override public func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if (kernel == function){
            command.setBuffer(histogramUniformBuffer, offset: 0, atIndex: 0)
            command.setBuffer(channelsUniformBuffer,  offset: 0, atIndex: 1)
            command.setBuffer(layerUniformBiffer,     offset: 0, atIndex: 2)
        }
    }
    
    private var kernel:IMPFunction!
    private var layerUniformBiffer:MTLBuffer!
    private var histogramUniformBuffer:MTLBuffer!
    private var channelsUniformBuffer:MTLBuffer!
}
