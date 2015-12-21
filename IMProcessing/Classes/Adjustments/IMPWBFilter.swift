//
//  IMPWBFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa

public class IMPWBFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public static let defaultAdjustment = IMPWBAdjustment(
        dominantColor: float4([0.5, 0.5, 0.5, 0.5]),
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
    )
    
    public var adjustment:IMPWBAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeof(IMPWBAdjustment))
            self.dirty = true
        }
    }
    
    internal var adjustmentBuffer:MTLBuffer?
    internal var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustWB")
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPWBFilter.defaultAdjustment
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}
