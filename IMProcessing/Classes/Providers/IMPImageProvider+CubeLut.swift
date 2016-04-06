//
//  IMPImageProvider+CubeLUT.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import simd

public enum IMPLutType{
    case D1D
    case D3D
    case UNKNOOWN
}

public enum IMPLutStatus:Int{
    case OK          = 0
    case NOT_FOUND
    case WRONG_FORMAT
    case WRANG_RANGE
    case OUT_RANGE
    case UNKNOWN
}

public extension IMPImageProvider{
    
    public struct LutDescription {
        public var type = IMPLutType.UNKNOOWN
        public var title = String("")
        public var domainMin = float3(0)
        public var domainMax = float3(1)
        public var lut3DSize = Int(0)
        
        public init(){}
    }
    
    public convenience init(context: IMPContext, cubeFile:String, inout description:LutDescription) throws {
        self.init(context: context)
        do{
            description = try update(cubeFile: cubeFile)
        }
        catch let error as NSError {
            throw error
        }
    }
    
    public convenience init(context: IMPContext, cubeName:String, inout description:LutDescription) throws {
        let path = NSBundle.mainBundle().pathForResource(cubeName, ofType:".cube")
        self.init(context: context)
        do{
            description = try update(cubeFile: path!)
        }
        catch let error as NSError {
            throw error
        }
    }
    
