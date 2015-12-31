//
//  IMPColorCubeAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 28.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif


public typealias IMPHistogramCubeUpdateHandler =  ((histogram:IMPHistogramCube) -> Void)

public protocol IMPHistogramCubeSolver {
    func analizerDidUpdate(analizer: IMPHistogramCubeAnalyzer, histogram: IMPHistogramCube, imageSize: CGSize);
}


public class IMPHistogramCubeAnalyzer: IMPFilter {
    
    public var histogram = IMPHistogramCube()
    
    public var downScaleFactor:Float!{
        didSet{
            scaleUniformBuffer = scaleUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(Float), options: .CPUCacheModeDefaultCache)
            memcpy(scaleUniformBuffer.contents(), &downScaleFactor, scaleUniformBuffer.length)
        }
    }
    
    public static var defaultClipping = IMPHistogramCubeClipping(shadows: float3(0.2,0.2,0.2), highlights: float3(0.2,0.2,0.2))
    
    private var clippingBuffer:MTLBuffer!
    public var clipping:IMPHistogramCubeClipping!{
        didSet{
            clippingBuffer = clippingBuffer ?? context.device.newBufferWithLength(sizeof(IMPHistogramCubeClipping), options: .CPUCacheModeDefaultCache)
            memcpy(clippingBuffer.contents(), &clipping, clippingBuffer.length)

        }
    }
    
    private var scaleUniformBuffer:MTLBuffer!
    private var solvers:[IMPHistogramCubeSolver] = [IMPHistogramCubeSolver]()
    
    public func addSolver(solver:IMPHistogramCubeSolver){
        solvers.append(solver)
    }
    
    public var region:IMPCropRegion!{
        didSet{
            regionUniformBuffer = regionUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(IMPCropRegion), options: .CPUCacheModeDefaultCache)
            memcpy(regionUniformBuffer.contents(), &region, regionUniformBuffer.length)
        }
    }
    internal var regionUniformBuffer:MTLBuffer!
    
    private var kernel_impHistogramCounter:IMPFunction!
    private var histogramUniformBuffer:MTLBuffer!
    private var threadgroups = MTLSize(width: 1, height: 1, depth: 1)
    private var threadgroupCounts = MTLSize(width: Int(kIMP_HistogramCubeThreads),height: 1,depth: 1)
    
    public init(context: IMPContext, function: String) {
        super.init(context: context)
        
        kernel_impHistogramCounter = IMPFunction(context: self.context, name:function)
        
        let groups = kernel_impHistogramCounter.pipeline!.maxTotalThreadsPerThreadgroup/threadgroupCounts.width
        
        threadgroups = MTLSizeMake(groups,1,1)
        
        histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramCubeBuffer) * Int(groups), options: MTLResourceOptions.CPUCacheModeDefaultCache)
        
        self.addFunction(kernel_impHistogramCounter);
        
        defer{
            region = IMPCropRegion(top: 0, right: 0, left: 0, bottom: 0)
            downScaleFactor = 1.0
            clipping = IMPHistogramCubeAnalyzer.defaultClipping
        }
    }
    
    convenience required public init(context: IMPContext) {
        self.init(context:context, function: "kernel_impHistogramCubePartial")
    }
    
    public func addUpdateObserver(observer:IMPHistogramCubeUpdateHandler){
        analizerUpdateHandlers.append(observer)
    }
    
    private var analizerUpdateHandlers:[IMPHistogramCubeUpdateHandler] = [IMPHistogramCubeUpdateHandler]()
    
    public override var source:IMPImageProvider?{
        didSet{
            
            super.source = source
            
            if source?.texture != nil {
                // выполняем фильтр
                self.apply()
            }
        }
    }
    
    public override var destination:IMPImageProvider?{
        get{
            return source
        }
    }
    
    internal func apply(texture:MTLTexture, buffer:MTLBuffer!) {
        
        self.context.execute { (commandBuffer) -> Void in

            let blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.fillBuffer(buffer, range: NSMakeRange(0, buffer.length), value: 0)
            blitEncoder.endEncoding()
            
            let commandEncoder = commandBuffer.computeCommandEncoder()
            
            commandEncoder.setComputePipelineState(self.kernel_impHistogramCounter.pipeline!);
            commandEncoder.setTexture(texture, atIndex:0)
            commandEncoder.setBuffer(buffer, offset:0, atIndex:0)
            commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, atIndex:1)
            commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, atIndex:2)
            commandEncoder.setBuffer(self.clippingBuffer,         offset:0, atIndex:3)
            
            self.configure(self.kernel_impHistogramCounter, command: commandEncoder)
            
            commandEncoder.dispatchThreadgroups(self.threadgroups, threadsPerThreadgroup:self.threadgroupCounts);
            commandEncoder.endEncoding()
        }
    }
    
    public override func apply() {
        
        if let texture = source?.texture{
            
            apply( texture, buffer: histogramUniformBuffer)
            
            histogram.updateWithData(histogramUniformBuffer.contents(), dataCount: threadgroups.width)
            
            for s in solvers {
                let size = CGSizeMake(CGFloat(texture.width), CGFloat(texture.height))
                s.analizerDidUpdate(self, histogram: self.histogram, imageSize: size)
            }
            
            for o in analizerUpdateHandlers{
                o(histogram: histogram)
            }
            
        }
    }
}