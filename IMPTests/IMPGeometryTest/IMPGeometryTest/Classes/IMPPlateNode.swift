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

//        let A = IMPVertex(x: -a, y:   1, z:  0, tx: 0, ty: 0) // left-top
//        let B = IMPVertex(x: -a, y:  -1, z:  0, tx: 0, ty: 1) // left-bottom
//        let C = IMPVertex(x:  a, y:  -1, z:  0, tx: 1, ty: 0) // right-bottom
//        let D = IMPVertex(x:  a, y:   1, z:  0, tx: 1, ty: 1) // right-top

//        let A = IMPVertex(x: -1, y:  -1, z:  0, tx: 0, ty: 1) // left-top
//        let B = IMPVertex(x:  1, y:  -1, z:  0, tx: 1, ty: 1) // left-bottom
//        let C = IMPVertex(x: -1, y:   1, z:  0, tx: 0, ty: 0) // right-bottom
//        let D = IMPVertex(x:  1, y:   1, z:  0, tx: 1, ty: 0) // right-top

        return [
            A,B,C ,A,C,D,   // The main front plate. Here we put image.
        ]
        
//        // Front
//        let A = IMPVertex(x: -1.0*a, y:   1.0, z:   1, tx: 0, ty: 0) // left-top
//        let B = IMPVertex(x: -1.0*a, y:  -1.0, z:   1, tx: 0, ty: 1) // left-bottom
//        let C = IMPVertex(x:  1.0*a, y:  -1.0, z:   1, tx: 1, ty: 1) // right-bottom
//        let D = IMPVertex(x:  1.0*a, y:   1.0, z:   1, tx: 1, ty: 0) // right-top
//        
//        // Back
//        let Q = IMPVertex(x: -1.0*a, y:   1.0, z:  -1, tx: 0, ty: 0) // virtual depth = 0
//        let R = IMPVertex(x:  1.0*a, y:   1.0, z:  -1, tx: 0, ty: 0)
//        let S = IMPVertex(x: -1.0*a, y:  -1.0, z:  -1, tx: 0, ty: 0)
//        let T = IMPVertex(x:  1.0*a, y:  -1.0, z:  -1, tx: 0, ty: 0)
//        
//        return [
//            A,B,C ,A,C,D,   // The main front plate. Here we put image.
//            R,T,S ,Q,R,S,   // Back
//            
//            Q,S,B ,Q,B,A,   //Left
//            D,C,T ,D,T,R,   //Right
//            
//            Q,A,D ,Q,D,R,   //Top
//            B,S,T ,B,T,C    //Bot
//        ]

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
