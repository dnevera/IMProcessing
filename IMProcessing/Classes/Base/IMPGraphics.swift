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

public protocol IMPGraphicsProvider {
    var backgroundColor:IMPColor {get set}
    var graphics:IMPGraphics! {get}
}

extension IMPGraphicsProvider{
    public var clearColor:MTLClearColor {
        get {
            let rgba = backgroundColor.rgba
            let color = MTLClearColor(red:   rgba.r.double,
                                      green: rgba.g.double,
                                      blue:  rgba.b.double,
                                      alpha: rgba.a.double)
            return color
        }
    }
}

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
            
            renderPipelineDescription.vertexDescriptor = self.vertexDescriptor 
            
            renderPipelineDescription.colorAttachments[0].pixelFormat = IMProcessing.colors.pixelFormat
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
        self._vertexDescriptor = vertexDescriptor        
    }
    
    lazy var _defaultVertexDescriptor:MTLVertexDescriptor = {
        var v = MTLVertexDescriptor()
        v.attributes[0].format = .Float3;
        v.attributes[0].bufferIndex = 0;
        v.attributes[0].offset = 0;
        v.attributes[1].format = .Float3;
        v.attributes[1].bufferIndex = 0;
        v.attributes[1].offset = sizeof(float3);  
        v.layouts[0].stride = sizeof(IMPVertex) 
        
        return v
    }()
    
    var _vertexDescriptor:MTLVertexDescriptor? 
    public var vertexDescriptor:MTLVertexDescriptor {
        return _vertexDescriptor ?? _defaultVertexDescriptor
    }     
}
