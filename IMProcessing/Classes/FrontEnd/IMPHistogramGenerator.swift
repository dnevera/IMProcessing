//
//  IMPHistogramLayer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 06.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPHistogramGenerator: IMPFilter{
    
    var texture:MTLTexture?
    
    public var size:IMPSize!{
        didSet{
            if
                texture?.width.cgfloat != size.width
                ||
                texture?.height.cgfloat != size.height
            {
                let desc = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
                texture = context.device.newTextureWithDescriptor(desc)
            }
            
            self.source = IMPImageProvider(context: context, texture: texture!)
        }
    }
    
    public static let defaultLayer = IMPHistogramLayer(
        components: (
            IMPHistogramLayerComponent(color: float4([1,0,0,0.5]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,1,0,0.6]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,0,1,0.7]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.8,0.8,0.8,0.8]), width: Float(UInt32.max))),
        backgroundColor: float4([0.1, 0.1, 0.1, 0.7]),
        backgroundSource: false)
    
    public var layer = IMPHistogramGenerator.defaultLayer {
        didSet{
            layerUniformBiffer = layerUniformBiffer ?? self.context.device.newBufferWithLength(sizeof(IMPHistogramLayer), options: .CPUCacheModeDefaultCache)
            memcpy(layerUniformBiffer.contents(), &layer, sizeof(IMPHistogramLayer))
        }
    }
    
    public required init(context: IMPContext, size:IMPSize) {
        super.init(context: context)
        
        defer{
            self.size = size
        }
        
        kernel = IMPFunction(context: self.context, name: "kernel_histogramLayer")
        self.addFunction(kernel)
        channelsUniformBuffer = self.context.device.newBufferWithLength(sizeof(UInt), options: .CPUCacheModeDefaultCache)
        histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramFloatBuffer), options: .CPUCacheModeDefaultCache)
        defer{
            layer = IMPHistogramGenerator.defaultLayer
        }
    }

    required public init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    public var histogram:IMPHistogram?{
        didSet{
            if let h = histogram {
                update(h)
            }
        }
    }
    
    func update(histogram: IMPHistogram){
        
        let pdf = histogram
        
        for c in 0..<pdf.channels.count{
            let address =  UnsafeMutablePointer<Float>(histogramUniformBuffer.contents())+c*pdf.size
            memset(address, 0, sizeof(Float)*pdf.size)
            memcpy(address, pdf.channels[c], sizeof(Float)*pdf.size)
        }
        
        var channels = pdf.channels.count
        memcpy(channelsUniformBuffer.contents(), &channels, sizeof(UInt))
        
        self.dirty = true;
        self.apply()
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
