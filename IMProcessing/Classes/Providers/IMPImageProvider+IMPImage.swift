//
//  IMPImageProvider+IMPImage.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public extension IMPExifOrientation{
    init(rawValue:Int){
        self.rawValue = UInt32(rawValue)
    }
}

public extension IMPImageProvider{
    
    public convenience init(context: IMPContext, image: IMPImage, maxSize: Float = 0) {
        self.init(context: context)
        self.update(image: image, maxSize: maxSize)
    }
    
    public func update(image image:IMPImage, maxSize: Float = 0){
        texture = image.newTexture(context, maxSize: maxSize)
        #if os(iOS)
            self.orientation = image.imageOrientation
        #endif
        completeUpdate()
    }
    
    public func writeToJpeg(path:String, compression compressionQ:Float) throws {
        if let t = texture {
            var error:NSError?
            IMPJpegturbo.writeMTLTexture(t, toJpegFile: path, compression: compressionQ.cgfloat, error: &error)
            if error != nil {
                throw error!
            }
        }
    }
}