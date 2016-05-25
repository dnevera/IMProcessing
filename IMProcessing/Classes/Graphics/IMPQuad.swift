//
//  IMPQuad.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 04.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import simd
import Accelerate

public struct IMPLine {
    
    public let p0:float2
    public let p1:float2
    
    /// Standard form of line equation: Ax + By = C
    /// float3.x = A
    /// float3.y = B
    /// float3.z = C
    public var standardForm:float3 {
        get {
            var f = float3()
            f.x = p1.y-p0.y
            f.y = p0.x-p1.x
            f.z = -((p0.x*(p0.y-p1.y) + p0.y*(p1.x-p0.x)))
            return f
        }
    }

    public init(p0:float2,p1:float2){
        self.p0 = float2(p0.x,p0.y)
        self.p1 = float2(p1.x,p1.y)
    }
    
    public func contains(point point:float2) -> Bool {
        return float3x3(rows: [
            float3(point.x,point.y,1),
            float3(p0.x,p0.y,1),
            float3(p1.x,p1.y,1)
            ]).determinant == 0
    }
    
    public func normalIntersection(point point:float2) -> float2 {
        
        if self.contains(point:point) { return float2(0,0) }
        
        let p  = float2(point.x, point.y)

        let k  = (p1.x-p0.x)/(p1.y-p0.y)
        let k2 = pow(k,2)
        let m  = k2+1
        let l  = p.y + k * (p.x - p0.x) + k2 * p0.y
        
        let y = l/m
        let x = l * (k/m) - k * p0.y + p0.x
        
        return float2(x,y)
    }
    
    public func distanceTo(point point:float2) -> float2 {
        return normalIntersection(point: point) - point
    }
    
    public func crossPoint(line line:IMPLine) -> float2 {
        //
        // a1*x + b1*y = c1 - self line
        // a2*x + b2*y = c2 - another line
        //
        
        let form1 = self.standardForm
        let form2 = line.standardForm
        
        let a1 = form1.x
        let b1 = form1.y
        let c1 = form1.z
        
        let a2 = form2.x
        let b2 = form2.y
        let c2 = form2.z
        
        let D = float2x2(rows: [
            float2(a1,b1),
            float2(a2,b2)
            ]).determinant
        
        let Dx = float2x2(rows: [
            float2(c1,b1),
            float2(c2,b2)
            ]).determinant
        
        let Dy = float2x2(rows: [
            float2(a1,c1),
            float2(a2,c2)
            ]).determinant
        
        return float2(Dx/D,Dy/D)
    }
}

public struct IMPTriangle {
    
    public let p0:float2
    public let pc:float2 // base vertex, center of transformation
    public let p1:float2
    
    public let aspect:Float
    
    public init(p0:float2,pc:float2,p1:float2, aspect:Float = 1){
        self.aspect = aspect
        self.p0 = float2(p0.x*aspect,p0.y)
        self.pc = float2(pc.x*aspect,pc.y)
        self.p1 = float2(p1.x*aspect,p1.y)
    }
    
    public func contains(point:float2) -> Bool {
        return IMPLine(p0: p0, p1: pc).contains(point: point) || IMPLine(p0: pc, p1: p1).contains(point: point)
    }
    
    public func normalIntersections(point point:float2) -> [float2] {
        let line0 = IMPLine(p0: p0, p1: pc)
        let line1 = IMPLine(p0: p1, p1: pc)
        return [line0.normalIntersection(point: point), line1.normalIntersection(point: point)]
    }
    
    public func distancesTo(point point:float2) -> [float2] {
        let line0 = IMPLine(p0: p0, p1: pc)
        let line1 = IMPLine(p0: p1, p1: pc)
        return [line0.distanceTo(point: point),line1.distanceTo(point: point)]
    }
    
