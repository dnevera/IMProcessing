//
//  IMPSplines.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 09.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Accelerate

// MARK: - Bezier cubic splines 
public extension Float {
    
    public func cubicBesierFunction(c1 c1:float2, c2:float2) -> Float {
        let t = cubicBezierBinarySubdivide(x: self, x1: c1.x, x2: c2.x)
        return cubicBezierCalculate(t: t, a1: c1.y, a2: c2.y)
        
    }
    
    func  A(a1 a1:Float, a2:Float) -> Float { return (1.0 - 3.0 * a2 + 3.0 * a1) }
    func  B(a1 a1:Float, a2:Float) -> Float { return (3.0 * a2 - 6.0 * a1) }
    func  C(a1 a1:Float) -> Float  { return (3.0 * a1) }
    
    func cubicBezierCalculate(t t:Float, a1:Float, a2:Float) -> Float {
        return ((A(a1: a1, a2: a2) * t + B(a1: a1, a2: a2)) * t + C(a1: a1)) * t
    }
    
    func cubicBezierSlope(t t:Float, a1:Float, a2:Float) ->Float {
        return 3.0 * A(a1: a1, a2: a2) * t * t + 2.0 * B(a1: a1, a2: a2) * t + C(a1: a1)
    }
    
    func cubicBezierBinarySubdivide(x x:Float, x1: Float, x2: Float) -> Float {
        let epsilon:Float = 0.0000001
        let maxIterations = 10
        
        var start:Float = 0
        var end:Float = 1
        
        var currentX:Float
        var currentT:Float
        
        var i = 0
        repeat {
            currentT = start + (end - start) / 2
            currentX = cubicBezierCalculate(t: currentT, a1: x1, a2: x2) - x;
            
            if (currentX > 0) {
                end = currentT;
            } else {
                start = currentT;
            }
            
            i += 1
            
        } while (fabs(currentX) > epsilon && i < maxIterations)
        
        return currentT
    }
}

public extension CollectionType where Generator.Element == Float {
    public func cubicBezierSpline(c1 c1:float2, c2:float2, scale:Float=0)-> [Float]{
        var curve = [Float]()
        for x in self {
            curve.append(x.cubicBesierFunction(c1: c1, c2: c2))
        }
        return curve
    }
}


// MARK: - Cubic Splines
public extension CollectionType where Generator.Element == Float {
    
    ///  Create 1D piecewise cubic spline curve from linear collection of x-Float points with certain control points
    ///
    ///  - parameter controls: list of (x,y) control points
    ///
    ///  - returns: interpolated list of (y) points
    public func cubicSpline(controls:[float2], scale:Float=0)-> [Float]{
        var curve = [Float]()
        let max   = self.maxElement()!
        let S = splineSlopes(controls)
        for i in self{
            let x = Float(i)
            var y = evaluateSpline(x, points: controls, slopes: S)
            y = y<0 ? 0 : y > max ? max : y
            var point = y
            if scale > 0 {
                point = point/(max/scale)
            }
            curve.append(point)
        }
        return curve
    }
    
