//
//  IMPRenderNode.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal
import IMProcessing

/// 3D Node rendering
public class IMPRenderNode: IMPContextProvider {
    
    public typealias MatrixModelHandler =  ((destination:IMPImageProvider, model:IMPMatrixModel, aspect:Float) -> Void)
    
    public var context:IMPContext!
    
    /// Angle in radians which node rotation in scene
    public var angle = float3(0) {
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Node scale
    public var scale = float3(1){
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Node transition
    public var transition = float2(0){
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Field of view in radians
    public var fovy:Float = M_PI.float/2{
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
   
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
        
        if let texture = destination.texture {
            
            let width  = texture.width
            let height = texture.height
            let depth  = texture.depth
            
            currentDestination = destination
            currentDestinationSize = MTLSize(width: width,height: height,depth:depth)
            
            renderPassDescriptor.colorAttachments[0].texture = destination.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .Clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
            renderPassDescriptor.colorAttachments[0].storeAction = .Store
            
            let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            
            renderEncoder.setCullMode(.Front)
            
            renderEncoder.setRenderPipelineState(pipelineState)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
            renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, atIndex: 1)
            
            renderEncoder.setFragmentTexture(source.texture, atIndex:0)
            
            renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: vertices.count/3)
            renderEncoder.endEncoding()
        }
    }
    
    public var vertices:[IMPVertex]! {
        didSet{
            var vertexData = [Float]()
            for vertex in vertices{
                vertexData += vertex.raw
            }
            vertexBuffer = context.device.newBufferWithBytes(vertexData, length: vertexData.count * sizeofValue(vertexData[0]), options: .CPUCacheModeDefaultCache)
        }
    }
    
    public final func addMatrixModelObserver(model observer:MatrixModelHandler){
        matrixModelObservers.append(observer)
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
    
    var currentDestinationSize = MTLSize(width: 1,height: 1,depth: 1) {
        didSet {
            if oldValue.width != currentDestinationSize.width ||
            oldValue.height != currentDestinationSize.height
            {
                updateMatrixModel(currentDestinationSize)
            }
        }
    }
    
    var currentDestination:IMPImageProvider?
    
    func updateMatrixModel(size:MTLSize) -> IMPMatrixModel  {
        
        var matrix = matrixIdentityModel
        
        let width = currentDestinationSize.width.float
        let height = currentDestinationSize.height.float
        
        matrix.setPerspective(radians: fovy, aspect: width/height, nearZ: 0, farZ: 1)
        matrix.scale(x: scale.x, y: scale.y, z: scale.z)
        matrix.rotateAround(x: angle.x, y: angle.y, z: angle.z)
        matrix.move(x: transition.x, y: transition.y)
        
        memcpy(matrixBuffer.contents(), &matrix, matrixBuffer.length)
        
        if let destination = currentDestination {
            let width = currentDestinationSize.width.float
            let height = currentDestinationSize.height.float
            for o in matrixModelObservers {
                o(destination: destination, model: matrix, aspect: width/height)
            }
        }
        
        return matrix
    }
    
    lazy var matrixBuffer: MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(IMPMatrixModel), options: .CPUCacheModeDefaultCache)
    }()
    
    var matrixModelObservers = [MatrixModelHandler]()
    
}
