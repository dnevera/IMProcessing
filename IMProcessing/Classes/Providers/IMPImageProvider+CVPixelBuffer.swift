//
//  IMPImageProvider+CVPixelBuffer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 04.03.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMedia
import Metal

public extension IMPImageProvider{
    
    public convenience init(context: IMPContext, pixelBuffer: CVPixelBufferRef) {
        self.init(context: context)
        #if os(iOS)
            //
            // Pixelbuffer from camera always is Left
            //
            orientation = .Left
        #endif
        update(pixelBuffer: pixelBuffer)
    }
    
    public func update(pixelBuffer pixelBuffer:CVPixelBufferRef) {
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var textureRef:Unmanaged<CVMetalTextureRef>?
        
        let error = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoCache.reference!, pixelBuffer, nil, .BGRA8Unorm, width, height, 0, &textureRef)
        
        if error != kCVReturnSuccess {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
        
        if let ref = textureRef?.takeUnretainedValue() {
            
            if let t = CVMetalTextureGetTexture(ref) {
                texture = t
            }
            else {
                fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
            }
            
            textureRef?.release()
        }
    }
}