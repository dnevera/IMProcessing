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
    
    
    func transform(source:MTLTexture, orientation:IMPExifOrientation) -> MTLTexture? {
        
        guard let pipeline = graphics.pipeline else {return nil}
        
        var width  = source.width
        var height = source.height
        
        
        func swapSize() {
            width  = source.height
            height = source.width
        }
        
        switch orientation {
            
        case IMPExifOrientationHorizontalFlipped:
            transformer.reflectMode = (horizontal:.Mirroring, vertical:.None)
            
        case IMPExifOrientationLeft180:
            transformer.angle = IMPMatrixModel.degrees180

        case IMPExifOrientationVerticalFlipped:
            transformer.reflectMode = (horizontal:.None, vertical:.Mirroring)
            
        case IMPExifOrientationLeft90VertcalFlipped:
            swapSize()
            transformer.angle = IMPMatrixModel.left
            transformer.reflectMode = (horizontal:.Mirroring, vertical:.None)

        case IMPExifOrientationLeft90:
            swapSize()
            transformer.angle = IMPMatrixModel.right
            
        case IMPExifOrientationLeft90HorizontalFlipped:
            swapSize()
            transformer.angle = IMPMatrixModel.right
            transformer.reflectMode = (horizontal:.Mirroring, vertical:.None)
            
        case IMPExifOrientationRight90:
            swapSize()
            transformer.angle = IMPMatrixModel.left
            
        default:
            return source
        }
        
        
        if width != texture?.width || height != texture?.height{
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                source.pixelFormat,
                width: width, height: height,
                mipmapped: false)
            
            texture = self.context.device.newTextureWithDescriptor(descriptor)
        }

        guard let destination = texture else { return nil}
        
        context.execute(complete: true) { (commandBuffer) in
            self.transformer.render(commandBuffer, pipelineState: pipeline, source: source, destination: destination)
        }
        
        return texture
    }
    
    lazy var graphics:IMPGraphics = {
        return IMPGraphics(context:self.context, vertex: "vertex_transformation", fragment: "fragment_transformation")
    }()
    
    lazy var transformer:Transfromer = {
        return Transfromer(context: self.context, aspectRatio:1)
    }()
    
    
    // Plate is a cube with virtual depth == 0
    class Transfromer: IMPPlateNode {}
}