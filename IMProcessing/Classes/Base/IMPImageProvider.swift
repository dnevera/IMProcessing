//
//  IMPImageProvider.swift
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

public class IMPImageProvider: IMPTextureProvider,IMPContextProvider {

    #if os(iOS)
    public var orientation = UIImageOrientation.Up
    #endif
    
    public var context:IMPContext!
    public var texture:MTLTexture?
    
    public lazy var videoCache:IMPVideoTextureCache = {
        return IMPVideoTextureCache(context: self.context)
    }()
    
    public required init(context: IMPContext) {
        self.context = context
    }
    
    public convenience init(context: IMPContext, texture:MTLTexture){
        self.init(context: context)
        self.texture = texture
    }
    
    public weak var filter:IMPFilter?
    
    public func completeUpdate(){
        filter?.executeNewSourceObservers(self)
        filter?.dirty = true
    }
}
