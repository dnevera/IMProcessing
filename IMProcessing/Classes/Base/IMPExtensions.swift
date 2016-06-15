//
//  IMPAliases.swift
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

import simd
import Metal

#if os(iOS)
    public typealias IMPImage = UIImage
    public typealias IMPColor = UIColor
    public typealias NSRect   = CGRect
    public typealias NSSize   = CGSize
    public typealias NSPoint  = CGPoint

#else
    public typealias IMPImage = NSImage
    public typealias IMPColor = NSColor
#endif

public typealias IMPSize  = CGSize

public enum IMProcessing{
    
    public struct meta {
        
        public static let version                  = 1.0
        public static let versionKey               = "IMProcessingVersion"
        public static let imageOrientationKey      = "Orientation"
        public static let deviceOrientationKey     = "DeviceOrientation"
        public static let imageSourceExposureMode  = "SourceExposureMode"
        public static let imageSourceFocusMode     = "SourceFocusMode"
    }
    
    public struct names {
        static let prefix = "com.improcessing."
    }
    
    public struct colors {
        #if os(iOS)
        public static let pixelFormat = MTLPixelFormat.RGBA8Unorm
        #else
        public static let pixelFormat = MTLPixelFormat.RGBA16Unorm
        #endif
    }    
}


#if os(OSX)
let impColorSpace = NSColorSpace.sRGBColorSpace()
#endif
    
public extension IMPColor{

    public convenience init(color:float4) {
        self.init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
    }
    public convenience init(rgba:float4) {
        self.init(color:rgba)
    }
    public convenience init(rgb:float3) {
        self.init(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: CGFloat(1))
    }
    public convenience init(red:Float, green:Float, blue:Float) {
        self.init(rgb:float3(red,green,blue))
    }
    #if os(iOS)
    public var rgb:float3{
        get{
            return rgba.xyz
        }
    }
    
    public var rgba:float4{
        get{
            var red:CGFloat   = 0.0
            var green:CGFloat = 0.0
            var blue:CGFloat  = 0.0
            var alpha:CGFloat = 0.0
            getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return float4(red.float,green.float,blue.float,alpha.float)
        }
    }
    #else
    public var rgb:float3{
        get{
            guard let rgba = self.colorUsingColorSpace(impColorSpace) else {
                return float3(0)
            }
            return float3(rgba.redComponent.float,rgba.greenComponent.float,rgba.blueComponent.float)
        }
    }
    
    public var rgba:float4{
        get{
            guard let rgba = self.colorUsingColorSpace(impColorSpace) else {
                return float4(0)
            }
            return float4(rgba.redComponent.float,rgba.greenComponent.float,rgba.blueComponent.float,rgba.alphaComponent.float)
        }
    }
    #endif
}

public func * (left:IMPColor, right:Float) -> IMPColor {
    let rgb = left.rgb
    return IMPColor( red: rgb.r*right, green: rgb.g*right, blue: rgb.b*right)
}

public extension IMPBlendingMode{
    static let LUMNINOSITY = IMPBlendingMode(0)
    static let NORMAL      = IMPBlendingMode(1)
}

public extension IMPRegion{
    
    public var width:Float {return 1-(left+right) }
    public var height:Float {return 1-(top+bottom) }
    
    public var rectangle:NSRect{
        return NSRect(origin: NSPoint(x:left.cgfloat,y:top.cgfloat), size: NSSize(width: width, height: height))
    }

    public func lerp(final final:IMPRegion, t:Float) -> IMPRegion {
        return IMPRegion(left:  left.lerp(  final: final.left,  t: t),
                         right: right.lerp( final: final.right, t: t),
                         top:   top.lerp(   final: final.top,   t: t),
                         bottom:bottom.lerp(final: final.bottom,t: t) )
    }
}

public extension String {
    
    var floatValue: Float {
        return (self as NSString).floatValue
    }
    var intValue: Int {
        return (self as NSString).integerValue
    }
    var isNumeric: Bool {
        if Float(self) != nil {
            return true
        }
        else if Int(self) != nil {
            return true
        }
        return false
    }
}

public extension CGSize{
    public func swap() -> CGSize {
        return CGSize(width: height,height: width)
    }
}

public extension MTLSize{
    public init(cgsize:CGSize){
        self.init(width: Int(cgsize.width), height: Int(cgsize.height), depth: 1)
    }
}

public extension MTLTexture{
    public var size:CGSize{
        get{
            return CGSize(width: width, height: height)
        }
    }
}

public extension Array where Element : Equatable {
    public mutating func removeObject(object : Generator.Element) {
        if let index = self.indexOf(object) {
            self.removeAtIndex(index)
        }
    }
}
