//
//  IMPImageProvider.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
        
    public typealias IMPImageOrientation = UIImageOrientation
    
#else
    import Cocoa
    
    public enum IMPImageOrientation : Int {
        case Up             // 0,  default orientation
        case Down           // 1, -> Up    (0), UIImage, 180 deg rotation
        case Left           // 2, -> Right (3), UIImage, 90 deg CCW
        case Right          // 3, -> Down  (1), UIImage, 90 deg CW
        case UpMirrored     // 4, -> Right (3), UIImage, as above but image mirrored along other axis. horizontal flip
        case DownMirrored   // 5, -> Right (3), UIImage, horizontal flip
        case LeftMirrored   // 6, -> Right (3), UIImage, vertical flip
        case RightMirrored  // 7, -> Right (3), UIImage, vertical flip
    }

    public typealias UIImageOrientation = IMPImageOrientation

#endif
import Metal

public extension IMPImageOrientation {
    //
    // Exif codes, F is example
    //
    // 1        2       3      4         5            6           7          8
    //
    // 888888  888888      88  88      8888888888  88                  88  8888888888
    // 88          88      88  88      88  88      88  88          88  88      88  88
    // 8888      8888    8888  8888    88          8888888888  8888888888          88
    // 88          88      88  88
    // 88          88  888888  888888

    //                              EXIF orientation
    //    case Up             // 0, < - (1), default orientation
    //    case Down           // 1, < - (3), UIImage, 180 deg rotation
    //    case Left           // 2, < - (8), UIImage, 90 deg CCW
    //    case Right          // 3, < - (6), UIImage, 90 deg CW
    //    case UpMirrored     // 4, < - (2), UIImage, as above but image mirrored along other axis. horizontal flip
    //    case DownMirrored   // 5, < - (4), UIImage, horizontal flip
    //    case LeftMirrored   // 6, < - (5), UIImage, vertical flip
    //    case RightMirrored  // 7, < - (7), UIImage, vertical flip
    
    init?(exifValue: IMPImageOrientation.RawValue) {
        switch exifValue {
        case 1:
            self.init(rawValue: IMPImageOrientation.Up.rawValue)
        case 2:
            self.init(rawValue: IMPImageOrientation.UpMirrored.rawValue)
        case 3:
            self.init(rawValue: IMPImageOrientation.Down.rawValue)
        case 4:
            self.init(rawValue: IMPImageOrientation.DownMirrored.rawValue)
        case 5:
            self.init(rawValue: IMPImageOrientation.LeftMirrored.rawValue)
        case 6:
            self.init(rawValue: IMPImageOrientation.Right.rawValue)
        case 7:
            self.init(rawValue: IMPImageOrientation.RightMirrored.rawValue)
        case 8:
            self.init(rawValue: IMPImageOrientation.Left.rawValue)
        default:
            self.init(rawValue: IMPImageOrientation.Up.rawValue)
        }
    }
}

public class IMPImageProvider: IMPTextureProvider,IMPContextProvider {

    public var orientation = IMPImageOrientation.Up
    
    public var context:IMPContext!
    public var texture:MTLTexture?
    
    public lazy var videoCache:IMPVideoTextureCache = {
        return IMPVideoTextureCache(context: self.context)
    }()
    
    public required init(context: IMPContext) {
        self.context = context
    }

    public required init(context: IMPContext, orientation:IMPImageOrientation) {
        self.context = context
        self.orientation = orientation
    }

    public convenience init(context: IMPContext, texture:MTLTexture, orientation:IMPImageOrientation = .Up){
        self.init(context: context)
        self.texture = texture
        self.orientation = orientation
    }
    
    public weak var filter:IMPFilter?
    
    public func completeUpdate(){
        filter?.executeNewSourceObservers(self)
        filter?.dirty = true
    }
}
