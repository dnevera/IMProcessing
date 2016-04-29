//
//  IMPWarpPerspectiveFilter.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation


let m2 = [
    0.7649962742175858,	0,	0,	-0.0004501987083954297,
    0,	0.9319113263785396,	0,	-0.0003958643815201192,
    0,	0,	1,	0,
    0,	0,	0,	1]


import IMProcessing
import Metal

public class IMPWarpPerspectiveFilter: IMPFilter {
    
    public var region = IMPRegion() {
        didSet{
            dirty = true
        }
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                let blit = commandBuffer.blitCommandEncoder()
                
                let w = texture.width
                let h = texture.height
                let d = texture.depth
                
                let oroginSource = MTLOrigin(x: (self.region.left * w.float).int, y: (self.region.top * h.float).int, z: 0)
                
                let destinationSize = MTLSize(
                    width: (self.region.rectangle.width.float * w.float).int,
                    height: (self.region.rectangle.height.float * h.float).int, depth: d)
                
                
                if destinationSize.width != provider.texture?.width || destinationSize.height != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        texture.pixelFormat,
                        width: destinationSize.width, height: destinationSize.height,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                blit.copyFromTexture(
                    texture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: oroginSource,
                    sourceSize: destinationSize,
                    toTexture: provider.texture!,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: MTLOrigin(x:0,y:0,z:0))
                
                //blit.synchronizeResource(provider.texture!)
                
                blit.endEncoding()
            }
        }
        return provider
    }
}