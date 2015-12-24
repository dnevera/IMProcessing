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
    
    public var context:IMPContext!
    public var texture:MTLTexture?

    public required init(context: IMPContext) {
        self.context = context
    }
    
    public convenience init(context: IMPContext, texture:MTLTexture){
        self.init(context: context)
        self.texture = texture
    }
}
