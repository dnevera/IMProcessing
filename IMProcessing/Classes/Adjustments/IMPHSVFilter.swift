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

public extension Float32{
    
    func hueWeight(ramp ramp:float4) -> Float32 {
        
        var sigma = (ramp.z-ramp.y)
        var mu    = (ramp.w+ramp.x)/2.0
        
        if ramp.y>ramp.z {
            sigma = (360.0-ramp.y+ramp.z)
            if (self >= 0.float) && (self <= 360.0/2.0) {
                mu    = (360.0-ramp.y-ramp.z) / 2.0
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

public extension IMProcessing{
    static let hueRamps:[float4] = [kIMP_Reds, kIMP_Yellows, kIMP_Greens, kIMP_Cyans, kIMP_Blues, kIMP_Magentas]
}

public class IMPHSVFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public static let defaultAdjustment = IMPHSVAdjustment(
        reds:     float4(0),
        yellows:  float4(0),
        greens:   float4(0),
        cyans:    float4(0),
        blues:    float4(0),
        magentas: float4(0),
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1))
    
    public var adjustment:IMPHSVAdjustment!{
        didSet{
            print(" --- hsv --- \(adjustment)")
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeof(IMPWBAdjustment))
            self.dirty = true
        }
    }
    
    internal var adjustmentBuffer:MTLBuffer?
    internal var kernel:IMPFunction!
    internal var hueWeights:MTLTexture!
    
    public required init(context: IMPContext) {
        
        super.init(context: context)
        
        kernel = IMPFunction(context: self.context, name: "kernel_adjustHSV")
        addFunction(kernel)
        hueWeights = IMPHSVFilter.defaultHueWeights(self.context)
        
        defer{
            self.adjustment = IMPHSVFilter.defaultAdjustment
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
            command.setTexture(hueWeights, atIndex: 2)
        }
    }
    
    
    public static func defaultHueWeights(context:IMPContext) -> MTLTexture {
        let width  = 360
        
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = .Type1DArray;
        textureDescriptor.width       = width;
        textureDescriptor.height      = 1;
        textureDescriptor.depth       = 1;
        textureDescriptor.pixelFormat = .R32Float;
        
        textureDescriptor.arrayLength = IMProcessing.hueRamps.count;
        textureDescriptor.mipmapLevelCount = 1;
        
        
        let region = MTLRegionMake2D(0, 0, width, 1);
        
        let hueWeights = context.device.newTextureWithDescriptor(textureDescriptor)

        let hues = Float.range(0..<width)
        for i in 0..<IMProcessing.hueRamps.count{
            let ramp = IMProcessing.hueRamps[i]
            var data = hues.hueWeightsDistribution(ramp: ramp) as [Float32]
            
            NSLog(" ramp \(ramp) :  \(data)")
            hueWeights.replaceRegion(region, mipmapLevel:0, slice:i, withBytes:&data, bytesPerRow:sizeof(Float32) * width, bytesPerImage:0)
        }
        
        return hueWeights;
    }
    
}
    