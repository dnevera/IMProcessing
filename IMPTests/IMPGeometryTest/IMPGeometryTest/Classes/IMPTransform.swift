//
//  IMPTranformation.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 23.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import simd

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal


public extension IMPTransformIn {
    
    public init(tranform _tr:  float3x3, transition _mv: float4x4) {
        transform = _tr.cmatrix
        transition = _mv.cmatrix
    }
}

public extension float3 {
    
}

public extension matrix_float3x3 {
    
    
    public mutating func rotation(radians radians:Float, x:Float, y:Float, z:Float) {
        
        let v =  normalize(float3(x,y,z)) // GLKVector3Normalize(GLKVector3Make(x, y, z));
        let cos = cosf(radians)
        let cosp = 1.0 - cos
        let sin = sinf(radians)
        
        let m0 = float3(
            cos + cosp * v[0] * v[0],
            cosp * v[0] * v[1] + v[2] * sin,
            cosp * v[0] * v[2] - v[1] * sin)
        
        let m1  = float3(
            cosp * v[0] * v[1] - v[2] * sin,
            cos + cosp * v[1] * v[1],
            cosp * v[1] * v[2] + v[0] * sin)
        
        let m2 = float3(
            cosp * v[0] * v[2] + v[1] * sin,
            cosp * v[1] * v[2] - v[0] * sin,
            cos + cosp * v[2] * v[2])
        
        self = matrix_float3x3(columns: (m0,m1,m2))
    }
    

}

public class IMPTransform {
                
    public var cropRegion = IMPCropRegion() {
        didSet{
            cropRect = CGRect(x: cropRegion.left.cgfloat, y: cropRegion.top.cgfloat, width: 1.0-(cropRegion.right+cropRegion.left).cgfloat, height: 1.0-(cropRegion.bottom+cropRegion.top).cgfloat)
        }
    }
    
    public var cropRect   = CGRect() {
        didSet{
            cropRect.origin.x    =  cropRect.origin.x < 0.0 ? 0.0 : cropRect.origin.x
            cropRect.origin.x    =  cropRect.origin.x > 1.0 ? 1.0 : cropRect.origin.x
            cropRect.size.width  =  (cropRect.size.width + cropRect.origin.x) > 1.0 ? 1.0-cropRect.origin.x : cropRect.size.width
            cropRect.size.height =  (cropRect.size.height + cropRect.origin.y) > 1.0 ? 1.0-cropRect.origin.y : cropRect.size.height
            
            cropRegion = IMPCropRegion(top: cropRect.origin.y.float,
                                       right: 1.0-(cropRect.size.width+cropRect.origin.x).float,
                                       left: cropRect.origin.x.float,
                                       bottom: 1.0 - (cropRect.size.height+cropRect.origin.y).float
            )
        }
    }
    
    public func rotation(radians radians:Float){
        encoder.transform.rotation(radians: radians, x: 0, y: 0, z: 1)
    }
    
    var encoder = IMPTransformIn(tranform: float3x3(diagonal: float3(1)), transition: float4x4(diagonal: float4(1)))
    
    
    
}