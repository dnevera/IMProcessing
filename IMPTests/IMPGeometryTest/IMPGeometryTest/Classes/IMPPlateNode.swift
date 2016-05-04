//
//  IMPPlateNode.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import Foundation

// Photo Plate Node is a Cube Node with virtual depth == 0
public class IMPPlateNode: IMPRenderNode {
    
    public var region = IMPRegion() {
        didSet{
            if
                region.left != oldValue.left ||
                    region.right != oldValue.right ||
                    region.top != oldValue.top ||
                    region.bottom != oldValue.bottom
            {
                vertices = IMPPlate(aspect: aspectRatio, region: self.region)
            }
        }
    }
    
    public var aspectRatio:Float! = 4/3 {
        didSet{
            if oldValue != aspectRatio {
                vertices = IMPPlate(aspect: aspectRatio, region: self.region)
            }
        }
    }
    
    public init(context: IMPContext, aspectRatio:Float, region:IMPRegion = IMPRegion()){
        super.init(context: context, vertices: IMPPlate(aspect: aspectRatio, region: self.region))
    }
}
