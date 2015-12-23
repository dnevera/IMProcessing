//
//  IMPHSVFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal
import simd

public extension IMProcessing{
    struct hsv {
        /// Ramps of HSV hextants in the HSV color wheel with overlaping levels
        static let hueRamps:[float4] = [kIMP_Reds, kIMP_Yellows, kIMP_Greens, kIMP_Cyans, kIMP_Blues, kIMP_Magentas]
        /// Overlap factor
        static let hueOverlapFactor  = 1.4
        /// Hue range of the HSV color wheel
        static let hueRange = Range<Int>(0..<360)
    }
}

extension Float32{
    
    //
    // Get HSV weight for the hue overlap between two close colors in the HSV color wheel
    //
    func hueWeight(ramp ramp:float4) -> Float32 {
        
        var sigma = (ramp.z-ramp.y)
        var mu    = (ramp.w+ramp.x)/2.0
        
        if ramp.y>ramp.z {
            sigma = (IMProcessing.hsv.hueRange.endIndex.float-ramp.y+ramp.z)
            if (self >= 0.float) && (self <= IMProcessing.hsv.hueRange.endIndex.float/2.0) {
                mu    = (IMProcessing.hsv.hueRange.endIndex.float-ramp.y-ramp.z) / 2.0
            }else{
                mu    = (ramp.y+ramp.z)
            }
        }
        
        return self.gaussianPoint(fi: 1, mu: mu, sigma: sigma)
    }
}

public extension SequenceType where Generator.Element == Float32 {
    
    public func hueWeightsDistribution(ramp ramp:float4) -> [Float32]{
        var a = [Float32]()
        for i in self{
            a.append(i.hueWeight(ramp: ramp))
        }
        return a
    }
    
    public func hueWeightsDistribution(ramp ramp:float4) -> NSData {
        let f:[Float32] = hueWeightsDistribution(ramp: ramp) as [Float32]
        return NSData(bytes: f, length: f.count)
    }
    
}

public extension IMPHSVAdjustment{
    public var reds:    IMPHSVLevel{ get { return levels.0 } set(newValue){ levels.0 = newValue }}
    public var yellows: IMPHSVLevel{ get { return levels.1 } set(newValue){ levels.1 = newValue }}
    public var greens:  IMPHSVLevel{ get { return levels.2 } set(newValue){ levels.2 = newValue }}
    public var cyans:   IMPHSVLevel{ get { return levels.3 } set(newValue){ levels.3 = newValue }}
    public var blues:   IMPHSVLevel{ get { return levels.4 } set(newValue){ levels.4 = newValue }}
    public var magentas:IMPHSVLevel{ get { return levels.5 } set(newValue){ levels.5 = newValue }}
    public subscript(index:Int) -> IMPHSVLevel {
        get{
            var i = IMPHSVLevel()
            switch(index){
            case 0:
                i=reds
            case 1:
                i=yellows
            case 2:
                i=greens
            case 3:
                i=cyans
            case 4:
                i=blues
            case 5:
                i=magentas
            default:
                i = master
            }
            return i
        }
        set(newValue){
            switch(index){
            case 0:
                reds = newValue
            case 1:
                yellows = newValue
            case 2:
                greens = newValue
            case 3:
                cyans  = newValue
            case 4:
                blues  = newValue
            case 5:
                magentas  = newValue
            default:
                master  = newValue
            }
        }
    }
}

///
/// HSV adjustment filter
///
public class IMPHSVFilter:IMPFilter,IMPAdjustmentProtocol{
    
    ///  Optimization level description
    ///
    ///  - HIGH:   default optimization uses when you need to accelerate hsv adjustment
    ///  - NORMAL: hsv adjustments application without interpolation
    public enum optimizationLevel{
        case HIGH
        case NORMAL
    }
    
    ///
    /// Default HSV adjustment
    ///
    public static let defaultAdjustment = IMPHSVAdjustment(
        master:   IMPHSVFilter.level,
        levels:  (IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level),
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
    )
    
