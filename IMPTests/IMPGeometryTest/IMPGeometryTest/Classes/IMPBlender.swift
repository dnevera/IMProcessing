//
//  IMPBlender.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 07.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

import IMProcessing

public class IMPBlender: NSObject, IMPContextProvider {
    
    public let vertexName:String
    public let fragmentName:String
    public var context:IMPContext!
    
    public lazy var library:MTLLibrary = {
        return self.context.defaultLibrary
    }()
    
    public lazy var pipeline:MTLRenderPipelineState? = {
        do {
            let renderPipelineDescription = MTLRenderPipelineDescriptor()
            
            renderPipelineDescription.vertexDescriptor = self.vertexDescriptor
            
            renderPipelineDescription.colorAttachments[0].pixelFormat = .RGBA8Unorm
            
            renderPipelineDescription.colorAttachments[0].blendingEnabled = true
            renderPipelineDescription.colorAttachments[0].rgbBlendOperation = .Add
            renderPipelineDescription.colorAttachments[0].alphaBlendOperation = .Add
            
            renderPipelineDescription.colorAttachments[0].sourceRGBBlendFactor = .SourceColor
            renderPipelineDescription.colorAttachments[0].sourceAlphaBlendFactor = .SourceAlpha
            
            renderPipelineDescription.colorAttachments[0].destinationRGBBlendFactor = .One
            renderPipelineDescription.colorAttachments[0].destinationAlphaBlendFactor = .One
            
            renderPipelineDescription.vertexFunction   = self.context.defaultLibrary.newFunctionWithName(self.vertexName)
            renderPipelineDescription.fragmentFunction = self.context.defaultLibrary.newFunctionWithName(self.fragmentName)
            
            return try self.context.device.newRenderPipelineStateWithDescriptor(renderPipelineDescription)
        }
        catch let error as NSError{
            fatalError(" *** IMPGraphics: \(error)")
        }
    }()
    
    public required init(context:IMPContext, vertex:String, fragment:String, vertexDescriptor:MTLVertexDescriptor? = nil) {
        self.context = context
        self.vertexName = vertex
        self.fragmentName = fragment
    }
    
    lazy var vertexDescriptor:MTLVertexDescriptor = {
        var v = MTLVertexDescriptor()
        v.attributes[0].format = .UChar4;
        v.attributes[0].bufferIndex = 0;
        v.attributes[0].offset = 0;
        v.layouts[0].stride = 4 * sizeof(UInt8)
        
        return v
    }()
}
