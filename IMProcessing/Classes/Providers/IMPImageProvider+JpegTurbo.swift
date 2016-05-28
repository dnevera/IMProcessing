//
//  IMPImageProvider+JpegTurbo.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 21.05.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation

public class IMPJpegProvider:IMPImageProvider{

    public convenience init(context: IMPContext, file: String, maxSize: Float = 0, orientation:IMPExifOrientation = IMPExifOrientationUp) throws {
        self.init(context: context)
        try self.updateFromJpeg(file: file, maxSize: maxSize, orientation: orientation)
    }
    
    
    public func updateFromJpeg(file file:String, maxSize: Float = 0, orientation:IMPExifOrientation = IMPExifOrientationUp) throws {
        let source = try IMPJpegturbo.updateMTLTexture(texture,
                                                    withPixelFormat: IMProcessing.colors.pixelFormat,
                                                    withDevice: context.device,
                                                    fromFile: file,
                                                    maxSize: maxSize.cgfloat
        )
        
        texture = transform(source, orientation: orientation)
        
        self.orientation = .Up
        
        completeUpdate()
    }
    
 }