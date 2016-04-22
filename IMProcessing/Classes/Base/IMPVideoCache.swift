//
//  IMPVideoCache.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 04.03.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal
import AVFoundation
import CoreMedia

public class IMPVideoTextureCache {
    
    var reference:CVMetalTextureCache? {
        return videoTextureCache?.takeUnretainedValue()
    }
    
    init(context:IMPContext) {
        let textureCacheError = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, context.device, nil, &videoTextureCache);
        if textureCacheError != kCVReturnSuccess {
            fatalError("IMPVideoTextureCache error: couldn't create a texture cache...");
        }
    }
    
    func flush(){
        if let cache =  videoTextureCache?.takeUnretainedValue() {
            CVMetalTextureCacheFlush(cache, 0);
        }
    }
    
    var videoTextureCache: Unmanaged<CVMetalTextureCache>?
    
    deinit {
        if videoTextureCache != nil {
            videoTextureCache?.release()
        }
    }
}


