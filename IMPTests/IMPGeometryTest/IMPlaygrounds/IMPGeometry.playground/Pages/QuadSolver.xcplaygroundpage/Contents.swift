//: [Previous](@previous)

import Foundation
import simd

extension float2 {
    mutating func limitInifint() -> float2 {
        if x.isInfinite {
            x = 1000
        }
        if y.isInfinite {
            y = 1000
        }
        return self
    }
}

extension float3x3 {
    var determinant:Float {
        get {
            let t  = self.transpose
            let a1 = t.cmatrix.columns.0
            let a2 = t.cmatrix.columns.1
            let a3 = t.cmatrix.columns.2
            return a1.x*a2.y*a3.z - a1.x*a2.z*a3.y - a1.y*a2.x*a3.z + a1.y*a2.z*a3.x + a1.z*a2.x*a3.y - a1.z*a2.y*a3.x
        }
    }
}

public struct IMPLine {
    public let p0:float2
    public let p1:float2
    public init(p0:float2,p1:float2){
        self.p0 = p0
        self.p1 = p1
    }
    
    public func contains(point point:float2) -> Bool {
        return float3x3(rows: [
            float3(point.x,point.y,1),
            float3(p0.x,p0.y,1),
            float3(p1.x,p1.y,1)
            ]).determinant == 0
    }
    
    public func distanceTo(point point:float2) -> float2 {
        
        if self.contains(point:point) { return float2(0,0) }
        
        let k  = (p1.x-p0.x)/(p1.y-p0.y)
        let k2 = pow(k,2)
        let m  = k2+1
        let l  = point.y + k * (point.x - p0.x) + k2 * p0.y
        
        let y = l/m
        let x = l * (k/m) - k * p0.y + p0.x
        
        return float2(x,y) - point
    }
}

public struct IMPCorner {
    public let p0:float2
    public let pc:float2
    public let p1:float2
    public init(p0:float2,pc:float2,p1:float2){
        self.p0 = p0
        self.pc = pc
        self.p1 = p1
    }
    
    public func contains(point:float2) -> Bool {
        return IMPLine(p0: p0, p1: pc).contains(point: point) || IMPLine(p0: pc, p1: p1).contains(point: point)
    }
    
    public func distancesTo(point point:float2) -> [float2] {
        let line0 = IMPLine(p0: p0, p1: pc)
        let line1 = IMPLine(p0: p1, p1: pc)
        return [line0.distanceTo(point: point),line1.distanceTo(point: point)]
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
    
    public init(){}
    public init(left_bottom:float2,left_top:float2, right_bottom:float2, right_top:float2){
        self.left_bottom = left_bottom
        self.left_top = left_top
        self.right_bottom = right_bottom
        self.right_top = right_top
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
    ///  To solve in general you can transpose quad points.
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

        //return IMPQuad(left_bottom: lb, left_top: lt, right_bottom: rb, right_top: rt)
        return IMPQuad(left_bottom:  IMPQuad.normalVector(lb),
                       left_top:     IMPQuad.normalVector(lt),
                       right_bottom: IMPQuad.normalVector(rb),
                       right_top:    IMPQuad.normalVector(rt))
    }
    
    static func normalVector(distance: float2) -> float2 {
        
        if distance.x == 0 {
            return distance
        }
        
        if distance.y == 0 {
            return distance
        }
        
        let x = distance.x
        let y = distance.y
        
        let d = sqrt( 1 / (1/(x*x) + 1/(y*y)))
        
        let f = float2(d,0)
        
        let angle = Float(M_PI/2) - atan(y/x)

        let rotation = float2x2(rows:[
            float2(cosf(angle), -sinf(angle)),
            float2(-sinf(angle), cosf(angle))
            ])
        
        print(180*angle/Float(M_PI))
        
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
}

var p0 = float2(-0.5, 1)
var p1 = float2(-2,  -1)
var p2 = float2( 2,  -1)


//print(IMPQuad.distancesFrom(point: float2(-1,-1), toCorner: IMPCorner(p0: p0, pc: p1, p1: p3)))
//print(IMPQuad.distanceFrom(point: float2(-1,-1), toLine: IMPQuad.Line(p0: p0, p1: p1)))

//print(IMPLine(p0: p0, p1: p1).distanceTo(point: float2(-1,-1)))
//print(IMPCorner(p0: p0, pc: p1, p1: p2).distancesTo(point: float2(-1,-1)))


//print(IMPLine(p0: p1, p1: p2).contains(point: float2(-1,-1)))

//print(IMPQuad.normalVector(p0))

var s = IMPQuad()

s.contains(point: float2(0,0))
s.contains(point: float2(0,-1))
s.contains(point: float2(-1.2,-1))

//s.right_top.y = Float(1.333)
//
//let py = IMPQuad.findPointY(p0: s.left_bottom, p1: s.right_top, x: 0.7)
//let px = IMPQuad.findPointX(p0: s.left_bottom, p1: s.right_top, y: py.y)
//
////var vs = IMPQuad(left_bottom: float2(-0.995385, -1.16069), left_top: float2(-1.59054, 0.782171), right_bottom: float2(0.947479, -0.782171), right_top: float2(0.352324, 1.16069))
//
//var vs  = IMPQuad(left_bottom: float2(-0.899626, -0.899626), left_top: float2(-0.899626, 0.899626), right_bottom: float2(0.899626, -0.899626), right_top: float2(0.899626, 0.899626))
//
//var d = IMPQuad()
//d.left_bottom.x  = -0.5
//d.left_bottom.y  = -0.5
//d.right_bottom.x = -0.5
//d.right_bottom.y  = -0.5

//var dt = vs.insetDistances(quad: d)
//
//print(dt)

//let lb = IMPQuad.cornerDistances(
//    source: (
//        x:[vs.left_bottom, vs.left_top,    vs.right_top],
//        y:[vs.left_top,    vs.left_bottom, vs.right_bottom]),
//    destination: d.left_bottom
//    )
//
//
//print("corner = \(lb)")


//let lt = IMPQuad.cornerDistances(
//    source: (
//        x:[vs.left_bottom, vs.left_top,  vs.right_top],
//        y:[vs.left_top,    vs.right_top, vs.right_bottom]),
//    destination: d.left_top
//)
//
//print("corner = \(lt)")


//let rt = IMPQuad.cornerDistances(
//    source: (
//        x:[vs.right_top, vs.right_bottom, vs.left_bottom],
//        y:[vs.left_top,  vs.right_top,    vs.right_bottom]),
//    destination: d.right_top
//)
//
//print("corner = \(rt)")


//let rb = IMPQuad.cornerDistances(
//    source: (
//        x:[vs.right_top, vs.right_bottom, vs.left_bottom],
//        y:[vs.left_top,  vs.left_bottom,  vs.right_bottom]),
//    destination: d.right_bottom
//)
//
//print("corner = \(rb)")
//
