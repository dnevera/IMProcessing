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
        
#else
    public typealias IMPImage = NSImage
    public typealias IMPColor = NSColor
#endif

public typealias IMPSize  = CGSize

public enum IMProcessing{
    struct names {
        static let prefix = "com.improcessing."
    }
    struct colors {
        #if os(iOS)
        static let pixelFormat = MTLPixelFormat.RGBA8Unorm
        #else
        static let pixelFormat = MTLPixelFormat.RGBA16Unorm
        #endif
    }
}

public extension IMPColor{
    convenience init(color:float4) {
        self.init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
    }
}

public extension IMPBlendingMode{
    static let LUMNINOSITY = IMPBlendingMode(0)
    static let NORMAL      = IMPBlendingMode(1)
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