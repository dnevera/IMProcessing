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

extension MTLDevice {
    func texture1D(buffer:[Float], pixelFormat:MTLPixelFormat = .R32Float) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .Type1D
        weightsDescription.pixelFormat = pixelFormat
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.newTextureWithDescriptor(weightsDescription)
        texture.replaceRegion(MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: sizeof(Float32)*buffer.count)
        return texture
    }
}