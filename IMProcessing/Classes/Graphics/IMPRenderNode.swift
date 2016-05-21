//
//  IMPRenderNode.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// 3D Node rendering
public class IMPRenderNode: IMPContextProvider {
    
    public enum ReflectMode {
        case Mirroring
        case None
    }    
    
    public var backgroundColor:IMPColor = IMPColor.whiteColor()    
    
    public typealias MatrixModelHandler =  ((destination:IMPImageProvider, model:IMPMatrixModel, aspect:Float) -> Void)
    
    public var context:IMPContext!
    
    public var aspect = Float(1) {
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
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
    
    /// Flip mode
    public var reflectMode:(horizontal:ReflectMode, vertical:ReflectMode) = (horizontal:.None, vertical:.None) {
        didSet{
            switch reflectMode.horizontal {
            case .Mirroring:
                reflectionVector.x =  1
                reflectionVector.y = -1
            default:
                reflectionVector.x =  0
                reflectionVector.y =  1
            }
            switch reflectMode.vertical {
            case .Mirroring:
                reflectionVector.z =  1
                reflectionVector.w = -1
            default:
                reflectionVector.z =  0
                reflectionVector.w =  1                
            }
        }
    }
   
    /// Create Node
    public init(context: IMPContext, vertices: IMPVertices){
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
        currentDestination = destination
        if let input = source.texture {
            if let texture = destination.texture {
                render(commandBuffer, pipelineState: pipelineState, source: input, destination: texture)
            }
        }
     }
    
    public func render(commandBuffer:  MTLCommandBuffer,
                       pipelineState: MTLRenderPipelineState,
                       source: MTLTexture,
                       destination: MTLTexture
        ) {
        
        
        let width  = destination.width
        let height = destination.height
        let depth  = destination.depth
        
        currentDestinationSize = MTLSize(width: width,height: height,depth:depth)
        
        renderPassDescriptor.colorAttachments[0].texture = destination
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        
        renderEncoder.setCullMode(.Front)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, atIndex: 1)
        
        renderEncoder.setFragmentBuffer(flipVectorBuffer, offset: 0, atIndex: 0)
        renderEncoder.setFragmentTexture(source, atIndex:0)
        
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: vertices.count/3)
        renderEncoder.endEncoding()
    }
    
    
    public var vertices:IMPVertices! {
        didSet{
            vertexBuffer = context.device.newBufferWithBytes(vertices.raw, length: vertices.length, options: .CPUCacheModeDefaultCache)
        }
    }
    
    public final func addMatrixModelObserver(model observer:MatrixModelHandler){
        matrixModelObservers.append(observer)
    }

    lazy var renderPassDescriptor:MTLRenderPassDescriptor = {
        return MTLRenderPassDescriptor()                
    }()
    
    
    var clearColor:MTLClearColor {
        get {
            let rgba = backgroundColor.rgba
            let color = MTLClearColor(red:   rgba.r.double,
                                 green: rgba.g.double,
                                 blue:  rgba.b.double,
                                 alpha: rgba.a.double)
            return color
        }
    }
    
    var vertexBuffer: MTLBuffer!
    
    var matrixIdentityModel:IMPMatrixModel {
        get{
            var m = IMPMatrixModel.identity
            m.translate(x: 0, y: 0, z: -1)
            return m
        }
    }
    
    var reflectionVector = float4(0,1,0,1)
    
    lazy var _reflectionVectorBuffer:MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(float4), options: .CPUCacheModeDefaultCache)
    }()
    
    var flipVectorBuffer:MTLBuffer {
        memcpy(_reflectionVectorBuffer.contents(), &reflectionVector, _reflectionVectorBuffer.length)
        return _reflectionVectorBuffer
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
        
        matrix.setPerspective(radians: fovy, aspect: aspect, nearZ: 0, farZ: 1)

        matrix.scale(x: scale.x, y: scale.y, z: scale.z)
        matrix.rotateAround(x: angle.x, y: angle.y, z: angle.z)
        matrix.move(x: transition.x, y: transition.y)
                
        memcpy(matrixBuffer.contents(), &matrix, matrixBuffer.length)
        
        if let destination = currentDestination {
            for o in matrixModelObservers {
                o(destination: destination, model: matrix, aspect: aspect)
            }
        }
        
        return matrix
    }
    
    lazy var matrixBuffer: MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(IMPMatrixModel), options: .CPUCacheModeDefaultCache)
    }()
    
    var matrixModelObservers = [MatrixModelHandler]()
    
}
