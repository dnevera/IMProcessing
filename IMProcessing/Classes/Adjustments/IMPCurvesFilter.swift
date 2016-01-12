//
//  IMPCurveFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

public class IMPCurvesFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public class Splines: IMPTextureProvider,IMPContextProvider {
        
        public var context:IMPContext!
        
        public static let scale:Float    = 1
        public static let minValue = 0
        public static let maxValue = 255
        public static let defaultControls = [float2(minValue.float,minValue.float),float2(maxValue.float,maxValue.float)]
        public static let defaultRange    = Float.range(0..<maxValue)
        public static let defaultCurve    = defaultRange.cubicSpline(defaultControls, scale: scale) as [Float]

        var _redCurve:[Float]   = Splines.defaultCurve
        var _greenCurve:[Float] = Splines.defaultCurve
        var _blueCurve:[Float]  = Splines.defaultCurve
        
        public var channelCurves:[[Float]]{
            get{
                return [_redCurve,_greenCurve,_blueCurve]
            }
        }
        public var redCurve:[Float]{
            get{
                return _redCurve
            }
        }
        public var greenCurve:[Float]{
            get{
                return _greenCurve
            }
        }
        public var blueCurve:[Float]{
            get{
                return _greenCurve
            }
        }
        
        var doNotUpdate = false
        public var redControls   = Splines.defaultControls {
            didSet{
                _redCurve = Splines.defaultRange.cubicSpline(redControls, scale: Splines.scale) as [Float]
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var greenControls = Splines.defaultControls{
            didSet{
                _greenCurve = Splines.defaultRange.cubicSpline(greenControls, scale: Splines.scale) as [Float]
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var blueControls  = Splines.defaultControls{
            didSet{
                _blueCurve = Splines.defaultRange.cubicSpline(blueControls, scale: Splines.scale) as [Float]
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var compositeControls = Splines.defaultControls{
            didSet{
                doNotUpdate = true
                redControls   = compositeControls
                greenControls = compositeControls
                blueControls  = compositeControls
                doNotUpdate = false
                updateTexture()
            }
        }
        
        public var texture:MTLTexture?
        public var filter:IMPFilter?
        
        public required init(context:IMPContext){
            self.context = context
            updateTexture()
        }
        
        func updateTexture(){
            
            if texture == nil {
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.textureType = .Type1DArray
                textureDescriptor.width       = Splines.maxValue
                textureDescriptor.height      = 1
                textureDescriptor.depth       = 1
                textureDescriptor.pixelFormat = .R32Float
                
                textureDescriptor.arrayLength = 3
                textureDescriptor.mipmapLevelCount = 1
                
                texture = context.device.newTextureWithDescriptor(textureDescriptor)
            }

            let region = MTLRegionMake2D(0, 0, texture!.width, 1)
            let bytesPerRow = region.size.width * sizeof(Float32)
            for var index=0; index<channelCurves.count; index++ {
                let curve = channelCurves[index]
                texture!.replaceRegion(region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
            }
            
            if filter != nil {
                filter?.dirty = true
            }
        }
    }
    
    
    public static let defaultAdjustment = IMPAdjustment(
        blending: IMPBlending(mode: IMPBlendingMode.LUMNINOSITY, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeofValue(adjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    public var splines:Splines!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustCurve")
        addFunction(kernel)
        splines = Splines(context: context)
        splines.filter = self
        defer{
            adjustment = IMPCurvesFilter.defaultAdjustment
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(splines.texture, atIndex: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}