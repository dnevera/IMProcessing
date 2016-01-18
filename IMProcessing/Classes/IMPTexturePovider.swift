//
//  IMPTexturePovider.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public protocol IMPTextureProvider{
    var texture:MTLTexture?{ get set }
    init(context:IMPContext)
}

public extension MTLDevice {
    
    public func texture1D(buffer:[Float], pixelFormat:MTLPixelFormat = .R32Float) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .Type1D
        weightsDescription.pixelFormat = pixelFormat
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.newTextureWithDescriptor(weightsDescription)
        texture.update(buffer)
        return texture
    }
    
    public func texture1DArray(buffers:[[Float]], pixelFormat:MTLPixelFormat = .R32Float) -> MTLTexture {
        
        let width = buffers[0].count
        
        for var i=1; i<buffers.count; i++ {
            if (width != buffers[i].count) {
                fatalError("texture buffers must have identical size...")
            }
        }

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .Type1DArray
        textureDescriptor.width       = width
        textureDescriptor.height      = 1
        textureDescriptor.depth       = 1
        textureDescriptor.pixelFormat = .R32Float
        
        textureDescriptor.arrayLength = buffers.count
        textureDescriptor.mipmapLevelCount = 1
        
        let texture = self.newTextureWithDescriptor(textureDescriptor)

        texture.update(buffers)
        
        return texture
    }
}

public extension MTLTexture {
    public func update(buffer:[Float]){
        self.replaceRegion(MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: sizeof(Float32)*buffer.count)
    }
    public func update(buffers:[[Float]]){
        let region = MTLRegionMake2D(0, 0, self.width, 1)
        let bytesPerRow = region.size.width * sizeof(Float32)
        
        for var index=0; index<buffers.count; index++ {
            let curve = buffers[index]
            self.replaceRegion(region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
        }
    }
}