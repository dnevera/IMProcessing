//
//  IMPRender.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal

public class IMPRender: IMPFilter {

    public var keepAspectRatio = true
    
    public var transform = IMPTransform() {
        didSet {
            NSLog(" ### IMPRender transform = \(transform)")
            dirty = true
        }
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        self.context.execute { (commandBuffer) -> Void in

            if let inputTexture = source.texture {
                
                var width  = inputTexture.width.float
                var height = inputTexture.height.float
                
                
                let region = self.transform.cropRegion
                
                width  -= width  * (region.left   + region.right)
                height -= height * (region.bottom + region.top)
                
                self.aspectRatio = self.keepAspectRatio ? height/width : 1
                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        inputTexture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                    
                    self.renderPassDescriptor.colorAttachments[0].texture     = provider.texture
                    self.renderPassDescriptor.colorAttachments[0].loadAction  = .Clear
                    self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                    self.renderPassDescriptor.colorAttachments[0].clearColor =  MTLClearColorMake(1.0, 1.0, 1.0, 0.0)
                }
                
                
                let renderCommand = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)

                //
                // render current texture
                //
                
                renderCommand.setRenderPipelineState(self.graphics.pipeline!)
                
                renderCommand.setVertexBuffer(self.vertexBuffer,     offset:0, atIndex:0)
                renderCommand.setVertexBuffer(self.transformBuffer,  offset:0, atIndex:1)
                renderCommand.setVertexBuffer(self.orthoMatrixBuffer,offset:0, atIndex:2)
                renderCommand.setFragmentTexture(source.texture, atIndex:0)
                
                renderCommand.drawPrimitives(.TriangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
                
                renderCommand.endEncoding()
            }
        }
        return provider
    }
    
    public var graphics:IMPGraphics!

    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_passthrough", fragment: "fragment_passthrough")
    }
    
    var aspectRatio:Float = 1
    
    lazy var _vertexBuffer:MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(Float)*16, options: .CPUCacheModeDefaultCache)
    }()
    var vertexBuffer:MTLBuffer{
        get{
            let region = transform.cropRegion
            let data:[Float] = [
                //x     y                         cordx                              coordy
                -1.0,  -1.0*aspectRatio, /*left bottom*/     +region.left, /*left offset*/  1.0-region.bottom, /* bottom offset*/
                +1.0,  -1.0*aspectRatio, /*right bottom*/ 1.0-region.right,/*right offset*/ 1.0-region.bottom, /* bottom offset*/
                -1.0,  +1.0*aspectRatio, /*left top*/        +region.left, /*left offset*/     +region.top,    /* top offset*/
                +1.0,  +1.0*aspectRatio, /*right top*/    1.0-region.right,/*right offset*/    +region.top,    /* top offset*/
            ]
            memcpy(_vertexBuffer.contents(), data, _vertexBuffer.length)
            return _vertexBuffer
        }
    }
    
    var orthoMatrix:float4x4 {
        get {
            let bottom:Float = -1.0
            let top:Float    = 1.0
            let left:Float   = (-1.0 * aspectRatio)
            let right:Float  = (1.0 * aspectRatio)
            
            let near:Float = -1.0
            let far:Float = 1.0
            let r_l:Float = right - left
            let t_b:Float = top - bottom
            let f_n:Float = far - near
            let tx:Float = -(right + left) / (right - left)
            let ty:Float = -(top + bottom) / (top - bottom)
            let tz:Float = -(far + near) / (far - near)
            
            let scale:Float = 2.0
            
            let matrix = float4x4(rows:[
                float4( scale / t_b, 0,           0,           tx),
                float4( 0,           scale / r_l, 0,           ty),
                float4( 0,           0,           scale / f_n, tz),
                float4( 0,           0,           0,            1),
                ])
                        
            return matrix;
        }
    }

    lazy var _orthoMatrixBuffer:MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(float4x4), options: .CPUCacheModeDefaultCache)
    }()
    var orthoMatrixBuffer:MTLBuffer{
        get{
            var matrix = orthoMatrix.cmatrix
            memcpy(_orthoMatrixBuffer.contents(), &matrix , _orthoMatrixBuffer.length)
            return _orthoMatrixBuffer
        }
    }
    
    lazy var _transformBuffer:MTLBuffer = {
        return self.context.device.newBufferWithLength(sizeof(IMPTransformIn), options: .CPUCacheModeDefaultCache)
    }()
    var transformBuffer:MTLBuffer{
        get{
            memcpy(_transformBuffer.contents(), &transform.encoder , _transformBuffer.length)
            return _transformBuffer
        }
    }
    
    var renderPassDescriptor = MTLRenderPassDescriptor()
    
}