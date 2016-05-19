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
        
        case Up // default orientation
        case Down // 180 deg rotation
        case Left // 90 deg CCW
        case Right // 90 deg CW
        case UpMirrored // as above but image mirrored along other axis. horizontal flip
        case DownMirrored // horizontal flip
        case LeftMirrored // vertical flip
        case RightMirrored // vertical flip
    }

    public typealias UIImageOrientation = IMPImageOrientation

#endif
import Metal

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
