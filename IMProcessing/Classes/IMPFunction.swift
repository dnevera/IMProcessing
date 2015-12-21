//
//  IMPFunction.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import Metal
import simd

class IMPFunction: NSObject, IMPContextProvider {

    struct GroupSize {
        var width:Int  = 16
        var height:Int = 16
    }

    let kernel:MTLFunction?
    let library:MTLLibrary?
    let pipeline:MTLComputePipelineState?
    let name:String
    let groupSize:GroupSize = GroupSize()
    
    var context:IMPContext!
        
    required init(context:IMPContext, name:String) {
        
        self.context = context
        self.name = name
        
        library = self.context.device.newDefaultLibrary()
        
        if let l = library {
            kernel = l.newFunctionWithName(self.name)
            if kernel == nil {
                fatalError(" *** IMPFunction: \(name) has not foumd...")
            }
            do{
                pipeline = try self.context.device.newComputePipelineStateWithFunction(kernel!)
            }
            catch let error as NSError{
                fatalError(" *** IMPFunction: \(error)")
            }
        }
        else{
            fatalError(" *** IMPFunction: default Metal library is not found...")
        }
        
    }    
}