    /// HSV adjustment levels
    public var adjustment:IMPHSVAdjustment!{
        didSet{
            if self.optimization == .HIGH {
                adjustmentLut.blending = adjustment.blending
                self.updateBuffer(&adjustmentLutBuffer, context:context, adjustment:&adjustmentLut, size:sizeof(IMPAdjustment))
            }
            updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeof(IMPHSVAdjustment))
            
            if self.optimization == .HIGH {
                applyHsv3DLut()
            }
            
            dirty = true
        }
    }
    
    ///  Create HSV adjustment filter. 
    ///
    ///  - .HIGH optimization level uses to reduce HSV adjustment computation per pixel.
    ///     only defult 64x64x64 LUT creates and then applies to final image. With this 
    ///     option an image modification can lead to the appearance of artifacts in the image.
    ///    .HIGH level can use for live-view mode of image processing
    ///
    ///  - .Normal uses for more precise HSV adjustments
    ///
    ///  - parameter context:      execution context
    ///  - parameter optimization: optimization level
    ///
    public required init(context: IMPContext, optimization:optimizationLevel) {
        
        super.init(context: context)
        
        self.optimization = optimization
        
        if self.optimization == .HIGH {
            kernel = IMPFunction(context: self.context, name: "kernel_adjustLutD3D")
            kernel_hsv3DLut = IMPFunction(context: self.context, name: "kernel_adjustHSV3DLut")
            hsv3DlutTexture = hsv3DLut(64)
        }
        else{
            kernel = IMPFunction(context: self.context, name: "kernel_adjustHSV")
        }
        
        addFunction(kernel)
        
        hueWeights = IMPHSVFilter.defaultHueWeights(self.context)
        
        defer{
            adjustment = IMPHSVFilter.defaultAdjustment
        }
    }

    ///  Create HSV adjustment filter with default optimization level .NORMAL
    ///
    ///  - parameter context: device execution context
    ///
    public convenience required init(context: IMPContext) {
        self.init(context: context, optimization:.NORMAL)
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            if self.optimization == .HIGH {
                command.setTexture(hsv3DlutTexture, atIndex: 2)
                command.setBuffer(adjustmentLutBuffer, offset: 0, atIndex: 0)
            }
            else{
                command.setTexture(hueWeights, atIndex: 2)
                command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
            }
        }
    }
    
    
    ///  Create new hue color overlaping weights for the HSV color wheel
    ///
    ///  - parameter context: device execution context
    ///
    ///  - returns: new overlaping weights
    public static func defaultHueWeights(context:IMPContext) -> MTLTexture {
        let width  = IMProcessing.hsv.hueRange.endIndex
        
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = .Type1DArray;
        textureDescriptor.width       = width;
        textureDescriptor.height      = 1;
        textureDescriptor.depth       = 1;
        textureDescriptor.pixelFormat = .R32Float;
        
        textureDescriptor.arrayLength = IMProcessing.hsv.hueRamps.count;
        textureDescriptor.mipmapLevelCount = 1;
        
        
        let region = MTLRegionMake2D(0, 0, width, 1);
        
        let hueWeights = context.device.newTextureWithDescriptor(textureDescriptor)
        
        let hues = Float.range(0..<width)
        for i in 0..<IMProcessing.hsv.hueRamps.count{
            let ramp = IMProcessing.hsv.hueRamps[i]
            var data = hues.hueWeightsDistribution(ramp: ramp) as [Float32]
            hueWeights.replaceRegion(region, mipmapLevel:0, slice:i, withBytes:&data, bytesPerRow:sizeof(Float32) * width, bytesPerImage:0)
        }
        
        return hueWeights;
    }
    
    
    internal static let level:IMPHSVLevel = IMPHSVLevel(hue: 0.0, saturation: 0, value: 0)
    internal var adjustmentBuffer:MTLBuffer?
    internal var kernel:IMPFunction!
    internal var hueWeights:MTLTexture!
    
    private  var adjustmentLut = IMPAdjustment(blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1))
    internal var adjustmentLutBuffer:MTLBuffer?
    
    private var optimization:optimizationLevel!

    //
    //
    //
    //
    private var kernel_hsv3DLut:IMPFunction!
    
    private func applyHsv3DLut(){
        
        self.context.execute({ (commandBuffer) -> Void in
            
            let width  = self.hsv3DlutTexture!.width
            let height = self.hsv3DlutTexture!.height
            let depth  = self.hsv3DlutTexture!.depth
            
            let threadgroupCounts = MTLSizeMake(self.kernel_hsv3DLut.groupSize.width, self.kernel_hsv3DLut.groupSize.height,  self.kernel_hsv3DLut.groupSize.height);
            let threadgroups = MTLSizeMake(
                (width  + threadgroupCounts.width ) / threadgroupCounts.width ,
                (height + threadgroupCounts.height) / threadgroupCounts.height,
                (depth + threadgroupCounts.height) / threadgroupCounts.depth);
            
            let commandEncoder = commandBuffer.computeCommandEncoder()
            
            commandEncoder.setComputePipelineState(self.kernel_hsv3DLut.pipeline!)
            
            commandEncoder.setTexture(self.hsv3DlutTexture, atIndex:0)
            commandEncoder.setTexture(self.hueWeights, atIndex:1)
            commandEncoder.setBuffer(self.adjustmentBuffer, offset: 0, atIndex: 0)

            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
            commandEncoder.endEncoding()
        })
    }
    
    private var hsv3DlutTexture:MTLTexture?
    
    private func hsv3DLut(dimention:Int) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = .Type3D
        textureDescriptor.width  = dimention
        textureDescriptor.height = dimention
        textureDescriptor.depth  = dimention
        
        textureDescriptor.pixelFormat =  .RGBA8Unorm
        
        textureDescriptor.arrayLength = 1;
        textureDescriptor.mipmapLevelCount = 1;
        
        let texture = context.device.newTextureWithDescriptor(textureDescriptor)
        
        return texture
    }
}
    