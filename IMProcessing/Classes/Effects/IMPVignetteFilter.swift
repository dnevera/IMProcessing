//
//  IMPVignetteFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 14.06.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Metal

/// Vignette filter
public class IMPVignetteFilter: IMPFilter,IMPAdjustmentProtocol {
    
    /// Vignetting type
    ///
    ///  - Center: around center point
    ///  - Frame:  by region frame rectangle
    public enum Type{
        case Center
        case Frame
    }
    
    ///  @brief Vignette adjustment
    public struct Adjustment {
        /// Start vignetting path
        public var start:Float  = 0 {
            didSet {
                check_diff()
            }
        }
        /// End vignetting path
        public var end:Float    = 1 {
            didSet {
                check_diff()
            }
        }
        /// Vignetting color
        public var color    = float3(0)
        /// Blending options
        public var blending = IMPBlending(mode: NORMAL, opacity: 1)
        public init(start:Float, end:Float, color:float3, blending:IMPBlending){
            self.start = start
            self.end = end
            self.color = color
            self.blending = blending
        }
        public init() {}
        
        mutating func  check_diff() {
            if abs(end - start) < FLT_EPSILON  {
                end   = start+FLT_EPSILON // to avoid smoothstep 0 division
            }
        }
    }
    
    /// Vignette region
    public var region = IMPRegion() {
        didSet{
            memcpy(regionUniformBuffer.contents(), &region, regionUniformBuffer.length)
            var c = center
            memcpy(centerUniformBuffer.contents(), &c, centerUniformBuffer.length)
            dirty = true
        }
    }
    
    public var center:float2 {
        get {
            let rect = region.rectangle
            let x = rect.origin.x + rect.size.width/2
            let y = rect.origin.y + rect.size.height/2
            return float2(x.float,y.float)
        }
    }
    
    /// Default adjusment
    public static let defaultAdjustment = Adjustment()
    
    /// Current adjusment
    public var adjustment:Adjustment!{
        didSet{
            memcpy(colorStartUniformBuffer.contents(), &self.adjustment.start, colorStartUniformBuffer.length)
            memcpy(colorEndUniformBuffer.contents(), &self.adjustment.end, colorEndUniformBuffer.length)
            memcpy(colorUniformBuffer.contents(), &self.adjustment.color, colorUniformBuffer.length)
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment.blending, size:sizeofValue(adjustment.blending))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    var type:Type!
    
    public required init(context: IMPContext, type:Type = .Center) {
        super.init(context: context)
        self.type = type
        if type == .Center {
            kernel = IMPFunction(context: self.context, name: "kernel_vignetteCenter")
        }
        else {
            kernel = IMPFunction(context: self.context, name: "kernel_vignetteFrame")
        }
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPVignetteFilter.defaultAdjustment
        }
    }    
    
    required public init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
 
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
            command.setBuffer(colorStartUniformBuffer, offset: 0, atIndex: 1)
            command.setBuffer(colorEndUniformBuffer, offset: 0, atIndex: 2)
            command.setBuffer(colorUniformBuffer, offset: 0, atIndex: 3)
            if type == .Center {
                command.setBuffer(centerUniformBuffer, offset: 0, atIndex: 4)
            }
            else {
                command.setBuffer(regionUniformBuffer, offset: 0, atIndex: 4)
            }
        }
    }
    
    lazy var regionUniformBuffer:MTLBuffer = {
        return self.context.device.newBufferWithBytes(&self.region, length: sizeofValue(self.region), options: .CPUCacheModeDefaultCache)
    }()
    
    lazy var centerUniformBuffer:MTLBuffer = {
        var c = self.center
        return self.context.device.newBufferWithBytes(&c, length: sizeofValue(c), options: .CPUCacheModeDefaultCache)
    }()

    lazy var colorStartUniformBuffer:MTLBuffer = {
        return self.context.device.newBufferWithBytes(&self.adjustment.start, length: sizeofValue(self.adjustment.start), options: .CPUCacheModeDefaultCache)
    }()
    
    lazy var colorEndUniformBuffer:MTLBuffer = {
        return self.context.device.newBufferWithBytes(&self.adjustment.end, length: sizeofValue(self.adjustment.end), options: .CPUCacheModeDefaultCache)
    }()
    
    lazy var colorUniformBuffer:MTLBuffer = {
        return self.context.device.newBufferWithBytes(&self.adjustment.color, length: sizeofValue(self.adjustment.color), options: .CPUCacheModeDefaultCache)
    }()
}