    /// Vector of distance from base vertex to opposite side
    public var heightVector:float2 {
        get{
            let line1 = IMPLine(p0: p0, p1: p1)
            return line1.normalIntersection(point: pc) - pc
        }
    }
}


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
    
    subscript(index: Int) -> float2 {
        get {
            let i = index < 0 ? (4-abs(index))%4 : index%4
            
            if i == 0 {
                return left_bottom
            }
            else if i == 1 {
                return left_top
            }
            else if i == 2 {
                return right_top
            }
            return right_bottom
        }
    }
    
    public init(){}
    public init(left_bottom:float2,left_top:float2, right_bottom:float2, right_top:float2){
        self.left_bottom = left_bottom
        self.left_top = left_top
        self.right_bottom = right_bottom
        self.right_top = right_top
    }
    
    public init(region:IMPRegion, aspect:Float = 1){
        crop(region: region)
        setAspect(ratio: aspect)
    }
    
    public mutating func crop(region region:IMPRegion){
        left_bottom.x = left_bottom.x * (1-2*region.left)
        left_bottom.y = left_bottom.y * (1-2*region.bottom)
        
        left_top.x = left_top.x * (1-2*region.left)
        left_top.y = left_top.y * (1-2*region.top)
        
        right_bottom.x = right_bottom.x * (1-2*region.right)
        right_bottom.y = right_bottom.y * (1-2*region.bottom)
        
        right_top.x = right_top.x * (1-2*region.right)
        right_top.y = right_top.y * (1-2*region.top)
    }
    
    public mutating func setAspect(ratio ratio:Float){
        left_bottom.x *= ratio
        left_top.x *= ratio
        right_top.x *= ratio
        right_bottom.x *= ratio
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
    
    public func contains(point point:float2) -> Bool {
        if point.x>=left_bottom.x && point.y>=left_bottom.y {
            if point.x>=left_top.x && point.y<=left_top.y {
                if point.x<=right_top.x && point.y<=right_top.y {
                    if point.x<=right_bottom.x && point.y>=right_bottom.y {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    public func insetTriangles(quad quad:IMPQuad) -> [IMPTriangle] {
      
        var triangles = [IMPTriangle]()
        
        for i in 0..<4 {
            let p0 = quad[i-1]
            let pc = quad[i+0]
            let p1 = quad[i+1]
            
            let cp0 = self[i-1]
            let cpc = self[i+0]
            let cp1 = self[i+1]
            

            let cornerLine1 = IMPLine(p0: cpc, p1: cp0)
            let cornerLine2 = IMPLine(p0: cpc, p1: cp1)
            
            var baseline1 = IMPLine(p0: pc, p1:  p0)
            var baseline2 = IMPLine(p0: pc, p1:  p1)
            
            let crossPoint1 = cornerLine1.crossPoint(line: baseline1)
            let crossPoint2 = cornerLine2.crossPoint(line: baseline1)
            
            let crossPoint12 = cornerLine1.crossPoint(line: baseline2)
            let crossPoint22 = cornerLine2.crossPoint(line: baseline2)

            if contains(point: crossPoint1) && contains(point: crossPoint2){
                let t = IMPTriangle(p0: crossPoint1, pc: cpc, p1: crossPoint2)
                triangles.append(t)
            }

            if contains(point: crossPoint12) && contains(point: crossPoint22){
                let t = IMPTriangle(p0: crossPoint12, pc: cpc, p1: crossPoint22)
                triangles.append(t)
            }
        }
        return triangles
    }
    
    func getInPlaceDistance(points:[float2], base:float2) -> [float2] {
        var outp = float2(0)
        var a    = [float2]()
        
        for p in points {
            outp = p
            if contains(point: p) {
                var d = p-base
                a.append(d)
            }
        }
        return a
    }
    
    public func insetCornerDistances(quad quad:IMPQuad) -> [float2] {
        var a = [float2]()
        
        for i in 0..<4 {
            //let p0 = quad[i-1]
            let pc = quad[i+0]
            //let p1 = quad[i+1]
            
            let cp0 = self[i-1]
            let cpc = self[i+0]
            let cp1 = self[i+1]

            var p = IMPTriangle(p0: cp0, pc: cpc,  p1: cp1    ).normalIntersections(point: pc)
            a += quad.getInPlaceDistance(p, base: pc)

        }
        
        return a
    }
    
    ///  Find distance between corner points of the quad and points of another quad.
    ///  Angle between base lines must be less then 90º.
    ///  To solve in general you can translate quad points.
    ///
    ///  - parameter quad: inset quad
    ///
    ///  - returns: points distance
    ///
    public func insetDistances(quad quad:IMPQuad) -> IMPQuad {
        
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
    
    static func normalVector(distance: float2) -> float2 {
        
        if distance.x == 0 {
            return distance
        }
        
        if distance.y == 0 {
            return distance
        }
        
        let x = distance.x * 4/3
        let y = distance.y
        
        let d = sqrt( 1 / (1/(x*x) + 1/(y*y)))
        
        let f = float2(d,abs(y))
        
        let angle = Float(M_PI/2) - atan(y/x)
        
        let rotation = float2x2(rows:[
            float2(cosf(angle), sinf(angle)),
            float2(sinf(angle), cosf(angle))
            ])
        
        return rotation * f
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
        if p0 == p1 { return p0 }
        let A = ((p1.x * p0.y - p0.x * p1.y) - (p0.y-p1.y) * x)
        let B = (p1.x-p0.x)
        var y = B == 0 ? Float.infinity : A/B
         return float2(x,y)
    }
    
    static public func findPointX(p0 p0:float2, p1:float2, y:Float) -> float2 {
        if p0 == p1 { return p0 }
        let A = ((p1.x * p0.y - p0.x * p1.y) - (p1.x-p0.x) * y)
        let B = (p0.y-p1.y)
        var x =  B == 0 ? Float.infinity : A/B
        return float2(x,y)
    }
}
