//
//  IMPWBFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

/// White balance correction filter
public class IMPWBFilter:IMPFilter,IMPAdjustmentProtocol{
    
    /// Default WB adjustment
    public static let defaultAdjustment = IMPWBAdjustment(
        ///  @brief default dominant color of the image
        ///
        dominantColor: float4([0.5, 0.5, 0.5, 0.5]),
        ///  @brief Blending mode and opacity
        ///
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
    )
    
    /// Adjust filter
    public var adjustment:IMPWBAdjustment!{
        didSet{
            updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeof(IMPWBAdjustment))
            dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    ///  Create WB filter.
    ///
    ///  - parameter context: device context
    ///
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustWB")
        addFunction(kernel)
        defer{
            adjustment = IMPWBFilter.defaultAdjustment
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}
