//
//  IMPGHistogramAnalizer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 07.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing


public class IMPGHistogramAnalizer: IMPFilter {
    
    public lazy var blender:IMPBlender = {
        let b = IMPBlender(context: self.context, vertex: "vertex_blending", fragment: "fragment_blending")
        return b
    }()
    
    public required init(context: IMPContext){
        super.init(context: context)
    }
    
    public var histogram = [UInt8](count: 256, repeatedValue:0)
    var bytes:[UInt8]!
    
    override public func main(source source: IMPImageProvider, destination provider: IMPImageProvider) -> IMPImageProvider {
        self.context.execute { (commandBuffer) -> Void in
            if let inputTexture = source.texture {
                
                let size = inputTexture.width * inputTexture.height

                if size * 4 != self.buffer?.length {
                    self.buffer = self.context.device.newBufferWithLength(size * 4, options: .CPUCacheModeDefaultCache)
                }

                
                let blit = commandBuffer.blitCommandEncoder()
                
                #if os(OSX)
                    blit.synchronizeResource(inputTexture)
                #endif
                
                blit.copyFromTexture(
                    inputTexture,
                    sourceSlice: 1,
                    sourceLevel: 0,
                    sourceOrigin:  MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSizeMake(inputTexture.width, inputTexture.height, 1),
                    toBuffer: self.buffer!,
                    destinationOffset: 0,
                    destinationBytesPerRow: inputTexture.width * 4, destinationBytesPerImage: 0)
                
                #if os(OSX)
                    blit.synchronizeResource(self.buffer!)
                #endif
                
                blit.endEncoding()
            }
        }
        
        self.context.execute { (commandBuffer) -> Void in
            if let inputTexture = source.texture {
                
                let size = inputTexture.width * inputTexture.height
                
                
                var width:Float  = 256
                var height:Float = 1
                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        .R8Uint,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                self.renderPassDescriptor.colorAttachments[0].texture = provider.texture
                self.renderPassDescriptor.colorAttachments[0].loadAction = .Clear
                self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                
                let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)
                
                renderEncoder.setCullMode(.None)
                
                renderEncoder.setRenderPipelineState(self.blender.pipeline!)
                renderEncoder.setVertexBuffer(self.buffer, offset: 0, atIndex: 0)
                renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: size)
                renderEncoder.endEncoding()
                
                #if os(OSX)
                    let blit = commandBuffer.blitCommandEncoder()
                    blit.synchronizeResource(provider.texture!)
                    blit.endEncoding()
                #endif
            }
        }
        
        provider.texture?.getBytes(&histogram, bytesPerRow: histogram.count, fromRegion: MTLRegionMake2D(0, 0, 256, 1), mipmapLevel: 0)
        
        return provider
    }
    
    var buffer:MTLBuffer?
    
    lazy var renderPassDescriptor:MTLRenderPassDescriptor = {
        return MTLRenderPassDescriptor()
    }()
    
}
