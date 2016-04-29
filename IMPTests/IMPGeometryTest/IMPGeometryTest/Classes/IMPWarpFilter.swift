//
//  IMPWarpPerspectiveFilter.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


import IMProcessing
import Metal

let m2:float4x4 = float4x4([
    [0.43733375058676266,	0,	0,	-0.0010779046923625236],
    [0,	0.9529025191675795,	0,	-0.00027382256297918953],
    [0,	0,	1,	0],
    [0,	0,	0,	1]
    ]
)

//let m2:float4x4 = float4x4(rows:[
//    [1.0019157088122606,	0,	0,	0],
//    [0,	1.0019157088122606,	0,	0.000011137841931747305],
//    [0,	0,	1,	0],
//    [0,	0,	0,	1]
//    ]
//)

//let m2:float4x4 = float4x4(rows:[
//    [0.707, 0.586, 1.0, 1],
//    [0.707, 0.242, 1.0, 1],
//    [1.0, 1.0, 1.0, 1],
//    [1.0, 1.0, 1.0, 1]
//    ]
//)



public class IMPWarpFilter: IMPFilter {
    
    public var sourceQuad = IMPQuad() {
        didSet{
            solver.source = sourceQuad
            dirty = true
        }
    }
    
    public var destinationQuad = IMPQuad() {
        didSet{
            solver.destination = destinationQuad
            dirty = true
        }
    }
    
    public var graphics:IMPGraphics!
    
    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_warpTransformation", fragment: "fragment_warpTransformation")
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                var width  = texture.width.float
                var height = texture.height.float
                                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        texture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                self.renderPassDescriptor.colorAttachments[0].texture = provider.texture
                self.renderPassDescriptor.colorAttachments[0].loadAction = .Clear
                self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
                self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                
                let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)
                
                renderEncoder.setCullMode(MTLCullMode.Front)
                
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
    
    var solver = IMPWarpSolver(source: IMPQuad(), destination: IMPQuad())
    
    lazy var _matrixBuffer:MTLBuffer = {
        return  self.context.device.newBufferWithLength(sizeofValue(self.solver.transformation), options: .CPUCacheModeDefaultCache)
    }()

    var matrixBuffer: MTLBuffer {
        get {
            var m = self.solver.transformation
            memcpy(_matrixBuffer.contents(), &m, _matrixBuffer.length)
            return _matrixBuffer
        }
    }
    
    lazy var vertexBuffer: MTLBuffer = {
        var vertexData = [Float]()
        for vertex in self.vertices{
            vertexData += vertex.raw
        }
        return self.context.device.newBufferWithBytes(vertexData, length: vertexData.count * sizeofValue(vertexData[0]), options: .CPUCacheModeDefaultCache)
    }()
    
    lazy var vertices:[IMPVertex] = {
        // Front
        let A = IMPVertex(x: -1, y:   1, z:  0, tx: 0,    ty: 0) // left-top
        let B = IMPVertex(x: -1, y:  -1, z:  0, tx: 0,    ty: 1) // left-bottom
        let C = IMPVertex(x:  1, y:  -1, z:  0, tx: 1, ty: 1)    // right-bottom
        let D = IMPVertex(x:  1, y:   1, z:  0, tx: 1, ty: 0)    // right-top
        return [
            A,B,C ,A,C,D,   // The main front plate. Here we put image.
        ]
    }()
}