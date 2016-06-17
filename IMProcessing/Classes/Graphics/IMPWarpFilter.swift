//
//  IMPWarpPerspectiveFilter.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


import Metal

/// Warp transformation filter
public class IMPWarpFilter: IMPFilter, IMPGraphicsProvider {
    
    public var model:float4x4 {
        return transformation
    }

    /// Source image quad
    public var sourceQuad = IMPQuad() {
        didSet{
            transformation = sourceQuad.transformTo(destination: destinationQuad)
            dirty = true
        }
    }
    
    /// Destination image quad
    public var destinationQuad = IMPQuad() {
        didSet{
            transformation = sourceQuad.transformTo(destination: destinationQuad)
            dirty = true
        }
    }
    
    public var backgroundColor:IMPColor = IMPColor.whiteColor()
    
    /// Graphic function
    public var graphics:IMPGraphics!
    
    /// Create Warp with new graphic function
    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_warpTransformation", fragment: "fragment_passthrough")
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider? {
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                var width  = texture.width.float
                var height = texture.height.float
                                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        texture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                self.renderPassDescriptor.colorAttachments[0].texture = provider.texture
                self.renderPassDescriptor.colorAttachments[0].loadAction = .Clear
                self.renderPassDescriptor.colorAttachments[0].clearColor = self.clearColor
                self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                
                let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)
                                
                renderEncoder.setRenderPipelineState(self.graphics.pipeline!)
                
                renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, atIndex: 0)
                renderEncoder.setVertexBuffer(self.matrixBuffer, offset: 0, atIndex: 1)
                
                renderEncoder.setFragmentTexture(source.texture, atIndex:0)
                
                renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: self.vertices.count, instanceCount: self.vertices.count/3)
                renderEncoder.endEncoding()
            }
        }
        return provider
    }
    
    var renderPassDescriptor = MTLRenderPassDescriptor()
    
    var transformation = float4x4(diagonal:float4(1)){
        didSet{
            var m = transformation.cmatrix
            memcpy(_matrixBuffer.contents(), &m, _matrixBuffer.length)
        }
    }
    
    lazy var _matrixBuffer:MTLBuffer = {
        var m = self.transformation.cmatrix
        var mm = self.context.device.newBufferWithLength(sizeofValue(self.transformation.cmatrix), options: .CPUCacheModeDefaultCache)
        memcpy(mm.contents(), &m, mm.length)
        return mm
    }()

    var matrixBuffer: MTLBuffer {
        get {
            return _matrixBuffer
        }
    }
    
    lazy var vertices = IMPPhotoPlate(aspect: 1, region: IMPRegion())
    
    lazy var vertexBuffer: MTLBuffer = {
        return self.context.device.newBufferWithBytes(self.vertices.raw, length: self.vertices.length, options: .CPUCacheModeDefaultCache)
    }()
}