//
//  IMPRenderNode.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import Metal
import QuartzCore
import IMProcessing
import GLKit

/// 3D Node rendering
public class IMPNode: IMPContextProvider {
    
    public var context:IMPContext!
    
    /// Angle in radians which node rotation in scene
    public var angle = float3(0)
    /// Node scale
    public var scale = float3(1)
    /// Node transition
    public var transition = float2(0)
    /// Field of view in radians
    public lazy var fovy:Float = M_PI.float/2
    /// Create Node
    public init(context: IMPContext, vertices: [IMPVertex]){
        self.context = context
        defer{
            self.vertices = vertices
        }
    }
    ///  Render node
    ///
    ///  - parameter commandBuffer: command buffer
    ///  - parameter pipelineState: graphics pipeline
    ///  - parameter source:        source texture
    ///  - parameter destination:   destination texture
    public func render(commandBuffer:  MTLCommandBuffer,
                       pipelineState: MTLRenderPipelineState,
                       source: IMPImageProvider,
                       destination: IMPImageProvider
        ) {
        
        let width = (destination.texture?.width.float)!
        let height = (destination.texture?.height.float)!
        
        matrixModel = matrixIdentityModel
        
        matrixModel.setPerspective(radians: fovy, aspect: width/height, nearZ: 0, farZ: 1)
        
        matrixModel.scale(x: scale.x, y: scale.y, z: scale.z)
        matrixModel.rotateAround(x: angle.x, y: angle.y, z: angle.z)
        matrixModel.move(x: transition.x, y: -transition.y)
        
        renderPassDescriptor.colorAttachments[0].texture = destination.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.setCullMode(MTLCullMode.Front)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, atIndex: 1)
        
        renderEncoder.setFragmentTexture(source.texture, atIndex:0)
        
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: vertices.count/3)
        renderEncoder.endEncoding()
    }
    
    var vertices:[IMPVertex]! {
        didSet{
            var vertexData = [Float]()
            for vertex in vertices{
                vertexData += vertex.raw
            }
            vertexBuffer = context.device.newBufferWithBytes(vertexData, length: vertexData.count * sizeofValue(vertexData[0]), options: .CPUCacheModeDefaultCache)
        }
    }
    
    var renderPassDescriptor = MTLRenderPassDescriptor()
    var vertexBuffer: MTLBuffer!
    
    var matrixIdentityModel:IMPMatrixModel {
        get{
            var m = IMPMatrixModel.identity
            m.translate(x: 0, y: 0, z: -1)
            return m
        }
    }
    
    lazy var matrixModel: IMPMatrixModel = {
        return self.matrixIdentityModel
    }()
    
    lazy var _matrixBuffer: MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(IMPMatrixModel), options: .CPUCacheModeDefaultCache)
    }()
    
    var matrixBuffer: MTLBuffer {
        get{
            memcpy(_matrixBuffer.contents(), &matrixModel, _matrixBuffer.length)
            return _matrixBuffer
        }
    }
}
