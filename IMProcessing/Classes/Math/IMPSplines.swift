//
//  IMPSplines.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 09.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation

// MARK: - Splines
public extension CollectionType where Generator.Element == Float {
    
    ///  Create cubic spline curve from linear collection of Floats with certain control points
    ///
    ///  - parameter controls: list of (x,y) control points
    ///
    ///  - returns: interpolated list of points
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
                point = point/scale
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
        
        for var i=0; i<count; i++ {
            X[i]=points[i].x
            Y[i]=points[i].y
        }
        
        
        let start = 0
        let end   = count
        
        var A =  X [start+1] - X [start]
        var B = (Y [start+1] - Y [start]) / A
        
        S [start] = B
        
        var j=0
        
        // Slopes here are a weighted average of the slopes
        // to each of the adjcent control points.
        
        for j = start + 2; j < end; ++j {
            
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
            
            for j = start+1; j < end - 1; ++j {
                
                A = (X [j+1] - X [j-1]) * 2.0
                
                E [j] = (X [j+1] - X [j]) / A
                F [j] = (X [j] - X [j-1]) / A
                G [j] = 1.5 * S [j]
                
            }
            
            for j = start+1; j < end; ++j {
                
                A = 1.0 - F [j-1] * E [j]
                
                if j != end-1 { F [j] = F[j]/A }
                
                G [j] = (G [j] - G [j-1] * E [j]) / A
                
            }
            
            for j = end - 2; j >= start; --j {
                G [j] = G [j] - F [j] * G [j+1]
            }
            
            for j = start; j < end; ++j {
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
