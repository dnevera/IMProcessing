//
//  IMPGraphics.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

public class IMPGraphics: NSObject, IMPContextProvider {
    
    public let vertexName:String
    public let fragmentName:String
    public var context:IMPContext!
    
    public lazy var library:MTLLibrary = {
        return self.context.defaultLibrary
    }()
    
    public lazy var pipeline:MTLRenderPipelineState? = {
        do {
            let renderPipelineDescription = MTLRenderPipelineDescriptor()
            
            renderPipelineDescription.colorAttachments[0].pixelFormat = IMProcessing.colors.pixelFormat
            
            renderPipelineDescription.vertexFunction   = self.context.defaultLibrary.newFunctionWithName(self.vertexName)
            renderPipelineDescription.fragmentFunction = self.context.defaultLibrary.newFunctionWithName(self.fragmentName)
            
            return try self.context.device.newRenderPipelineStateWithDescriptor(renderPipelineDescription)
        }
        catch let error as NSError{
            fatalError(" *** IMPGraphics: \(error)")
        }
    }()
    
    public required init(context:IMPContext, vertex:String, fragment:String) {
        self.context = context
        self.vertexName = vertex
        self.fragmentName = fragment
    }
}
