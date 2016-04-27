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


/// RGB-Cube update handler
public typealias IMPHistogramCubeUpdateHandler =  ((histogram:IMPHistogramCube) -> Void)

///  @brief RGB-Cube solver protocol uses to extend cube analizer computation
public protocol IMPHistogramCubeSolver {
    ///  Handler calls every times when analizer calculation completes.
    ///
    ///  - parameter analizer:  analizer wich did computation
    ///  - parameter histogram: current rgb-cube histogram
    ///  - parameter imageSize: image size
    func analizerDidUpdate(analizer: IMPHistogramCubeAnalyzer, histogram: IMPHistogramCube, imageSize: CGSize);
}


/// RGB-Cube histogram analizer calculates and prepares base RGB-Cube statistics such as color count and rgb-volumes an image distribution
public class IMPHistogramCubeAnalyzer: IMPFilter {
    
    /// Cube histogram
    public var histogram = IMPHistogramCube()
    
    /// To manage computation complexity you may downscale source image presentation inside the filter kernel function
    public var downScaleFactor:Float!{
        didSet{
            scaleUniformBuffer = scaleUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(Float), options: .CPUCacheModeDefaultCache)
            memcpy(scaleUniformBuffer.contents(), &downScaleFactor, scaleUniformBuffer.length)
            dirty = true
        }
    }
    
    /// Default colors clipping
    public static var defaultClipping = IMPHistogramCubeClipping(shadows: float3(0.2,0.2,0.2), highlights: float3(0.2,0.2,0.2))
    
    private var clippingBuffer:MTLBuffer!
    /// Clipping preferences
    public var clipping:IMPHistogramCubeClipping!{
        didSet{
            clippingBuffer = clippingBuffer ?? context.device.newBufferWithLength(sizeof(IMPHistogramCubeClipping), options: .CPUCacheModeDefaultCache)
            memcpy(clippingBuffer.contents(), &clipping, clippingBuffer.length)
            dirty = true
        }
    }
    
    private var scaleUniformBuffer:MTLBuffer!
    private var solvers:[IMPHistogramCubeSolver] = [IMPHistogramCubeSolver]()
    
    ///  Add to the analyzer new solver
    ///
    ///  - parameter solver: rgb-cube histogram solver
    public func addSolver(solver:IMPHistogramCubeSolver){
        solvers.append(solver)
    }
    
    /// Crop region defines wich region of the image should be explored.
    public var region:IMPRegion!{
        didSet{
            regionUniformBuffer = regionUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(IMPRegion), options: .CPUCacheModeDefaultCache)
            memcpy(regionUniformBuffer.contents(), &region, regionUniformBuffer.length)
            dirty = true
        }
    }
    internal var regionUniformBuffer:MTLBuffer!
    
    private var kernel_impHistogramCounter:IMPFunction!
    private var histogramUniformBuffer:MTLBuffer!
    private var threadgroups = MTLSize(width: 1, height: 1, depth: 1)
    private var threadgroupCounts = MTLSize(width: Int(kIMP_HistogramCubeThreads),height: 1,depth: 1)
    
    ///  Create RGB-Cube histogram analizer with new kernel
    ///
    ///  - parameter context:  device context
    ///  - parameter function: new rgb-cube histogram kernel
    ///
    public init(context: IMPContext, function: String) {
        super.init(context: context)
        
        kernel_impHistogramCounter = IMPFunction(context: self.context, name:function)
        
        let maxThreads:Int  = kernel_impHistogramCounter.pipeline!.maxTotalThreadsPerThreadgroup
        let actualWidth:Int = threadgroupCounts.width <= maxThreads ? threadgroupCounts.width : maxThreads
        
        threadgroupCounts.width = actualWidth 
        
        let groups = maxThreads/actualWidth
        
        threadgroups = MTLSizeMake(groups,1,1)
        
        histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramCubeBuffer) * Int(groups), options: MTLResourceOptions.CPUCacheModeDefaultCache)
        
        self.addFunction(kernel_impHistogramCounter);
        
        defer{
            region = IMPRegion(left: 0, right: 0, top: 0, bottom: 0)
            downScaleFactor = 1.0
            clipping = IMPHistogramCubeAnalyzer.defaultClipping
        }
    }
    
    ///  Create RGB-Cube histogram analizer with standard kernel
    ///
    ///  - parameter context:  device context
    ///
    convenience required public init(context: IMPContext) {
        self.init(context:context, function: "kernel_impHistogramCubePartial")
    }
    
    ///  Add RGB-Cube histogram observer
    ///
    ///  - parameter observer: RGB-Cube update enclosure
    public func addUpdateObserver(observer:IMPHistogramCubeUpdateHandler){
        analizerUpdateHandlers.append(observer)
    }
    
    private var analizerUpdateHandlers:[IMPHistogramCubeUpdateHandler] = [IMPHistogramCubeUpdateHandler]()
    
    /// Source image frame
    public override var source:IMPImageProvider?{
        didSet{
            
            super.source = source
            
            if source?.texture != nil {
                // выполняем фильтр
                self.apply()
            }
        }
    }
    
    /// Destination image frame is equal the source frame
    public override var destination:IMPImageProvider?{
        get{
            return source
        }
    }
    
    internal func apply(texture:MTLTexture, buffer:MTLBuffer!) {
        
        self.context.execute { (commandBuffer) -> Void in
            
            #if os(iOS) 
                let blitEncoder = commandBuffer.blitCommandEncoder()
                blitEncoder.fillBuffer(buffer, range: NSMakeRange(0, buffer.length), value: 0)
                blitEncoder.endEncoding()
            #else
                memset(buffer.contents(), 0, buffer.length)
            #endif
            
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
    
    ///  Apply analyzer to the source frame. The method applyes every time automaticaly 
    ///  when any changes occur with the filter, or dirty property is set. 
    ///  Usually you don't need call the method except cases you sure you have to launch new computation.
    ///
    public override func apply() -> IMPImageProvider {
        
        if let texture = source?.texture{
            
            apply( texture, buffer: histogramUniformBuffer)
            
            histogram.update(data: histogramUniformBuffer.contents(), dataCount: threadgroups.width)
            
            for s in solvers {
                let size = CGSizeMake(CGFloat(texture.width), CGFloat(texture.height))
                s.analizerDidUpdate(self, histogram: self.histogram, imageSize: size)
            }
            
            for o in analizerUpdateHandlers{
                o(histogram: histogram)
            }
        }
        
        return source!
    }
}