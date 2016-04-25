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


public extension IMPTransformBuffer {
    public init(scale _sc: float3, rotation _rt: float3x3, transition _tr: float4x4, projection _pr: float4x4){
        scale = _sc
        rotation = _rt.cmatrix
        transition = _tr.cmatrix
        projection = _pr.cmatrix
    }
}

public extension matrix_float3x3 {
    public mutating func rotate(radians radians:Float, x:Float, y:Float, z:Float) {
        
        let v =  normalize(float3(x,y,z))
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

public extension matrix_float4x4 {
    
    public mutating func ratio(ratio:Float){
        let bottom:Float = -1.0
        let top:Float    = 1.0
        let left:Float   = (-1.0 * ratio)
        let right:Float  = (1.0 * ratio)
        
        let near:Float = -1.0
        let far:Float = 1.0
        let r_l:Float = right - left
        let t_b:Float = top - bottom
        let f_n:Float = far - near
        let tx:Float = -(right + left) / (right - left)
        let ty:Float = -(top + bottom) / (top - bottom)
        let tz:Float = -(far + near) / (far - near)
        
        let scale:Float = 2.0
        
        self = float4x4(rows:[
            float4( scale / t_b, 0,           0,           tx),
            float4( 0,           scale / r_l, 0,           ty),
            float4( 0,           0,           scale / f_n, tz),
            float4( 0,           0,           0,            1),
            ]).cmatrix
    }
    
    public mutating func perspective(x x:Float, y:Float) {
        self = float4x4(rows:[
            float4(1, 0, 0, x),
            float4(0, 1, 0, y),
            float4(0, 0, 1, 0),
            float4(0, 0, 0, 1)]).cmatrix
    }
    
    public mutating func move(x x:Float, y: Float){
        self = float4x4([
            float4(1, 0, 0, x),
            float4(0, 1, 0, y),
            float4(0, 0, 1, 0),
            float4(0, 0, 0, 1)]).cmatrix
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
        encoder.rotation.rotate(radians: radians, x: 0, y: 0, z: 1)
    }

    public func perspective(x x:Float, y:Float){
        encoder.projection.perspective(x: x, y: y)
    }

    public func ratio(ratio:Float){
        encoder.projection.ratio(ratio)
    }

    public func scale(scale:Float){
        encoder.scale = float3(scale)
    }
    
    public func move(x x:Float, y:Float){
        encoder.transition.move(x: x, y: y)
    }
    
    var encoder = IMPTransformBuffer(scale: float3(1),
                                     rotation: float3x3(diagonal: float3(1)),
                                     transition: float4x4(diagonal: float4(1)),
                                     projection: float4x4(diagonal: float4(1)))
}