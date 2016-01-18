//
//  IMPMaxSizeFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 18.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation

public class IMPMaxSizeFilter: IMPFilter {
    
    public var size:Float?
    
    public required init(context: IMPContext) {
        super.init(context: context)
        addSourceObserver { (source) -> Void in
            if self.size != nil {
                if let sz = source.texture?.size {
                    let scale = self.size!/max(sz.width,sz.height).float
                    if scale<1 {
                        self.destinationSize = MTLSize(cgsize: CGSize(width: sz.width*scale, height: sz.height*scale))
                    }
                }
            }
        }
    }
}