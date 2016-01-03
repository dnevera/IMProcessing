//
//  IMPImageProvider+IMPImage.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

extension IMPImageProvider{
    
    public convenience init(context: IMPContext, image: IMPImage, maxSize: Float = 0) {
        self.init(context: context)
        self.update(image: image, maxSize: maxSize)
    }

    public convenience init(context: IMPContext, file: String, maxSize: Float = 0) throws {
        self.init(context: context)
        try self.update(file: file, maxSize: maxSize)
    }

    public func update(image image:IMPImage, maxSize: Float = 0){
        texture = image.newTexture(context, maxSize: maxSize)
        #if os(iOS)
            self.orientation = image.imageOrientation
        #endif
    }
    
    public func update(file file:String, maxSize: Float = 0) throws {
        texture = try IMPJpegturbo.updateMTLTexture(texture, withPixelFormat: IMProcessing.colors.pixelFormat, withDevice: context.device, fromFile: file, maxSize: maxSize.cgloat)
    }
}