    ///  Create 2D piecewise cubic spline curve from linear collection of x-Float points with certain control points
    ///
    ///  - parameter controls: list of (x,y) control points
    ///
    ///  - returns: interpolated list of (x,y) points
    public func cubicSpline(controls:[float2], scale:Float=0)-> [float2]{
        var curve = [float2]()
        let max   = self.maxElement()!
        let S = splineSlopes(controls)
        for i in self{
            let x = Float(i)
            var y = evaluateSpline(x, points: controls, slopes: S)
            y = y<0 ? 0 : y > max ? max : y
            var point = float2(x,y)
            if scale > 0 {
                point = point/(max/scale)
            }
            curve.append(point)
        }
        return curve
    }

    
    func splineSlopes(points:[float2]) -> [Float] {
        
        // This code computes the unique curve such that:
        //		It is C0, C1, and C2 continuous
        //		The second derivative is zero at the end points
        
        let count = points.count
        
        var Y = [Float](count: count, repeatedValue: 0)
        var X = [Float](count: count, repeatedValue: 0)
        
        var S = [Float](count: count, repeatedValue: 0)
        var E = [Float](count: count, repeatedValue: 0)
        var F = [Float](count: count, repeatedValue: 0)
        var G = [Float](count: count, repeatedValue: 0)
        
        for i in 0 ..< count {
            X[i]=points[i].x
            Y[i]=points[i].y
        }
        
        
        let start = 0
        let end   = count
        
        var A =  X [start+1] - X [start]
        var B = (Y [start+1] - Y [start]) / A
        
        S [start] = B
        
        //var j=0
        
        // Slopes here are a weighted average of the slopes
        // to each of the adjcent control points.
        
        //for j = start + 2; j < end; j += 1 {
        for j in (start + 2)  ..< end {
            
            let C =  X[j] - X[j-1]
            let D = (Y[j] - Y[j-1]) / C
            
            S [j-1] = ((B * C + D * A) / (A + C))
            
            A = C
            B = D
        }
        
        S [end-1] = 2.0 * B - S[end-2]
        S [start] = 2.0 * S[start] - S[start+1]
        
        if (end - start) > 2 {
            
            F [start] = 0.5
            E [end-1] = 0.5
            G [start] = 0.75 * (S [start] + S [start+1])
            G [end-1] = 0.75 * (S [end-2] + S [end-1])
            
            //for j = start+1; j < end - 1; j += 1 {
            for j in (start+1) ..< (end-1) {
                
                A = (X [j+1] - X [j-1]) * 2.0
                
                E [j] = (X [j+1] - X [j]) / A
                F [j] = (X [j] - X [j-1]) / A
                G [j] = 1.5 * S [j]
                
            }
            
            //for j = start+1; j < end; j += 1 {
            for j in (start+1) ..< end {
                
                A = 1.0 - F [j-1] * E [j]
                
                if j != end-1 { F [j] = F[j]/A }
                
                G [j] = (G [j] - G [j-1] * E [j]) / A
                
            }
            
            //for j = end - 2; j >= start; j -= 1 {
            for j in (end - 2).stride(through: start, by: -1){
                G [j] = G [j] - F [j] * G [j+1]
            }
            
            //for j = start; j < end; j += 1 {
            for j in start ..< end {
                S [j] = G [j]
            }
        }
        
        return S
    }
    
    func evaluateSpline(x:Float, points:[float2], slopes S:[Float]) -> Float {
        
        let count = points.count
        
        // Check for off each end of point list.
        
        if x <= points[0].x       { return points[0].y }
        
        if x >= points[count-1].x { return points[count-1].y }
        
        // Binary search for the index.
        
        var lower = 1
        var upper = count - 1
        
        while upper > lower {
            
            let mid = (lower + upper) >> 1
            
            let point = points[mid]
            
            if x == point.x { return point.y }
            
            if x > point.x { lower = mid + 1 }
            else           { upper = mid }
            
        }
        
        let j = lower
        
        // X [j - 1] < x <= X [j]
        // A is the distance between the X [j] and X [j - 1]
        // B and C describe the fractional distance to either side. B + C = 1.
        
        // We compute a cubic spline between the two points with slopes
        // S[j-1] and S[j] at either end. Specifically, we compute the 1-D Bezier
        // with control values:
        //
        //		Y[j-1], Y[j-1] + S[j-1]*A, Y[j]-S[j]*A, Y[j]
        
        let P0 = points[j-1]
        let P1 = points[j]
        let S0 = S[j-1]
        let S1 = S[j]
        return evaluateSplineSegment (x,
            P0.x,
            P0.y,
            S0,
            P1.x,
            P1.y,
            S1)
    }
    
