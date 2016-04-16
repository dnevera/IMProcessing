//
//  IMPAdjustment.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public protocol IMPAdjustmentProtocol{
    
    var adjustmentBuffer:MTLBuffer? {get set}
    var kernel:IMPFunction! {get set}
    
}

public extension IMPAdjustmentProtocol{
    public func updateBuffer(inout buffer:MTLBuffer?, context:IMPContext, adjustment:UnsafePointer<Void>, size:Int){
        buffer = buffer ?? context.device.newBufferWithLength(size, options: .CPUCacheModeDefaultCache)
        if let b = buffer {
            memcpy(b.contents(), adjustment, b.length)
        }
    }
}
