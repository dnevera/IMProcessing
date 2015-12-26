//
//  IMPFunction.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

public class IMPFunction: NSObject, IMPContextProvider {

    public struct GroupSize {
        var width:Int  = 16
        var height:Int = 16
    }

    public let kernel:MTLFunction?
    public let library:MTLLibrary?
    public let pipeline:MTLComputePipelineState?
    public let name:String
    public let groupSize:GroupSize = GroupSize()
    
    public var context:IMPContext!
        
    public required init(context:IMPContext, name:String) {
        
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
