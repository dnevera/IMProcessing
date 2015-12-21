//
//  IMPImageProvider+IMPImage.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

extension IMPImageProvider{    
    public convenience init(context: IMPContext, image: IMPImage, maxSize: Float = 0) {
        self.init(context: context)
        self.update(image)
    }
    
    public func update(image:IMPImage){
        self.texture = image.newTexture(self.context)
    }
}