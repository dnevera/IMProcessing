//: [Previous](@previous)

import Foundation
import Accelerate
import simd

typealias LAInt = __CLPK_integer

extension float2x2 {
    var determinant:Float {
        get {
            let t = cmatrix.columns
            return t.0.x*t.1.y - t.0.y*t.1.x
        }
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


let base  = IMPLine(p0: float2(-1, 1), p1: float2(-1,-1))
let line2 = IMPLine(p0: float2(-2, 1), p1: float2(0.5,-0.5))

print(base.crossPoint(line: line2))

(4-1)%4
