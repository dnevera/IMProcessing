//
//  IMPSaturationFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 24.02.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

/// Image saturation filter
public class IMPSaturationFilter:IMPFilter,IMPAdjustmentProtocol{
    
    /// Saturation adjustment.
    /// Default level is 0.5. Level values must be within interval [0,1].
    ///
    public var adjustment:IMPLevelAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeof(IMPLevelAdjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    ///  Create image saturation filter.
    ///
    ///  - parameter context: device context
    ///
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustSaturation")
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPLevelAdjustment(
                level: 0.5,
                blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
            )
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}
