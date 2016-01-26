//
//  IMPNoiseFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 25.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

public class IMPRandomNoiseFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public static let defaultAdjustment = IMPLevelAdjustment(
        level: 1,
        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPLevelAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeofValue(adjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_randomNoise")
        self.addFunction(kernel)
        timerBuffer = context.device.newBufferWithLength(sizeof(Float), options: .CPUCacheModeDefaultCache)
        defer{
            self.adjustment = IMPRandomNoiseFilter.defaultAdjustment
        }
    }    
    
    var timerBuffer:MTLBuffer!
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate()).0)
            var rand = Float(arc4random_uniform(timer))/Float(timer)
            memcpy(timerBuffer.contents(), &rand, sizeof(Float))
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
            command.setBuffer(timerBuffer, offset: 0, atIndex: 1)
        }
    }
}