    func evaluateSplineSegment (x:Float,
        _ x0:Float,
        _ y0:Float,
        _ s0:Float,
        _ x1:Float,
        _ y1:Float,
        _ s1:Float) -> Float
    {
        
        let A = x1 - x0
        
        let B = (x - x0) / A
        
        let C = (x1 - x) / A
        
        let D = ((y0 * (2.0 - C + B) + (s0 * A * B)) * (C * C)) +
            ((y1 * (2.0 - B + C) - (s1 * A * C)) * (B * B));
        
        return D
    }
}

// MARK: - Catmull-Rom piecewise splines
public extension CollectionType where Generator.Element == Float {
    
    ///  Create 1D piecewise Catmull-Rom spline curve from linear collection of x-Float points with certain control points
    ///
    ///  - parameter controls: list of (x,y) control points
    ///
    ///  - returns: interpolated list of (y) points
    public func catmullRomSpline(points:[float2], scale:Float=0) -> [Float]{
        var curve = [Float]()
        for x in self {
            curve.append(catmullRomSplinePoint(x, points: points).y)
        }
        if scale>0 {
            var max:Float = 0
            vDSP_maxv(curve, 1, &max, vDSP_Length(curve.count))
            max = scale/max
            vDSP_vsmul(curve, 1, &max, &curve, 1, vDSP_Length(curve.count))
        }
        return curve
    }
    
    ///  Create 2D piecewise Catmull-Rom spline curve from linear collection of x-Float points with certain control points
    ///
    ///  - parameter controls: list of (x,y) control points
    ///
    ///  - returns: interpolated list of (x,y) points
    public func catmullRomSpline(points:[float2], scale:Float=0) -> [float2]{
        var curve = [float2]()
        for x in self {
            curve.append(catmullRomSplinePoint(x, points: points))
        }
        if scale>0 {
            var max:Float = 0
            let address = UnsafeMutablePointer<Float>(curve)
            vDSP_maxv(address+1, 2, &max, vDSP_Length(curve.count))
            max = scale/max
            vDSP_vsmul(address, 1, &max, address, 1, vDSP_Length(curve.count*2))
        }
        return curve
    }
    
    func catmullRomSplinePoint(x:Float,points:[float2]) -> float2 {
        let Xi = x
        
        let k  = find(points, Xi: Xi)
        let P1 = points[k.0]
        let P2 = points[k.1]
        
        let (a,b,h) = catmullRomSplineCoeff(k, points: points)
        
        let t = (Xi - P1.x) / h
        let t2 = t*t
        let t3 = t2*t
        
        let h00 =  2*t3 - 3*t2 + 1
        let h10 =    t3 - 2*t2 + t
        let h01 = -2*t3 + 3*t2
        let h11 =    t3 - t2
        
        return float2(
            Xi,
            h00 * P1.y + h10 * h * a + h01 * P2.y + h11 * h * b
        )
    }
    
    func find(points:[float2], Xi:Float)->(Int,Int){
        let n = points.count
        
        var k1:Int = 0
        var k2:Int = n-1
        while k2-k1 > 1 {
            let k = floor(Float(k2+k1)/2.0).int
            let xkpoint = points[k]
            if xkpoint.x > Xi {
                k2 = k
            }
            else {
                k1 = k
            }
        }
        return (k1,k2)
    }
    
    
    func catmullRomSplineCoeff(k:(Int,Int), points:[float2]) -> (a:Float,b:Float,h:Float) {
        
        let P1 = points[k.0]
        let P2 = points[k.1]
        
        let h = P2.x - P1.x
        var a:Float = 0
        var b:Float = 0
        
        if k.0 == 0 {
            let P3 = points[k.1+1]
            a = (P2.y - P1.y) / h
            b = (P3.y - P1.y) / (P3.x - P1.x)
        }
        else if k.1 == points.count-1 {
            let P0 = points[k.0-1]
            a = (P2.y - P1.y) / (P2.x - P0.x)
            b = (P2.y - P1.y) / h
        }
        else{
            let P0 = points[k.0-1]
            let P3 = points[k.1+1]
            a = (P2.y - P0.y) / (P2.x - P0.x)
            b = (P3.y - P1.y) / (P3.x - P1.x)
        }
        
        return (a,b,h)
    }
}

