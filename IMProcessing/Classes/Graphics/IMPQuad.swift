//
//  IMPQuad.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 04.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import simd

///  @brief Base quadrangle
public struct IMPQuad {
    
    /// Left bottom point of the quad
    public var left_bottom  = float2( -1, -1)
    /// Left top point of the quad
    public var left_top     = float2( -1,  1)
    /// Right bottom point of the quad
    public var right_bottom = float2(  1, -1)
    /// Right top point of the quad
    public var right_top    = float2(  1,  1)
    
    public init(){}
    public init(left_bottom:float2,left_top:float2, right_bottom:float2, right_top:float2){
        self.left_bottom = left_bottom
        self.left_top = left_top
        self.right_bottom = right_bottom
        self.right_top = right_top
    }
    
    public init(region:IMPRegion){
        left_bottom.x = left_bottom.x * (1-2*region.left)
        left_bottom.y = left_bottom.y * (1-2*region.bottom)
        
        left_top.x = left_top.x * (1-2*region.left)
        left_top.y = left_top.y * (1-2*region.top)
        
        right_bottom.x = right_bottom.x * (1-2*region.right)
        right_bottom.y = right_bottom.y * (1-2*region.bottom)
        
        right_top.x = right_top.x * (1-2*region.right)
        right_top.y = right_top.y * (1-2*region.top)
    }
    
    /// Basis matrix
    public var basis:float3x3 {
        get{
            let A = float3x3(rows:[
                [left_bottom.x,left_top.x,right_bottom.x],
                [left_bottom.y,left_top.y,right_bottom.y],
                [1,1,1]
                ])
            let B = float3(right_top.x,right_top.y,1)
            let X = A.inverse * B
            // C = (Ai)*B
            return A * float3x3(diagonal: X)
        }
    }
    
    ///  Projection transformation matrix on 2D plain from the self to destination
    ///
    ///  - parameter destination: destination quad
    ///
    ///  - returns: transformation matrix
    public func transformTo(destination d:IMPQuad) -> float4x4 {
        let t = d.basis * self.basis.inverse
        
        return float4x4(rows: [
            [t[0,0], t[1,0], 0, t[2,0]],
            [t[0,1], t[1,1], 0, t[2,1]],
            [0     , 0     , 1, 0   ],
            [t[0,2], t[1,2], 0, t[2,2]]
            ])
    }
    
    ///  Find distance between corner points of the quad and points of another quad.
    ///  Angle between base lines must be less then 90º.
    ///  To solve in general you can translate quad points.
    ///
    ///  - parameter quad: inset quad
    ///
    ///  - returns: points distance
    ///
    public func insetsDistance(quad quad:IMPQuad) -> IMPQuad {
        
        let lb = IMPQuad.cornerDistances(
            source: (
                x:[left_bottom, left_top,    right_top],
                y:[left_top,    left_bottom, right_bottom]),
            destination: quad.left_bottom
        )
        
        let lt = IMPQuad.cornerDistances(
            source: (
                x:[left_bottom, left_top,  right_top],
                y:[left_top,    right_top, right_bottom]),
            destination: quad.left_top
        )
        
        let rt = IMPQuad.cornerDistances(
            source: (
                x:[right_top, right_bottom, left_bottom],
                y:[left_top,  right_top,    right_bottom]),
            destination: quad.right_top
        )
        
        let rb = IMPQuad.cornerDistances(
            source: (
                x:[right_top, right_bottom, left_bottom],
                y:[left_top,  left_bottom,  right_bottom]),
            destination: quad.right_bottom
        )
        
        return IMPQuad(left_bottom:  float2( lb.x, lb.y),
                       left_top:     float2( lt.x, lt.y),
                       right_bottom: float2( rb.x, rb.y),
                       right_top:    float2( rt.x, rt.y))
    }
    
    static func cornerDistances(source source: (x:[float2],y:[float2]), destination: float2) -> float2 {
        
        let px0 = IMPQuad.findPointX(p0: source.x[0], p1: source.x[1], y: destination.y)
        let px1 = IMPQuad.findPointX(p0: source.x[1], p1: source.x[2], y: destination.y)
        
        var p0:float2
        
        if distance(destination, px0) < distance(destination, px1) {
            p0 = float2(px0.x,destination.y)
        }
        else {
            p0 = float2(px1.x,destination.y)
        }
        
        let py0 = IMPQuad.findPointY(p0: source.y[0], p1: source.y[1], x: destination.x)
        let py1 = IMPQuad.findPointY(p0: source.y[1], p1: source.y[2], x: destination.x)
        
        var p1:float2
        
        
        if distance(destination, py0) < distance(destination, py1) {
            p1 = float2(destination.x,py0.y)
        }
        else {
            p1 = float2(destination.x,py1.y)
        }
        
        return float2(destination.x-p0.x,destination.y-p1.y)
    }
    
    static public func findPointY(p0 p0:float2, p1:float2, x:Float) -> float2 {
        let A =  ((p1.x * p0.y - p0.x * p1.y) - (p0.y-p1.y) * x)
        let B = (p1.x-p0.x)
        let y =  A == 0 ? p0.y : (B == 0 ? p0.x : A/B)
        return float2(x,y)
    }
    
    static public func findPointX(p0 p0:float2, p1:float2, y:Float) -> float2 {
        let A = ((p1.x * p0.y - p0.x * p1.y) - (p1.x-p0.x) * y)
        let B = (p0.y-p1.y)
        let x =  A == 0 ? p0.x : (B == 0 ? p0.y : A/B)
        return float2(x,y)
    }
}