    public func update(cubeFile cubeFile:String) throws ->  LutDescription {
        
        let manager = NSFileManager.defaultManager()
        var description = LutDescription()
        
        if manager.fileExistsAtPath(cubeFile){
            
            do{
                let contents = try String(contentsOfFile: cubeFile, encoding: NSUTF8StringEncoding)
                
                let lines = contents.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
                var linenum=0
                
                var dataBytes = NSMutableData()
                var isData = false
                
                for line in lines {
                    linenum += 1
                    var words = line.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                    
                    if line.hasPrefix("#") || words[0].characters.count==0 {
                        continue;
                    }
                    else{
                        if (words.count>1) {
                            let what = updateBytes(&words, isData: &isData, dataBytes: &dataBytes, description: &description)
                            if what == .OK  {
                                continue
                            }
                            else{
                                switch what {
                                case .OUT_RANGE:
                                    throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                                        code: what.rawValue,
                                        userInfo: [
                                            NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file has out of range value in in line: %i", comment:""), linenum),
                                            NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file has out of ramge value", comment:""))
                                        ])
                                case .WRONG_FORMAT:
                                    throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                                        code: what.rawValue,
                                        userInfo: [
                                            NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file format error in line: %i", comment:""), linenum),
                                            NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file format error", comment:""))
                                        ])
                                default:
                                    throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                                        code: IMPLutStatus.UNKNOWN.rawValue,
                                        userInfo: [
                                            NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file format error in line: %i", comment:""), linenum),
                                            NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file format error", comment:""))
                                        ])
                                }
                            }
                            
                        }
                        else{
                            throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                                code: IMPLutStatus.WRONG_FORMAT.rawValue,
                                userInfo: [
                                    NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file format error in line: %i", comment:""), linenum),
                                    NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file format error", comment:""))
                                ])
                        }
                    }
                }
                
                if description.type == .UNKNOOWN {
                    throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                        code: IMPLutStatus.WRONG_FORMAT.rawValue,
                        userInfo: [
                            NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file format error in line: %i", comment:""), linenum),
                            NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file format error", comment:""))
                        ])
                }
                else {
                    updateTextureFromData(dataBytes, desciption: description)
                }
            }
            catch let error as NSError {
                throw error
            }
        }
        else{
            throw NSError(domain: IMProcessing.names.prefix+"cube-lut.read",
                code: IMPLutStatus.NOT_FOUND.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: String(format: NSLocalizedString("Adobe Cube LUT file %@ not found", comment:""), cubeFile),
                    NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Adobe Cube LUT file not found", comment:""))
                ])
        }
        return description
    }
    
    private func updateTextureFromData(data:NSData, desciption:LutDescription) {
        let width  = desciption.lut3DSize
        let height = desciption.type == .D1D ? 1: width
        let depth  = desciption.type == .D1D ? 1: width
        
        let componentBytes =  IMProcessing.colors.pixelFormat == .RGBA16Unorm  ? sizeof(UInt16) : sizeof(UInt8)
        
        let bytesPerPixel  = 4 * componentBytes
        let bytesPerRow    = bytesPerPixel * width
        let bytesPerImage  = bytesPerRow * height
        
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = desciption.type == .D1D ? .Type2D : .Type3D
        textureDescriptor.width  = width
        textureDescriptor.height = height
        textureDescriptor.depth  = depth
        
        textureDescriptor.pixelFormat =  IMProcessing.colors.pixelFormat // .RGBA8Unorm //IMProcessing.colors.pixelFormat;
        
        textureDescriptor.arrayLength = 1;
        textureDescriptor.mipmapLevelCount = 1;
        
        self.texture = self.context.device.newTextureWithDescriptor(textureDescriptor)
        
        let region = desciption.type == .D1D ? MTLRegionMake2D(0, 0, width, 1) : MTLRegionMake3D(0, 0, 0, width, height, depth);
        
        self.texture!.replaceRegion(region, mipmapLevel:0, slice:0, withBytes:data.bytes, bytesPerRow:bytesPerRow, bytesPerImage:bytesPerImage)
    }
    
    private func updateBytes(inout words:[String], inout isData:Bool, inout dataBytes:NSMutableData, inout description: LutDescription) -> IMPLutStatus {
        
        let keyword = words[0];
        
        if keyword.uppercaseString.hasPrefix("TITLE") {
            description.title = words[1]
        }
        else if keyword.uppercaseString.hasPrefix("DOMAIN_MIN") {
            if (words.count==4) {
                var w = [String]()
                for i in 1..<4 { w.append(words[i])}
                description.domainMin = float3(colors: w)
            }
            else{
                return .WRONG_FORMAT
            }
        }
        else if keyword.uppercaseString.hasPrefix("DOMAIN_MAX") {
            if (words.count==4) {
                var w = [String]()
                for i in 1..<4 { w.append(words[i])}
                description.domainMax = float3(colors: w)
            }
            else{
                return .WRONG_FORMAT
            }
        }
        else if keyword.uppercaseString.hasPrefix("LUT_3D_SIZE") {
            description.lut3DSize = words[1].intValue
            description.type = .D3D
            if description.lut3DSize < 2 || description.lut3DSize > 256  {
                return .OUT_RANGE
            }
        }
        else if keyword.uppercaseString.hasPrefix("LUT_1D_SIZE") {
            description.lut3DSize = words[1].intValue
            description.type = .D1D
            if description.lut3DSize < 2 || description.lut3DSize > 65536  {
                return .OUT_RANGE
            }
        }
        else if keyword.uppercaseString.hasPrefix("LUT_1D_INPUT_RANGE") {
            if (words.count==3) {
                
                let dmin = words[1].floatValue
                let dmax = words[2].floatValue
                
                description.domainMin = float3(dmin)
                description.domainMax = float3(dmax)
            }
            else{
                return .WRONG_FORMAT
            }
        }
        else if isData || keyword.isNumeric {
            if (
                (description.domainMax.x-description.domainMin.x)<=0
                    ||
                    (description.domainMax.y-description.domainMin.y)<=0
                    ||
                    (description.domainMax.z-description.domainMin.z)<=0
                ) {
                    return .WRANG_RANGE
            }
            
            isData = true
            
            let denom:Float = IMProcessing.colors.pixelFormat == .RGBA16Unorm  ? Float(UInt16.max) : Float(UInt8.max)
            
            let rgb    = float3(colors: words)/(description.domainMax.x-description.domainMin.x)*denom
            var color  = float4(rgb:rgb, a: denom)
            
            for i in 0..<4 {
                if IMProcessing.colors.pixelFormat == .RGBA16Unorm {
                    var c = UInt16(color[i])
                    dataBytes.appendBytes(&c, length: sizeofValue(c))
                }
                else {
                    var c = UInt8(color[i])
                    dataBytes.appendBytes(&c, length: sizeofValue(c))
                }
            }
        }
        
        return .OK
    }
}