public struct IMPMatrix3D{
    
    public var columns:[Float]
    public var rows:   [(y:Float,z:[Float])]
    
    public func column(index:Int) -> [Float] {
        var c = [Float]()
        for i in rows {
            c.append(i.z[index])
        }
        return c
    }
    
    public func row(index:Int) -> [Float] {
        return rows[index].z
    }
    
    public init(columns:[Float], rows:[(y:Float,z:[Float])]){
        self.columns = columns
        self.rows = rows
    }
    
    public init(xy points:[[Float]], zMatrix:[Float]){
        if points.count != 2 {
            fatalError("IMPMatrix3D xy must have 2 dimension Float array with X-points and Y-points lists...")
        }
        columns = points[0]
        rows = [(y:Float,z:[Float])]()
        var yi = 0
        for y in points[1] {
            var row = (y,z:[Float]())
            for _ in 0 ..< columns.count {
                row.z.append(zMatrix[yi])
                yi += 1
            }
            rows.append(row)
        }
    }
    
    public var description:String{
        get{
            var s = String("[")
            var i=0
            for yi in 0 ..< rows.count {
                let row = rows[yi]
                var ci = 0
                for obj in row.z {
                    if i>0 {
                        s += ""
                    }
                    i += 1
                    s += String(format: "%2.4f", obj)
                    if i<rows.count*columns.count {
                        if ci<self.columns.count-1 {
                            s += ","
                        }
                        else{
                            s += ";"
                        }
                    }
                    ci += 1
                }
                if (yi<rows.count-1){
                    s += "\n"
                }
            }
            s += "]"
            return s
        }
    }
}

// MARK: - 3D Catmull-Rom piecewise splines
public extension CollectionType where Generator.Element == [Float] {
    
    public func catmullRomSpline(controlPoints:IMPMatrix3D, scale:Float=0)  -> [Float]{
        
        if self.count != 2 {
            fatalError("CollectionType must have 2 dimension Float array with X-points and Y-points lists...")
        }
        
        var curve   = [Float]()
        let xPoints = self[0 as! Self.Index]
        let yPoints = self[count - 1 as! Self.Index]
        
        
        //
        // y-z
        //
        var ysplines = [Float]()
        for i in 0 ..< controlPoints.columns.count {
            
            var points = [float2]()
            
            for yi in 0 ..< controlPoints.rows.count {
                let y = controlPoints.rows[yi].y
                let z = controlPoints.rows[yi].z[i]
                points.append(float2(y,z))
            }
            
            let spline = yPoints.catmullRomSpline(points, scale: 0) as [Float]
            ysplines.appendContentsOf(spline)
        }
        
        let z = IMPMatrix3D(xy: [yPoints,controlPoints.columns], zMatrix: ysplines)
        
        //
        // x-y-z
        //
        for i in 0 ..< yPoints.count {
            
            var points = [float2]()
            
            for xi in 0 ..< controlPoints.columns.count {
                let x = controlPoints.columns[xi]
                let y = z.rows[xi].z[i]
                points.append(float2(x,y))
            }
            let spline = xPoints.catmullRomSpline(points, scale: 0) as [Float]
            curve.appendContentsOf(spline)
        }
        
        if scale>0 {
            var max:Float = 0
            vDSP_maxv(curve, 1, &max, vDSP_Length(curve.count))
            max = scale/max
            vDSP_vsmul(curve, 1, &max, &curve, 1, vDSP_Length(curve.count))
        }

        return curve
    }
}

