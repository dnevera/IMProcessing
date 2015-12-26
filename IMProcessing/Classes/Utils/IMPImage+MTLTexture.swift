//
//  IMPImage+Metal.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import Metal
import Accelerate

extension IMPImage{
    
    #if os(iOS)
    
    public convenience init(image: IMPImage, size:IMPSize){
    let scale = min(size.width/image.size.width, size.height/image.size.height)
    self.init(CGImage: image.CGImage!, scale:1.0/scale, orientation:image.imageOrientation)
    }
    
    #else
    
    public convenience init(image: IMPImage, size:IMPSize){
        self.init(CGImage: image.CGImage!, size:size)
    }
    
    #endif
    
    func newTexture(context:IMPContext, maxSize:Float = 0) -> MTLTexture? {
        
        let imageRef  = self.CGImage
        let imageSize = self.size
        
        var imageAdjustedSize = IMPContext.sizeAdjustTo(size: imageSize)
        
        //
        // downscale acording to GPU hardware limit size
        //
        var width  = Float(floor(imageAdjustedSize.width))
        var height = Float(floor(imageAdjustedSize.height))
        
        var scale = Float(1.0)
        
        if (maxSize > 0 && (maxSize < width || maxSize < height)) {
            scale = fmin(maxSize/width,maxSize/height)
            width  *= scale
            height *= scale
            imageAdjustedSize = CGSize(width: width, height: height)
        }
        
        let image = IMPImage(image: self, size:imageAdjustedSize)
        
        width  = Float(floor(image.size.width))
        height = Float(floor(image.size.height))
        
        let resultWidth  = Int(width)
        let resultHeight = Int(height)
        
        
        let rawData  = calloc(resultHeight * resultWidth * 4, sizeof(UInt8))
        let componentsPerPixel = 4
        let componentsPerRow   = componentsPerPixel * resultWidth
        let bitsPerComponent   = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrder32Big.rawValue)
        
        let bitmapContext = CGBitmapContextCreate(rawData, resultWidth, resultHeight,
            bitsPerComponent, componentsPerRow, colorSpace, bitmapInfo.rawValue)
        
        CGContextDrawImage(bitmapContext, CGRectMake(0, 0, CGFloat(resultWidth), CGFloat(resultHeight)), imageRef)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(IMProcessing.colors.pixelFormat,
            width:resultWidth,
            height:resultHeight,
            mipmapped:false)
        
        let texture = context.device?.newTextureWithDescriptor(textureDescriptor)
        
        if let t = texture {
            let region = MTLRegionMake2D(0, 0, resultWidth, resultHeight)
            
            if IMProcessing.colors.pixelFormat == .RGBA16Unorm {
                var u16:[UInt16] = [UInt16](count: componentsPerRow*resultHeight, repeatedValue: 0)
                for var i=0; i < componentsPerRow*resultHeight; i++ {
                    var pixel = UInt16()
                    let address = UnsafePointer<UInt8>(rawData)+i
                    memcpy(&pixel, address, sizeof(UInt8))
                    u16[i] = pixel<<8
                }
                t.replaceRegion(region, mipmapLevel:0, withBytes:u16, bytesPerRow:componentsPerRow*sizeof(UInt16)/sizeof(UInt8))
            }
            else {
                t.replaceRegion(region, mipmapLevel:0, withBytes:rawData, bytesPerRow:componentsPerRow)
            }
        }
        
        free(rawData)
        
        return texture
    }
}

public extension IMPImage{
    
    convenience init (provider: IMPImageProvider){
        var imageRef:CGImageRef?
        var width  = 0
        var height = 0
        
        if let texture = provider.texture {
            width  = texture.width
            height = texture.height
            
            let bytesPerRow     = width * 4
            let imageByteCount  = bytesPerRow * height
            let imageBytes      = malloc(imageByteCount)
            
            let region = MTLRegionMake2D(0, 0, width, height)
            
            texture.getBytes(imageBytes, bytesPerRow:bytesPerRow, fromRegion:region, mipmapLevel:0)
            
            let cgprovider = CGDataProviderCreateWithData(nil, imageBytes, imageByteCount, nil)
            
            let bitsPerComponent = 8
            
            //if texture.pixelFormat == .RGBA16Unorm {
            //    bitsPerComponent = 16
            //}
            
            let bitsPerPixel     = bitsPerComponent * 4
            
            let colorSpaceRef  = CGColorSpaceCreateDeviceRGB();
            
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrder32Big.rawValue)
            
            imageRef = CGImageCreate(width,
                height,
                bitsPerComponent,
                bitsPerPixel,
                bytesPerRow,
                colorSpaceRef,
                bitmapInfo,
                cgprovider,
                nil,
                false,
                .RenderingIntentDefault)
            
            free(imageBytes)
        }
        self.init(CGImage: imageRef!, size: IMPSize(width: width, height: height))
    }
    
    #if os(OSX)
    public func saveAsJpeg(fileName fileName:String){
        // Cache the reduced image
        if var imageData = self.TIFFRepresentation{
            let imageRep = NSBitmapImageRep(data: imageData)
            let imageProps = [NSImageCompressionFactor: 1]
            imageData =  (imageRep?.representationUsingType(.NSJPEGFileType, properties: imageProps))!
            imageData.writeToFile(fileName, atomically:true)
        }
    }

    #endif
    
}