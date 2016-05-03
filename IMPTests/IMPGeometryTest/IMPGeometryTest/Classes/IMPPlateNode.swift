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
    
    public static func  newAspect (ascpectRatio a:Float, region:IMPRegion = IMPRegion()) -> [IMPVertex] {
        // Front
        let A = IMPVertex(x: -a, y:   1, z:  0, tx: region.left,    ty: region.top)      // left-top
        let B = IMPVertex(x: -a, y:  -1, z:  0, tx: region.left,    ty: 1-region.bottom) // left-bottom
        let C = IMPVertex(x:  a, y:  -1, z:  0, tx: 1-region.right, ty: 1-region.bottom) // right-bottom
        let D = IMPVertex(x:  a, y:   1, z:  0, tx: 1-region.right, ty: region.top)      // right-top

        return [
            A,B,C ,A,C,D,   // The main front plate. Here we put image.
        ]        
    }
    
    public var region = IMPRegion() {
        didSet{
            if
                region.left != oldValue.left ||
                    region.right != oldValue.right ||
                    region.top != oldValue.top ||
                    region.bottom != oldValue.bottom
            {
                vertices = IMPPlateNode.newAspect(ascpectRatio: aspectRatio, region: self.region)
            }
        }
    }
    
    public var aspectRatio:Float! = 4/3 {
        didSet{
            if oldValue != aspectRatio {
                vertices = IMPPlateNode.newAspect(ascpectRatio: aspectRatio, region: self.region)
            }
        }
    }
    
    public init(context: IMPContext, aspectRatio:Float, region:IMPRegion = IMPRegion()){
        super.init(context: context, vertices: IMPPlateNode.newAspect(ascpectRatio: aspectRatio, region: region))
    }
}
