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
    
    public func texture1D(buffer:[Float]) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .Type1D
        weightsDescription.pixelFormat = .R32Float
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.newTextureWithDescriptor(weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture1D(buffer:[UInt8]) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .Type1D
        weightsDescription.pixelFormat = .R8Uint
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.newTextureWithDescriptor(weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture2D(buffer:[[UInt8]]) -> MTLTexture {
        let width = buffer[0].count
        let weightsDescription = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.R8Unorm, width: width, height: buffer.count, mipmapped: false)
        let texture = self.newTextureWithDescriptor(weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture1DArray(buffers:[[Float]]) -> MTLTexture {
        
        let width = buffers[0].count
        
        for i in 1 ..< buffers.count {
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
        if pixelFormat != .R32Float {
            fatalError("MTLTexture.update(buffer:[Float]) has wrong pixel format...")
        }
        if width != buffer.count {
            fatalError("MTLTexture.update(buffer:[Float]) is not equal texture size...")
        }
        self.replaceRegion(MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: sizeof(Float32)*buffer.count)
    }

    public func update(buffer:[UInt8]){
        if pixelFormat != .R8Uint {
            fatalError("MTLTexture.update(buffer:[UInt8]) has wrong pixel format...")
        }
        if width != buffer.count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        self.replaceRegion(MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: sizeof(UInt8)*buffer.count)
    }

    public func update(buffer:[[UInt8]]){
        if pixelFormat != .R8Unorm {
            fatalError("MTLTexture.update(buffer:[UInt8]) has wrong pixel format...")
        }
        if width != buffer[0].count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        if height != buffer.count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        for i in 0 ..< height {
            self.replaceRegion(MTLRegionMake2D(0, i, width, 1), mipmapLevel: 0, withBytes: buffer[i], bytesPerRow: width)
        }
    }
    
    public func update(buffers:[[Float]]){
        if pixelFormat != .R32Float {
            fatalError("MTLTexture.update(buffer:[[Float]]) has wrong pixel format...")
        }
        
        let region = MTLRegionMake2D(0, 0, width, 1)
        let bytesPerRow = region.size.width * sizeof(Float32)
        
        for index in 0 ..< buffers.count {
            let curve = buffers[index]
            if width != curve.count {
                fatalError("MTLTexture.update(buffer:[[Float]]) is not equal texture size...")
            }
            self.replaceRegion(region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
        }
    }
}