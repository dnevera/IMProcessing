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


public extension float4x4 {
    public mutating func move(x x:Float, y: Float){
        self = float4x4([
            float4(1, 0, 0, x),
            float4(0, 1, 0, y),
            float4(0, 0, 1, 0),
            float4(0, 0, 0, 1)])
    }
}

//class IMPMatrix {
//    var projection:float4x4
//    var transform:float4x4
//}


public class IMPNode: IMPContextProvider {
    
    public var context:IMPContext!
    
    public var angle = float3(0)
    public var scale = float3(1)
    public var transition = float2(0)

    var translation = float3(0)

    public init(context: IMPContext, vertices: [IMPVertex]){
        self.context = context
        matrixBuffer = context.device.newBufferWithLength(sizeof(IMPMatrixModel), options: .CPUCacheModeDefaultCache)
        defer{
            self.vertices = vertices
        }
    }
    
    public func render(commandBuffer:  MTLCommandBuffer,
                pipelineState: MTLRenderPipelineState,
                source: IMPImageProvider,
                destination: IMPImageProvider
        ) {
        
        let width = (destination.texture?.width.float)!
        let height = (destination.texture?.height.float)!
        
        let projectionMatrix = Matrix4.makePerspectiveViewAngle(fovy, aspectRatio: width/height, nearZ: 0, farZ: 1)
        
        let nodeModelMatrix = self.modelMatrix()
        
        transitionMatrix.move(x: transition.x, y: transition.y)

        matrixBuffer = context.device.newBufferWithLength(sizeof(Float) * Matrix4.numberOfElements() * 2 * sizeofValue(transitionMatrix.cmatrix), options: .CPUCacheModeDefaultCache)
        
        let bufferPointer = matrixBuffer.contents()
        memcpy(bufferPointer, nodeModelMatrix.raw(), sizeof(Float)*Matrix4.numberOfElements())
        memcpy(bufferPointer + sizeof(Float)*Matrix4.numberOfElements(), projectionMatrix.raw(), sizeof(Float)*Matrix4.numberOfElements())
        
        var m = transitionMatrix.cmatrix
        
        memcpy(bufferPointer + 2*sizeof(Float)*Matrix4.numberOfElements(), &m, sizeofValue(transitionMatrix.cmatrix))
        
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
    
    lazy var fovy:Float = {
        return M_PI.float/2
    }()

    var renderPassDescriptor = MTLRenderPassDescriptor()

    var vertexBuffer: MTLBuffer!
    var matrixBuffer: MTLBuffer
    
    var transitionMatrix = float4x4(diagonal:float4(1))
    
    func modelMatrix() -> Matrix4 {
        let matrix = Matrix4()
        matrix.translate(0, y: 0, z: -1.1002)
        matrix.rotateAroundX(angle.x, y: angle.y, z: angle.z)
        matrix.scale(scale.x, y: scale.y, z: scale.z)
        return matrix
    }
    
}
