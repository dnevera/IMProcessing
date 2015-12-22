//
//  IMPDistribution.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import Accelerate

public extension Float{
    
    public func gaussianPoint(fi fi:Float, mu:Float, sigma:Float) -> Float {
        return fi * exp( -(pow(( self - mu ),2)) / (2*pow(sigma, 2)) )
    }
    
    public func gaussianPoint(fi fi:float2, mu:float2, sigma:float2) -> Float {
        
        let c1 = self <= mu.x ? 1.float : 0.float
        let c2 = self >= mu.y ? 1.float : 0.float
        
        let y1 = self.gaussianPoint(fi: fi.x, mu: mu.x, sigma: sigma.x) * c1 + (1.0-c1)
        let y2 = self.gaussianPoint(fi: fi.y, mu: mu.y, sigma: sigma.y) * c2 + (1.0-c2)
        
        return y1 * y2
    }
    
    public func gaussianPoint(mu:Float, sigma:Float) -> Float {
        return self.gaussianPoint(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    public func gaussianPoint(mu:float2, sigma:float2) -> Float {
        return self.gaussianPoint(fi:float2(1), mu: mu, sigma: sigma)
    }
    
    static func range(r:Range<Int>) -> [Float]{
        return range(start: Float(r.startIndex), step: 1, end: Float(r.endIndex))
    }
    
    static func range(start start:Float, step:Float, end:Float) -> [Float] {
        let size       = Int((end-start)/step)
        
        var h:[Float]  = [Float](count: size, repeatedValue: 0)
        var zero:Float = start
        var v:Float    = step
        
        vDSP_vramp(&zero, &v, &h, 1, vDSP_Length(size))
        
        return h
        
    }
}

public extension SequenceType where Generator.Element == Float {
    
    public func gaussianDistribution(fi fi:Float, mu:Float, sigma:Float) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    public func gaussianDistribution(fi fi:float2, mu:float2, sigma:float2) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    public func gaussianDistribution(mu mu:Float, sigma:Float) -> [Float]{
        return self.gaussianDistribution(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    public func gaussianDistribution(mu mu:float2, sigma:float2) -> [Float]{
        return self.gaussianDistribution(fi: float2(1), mu: mu, sigma: sigma)
    }
    
    public static func range(r:Range<Int>) -> [Float]{ return Float.range(r) }
    
    public static func range(start start:Float, step:Float, end:Float) -> [Float] {
        return Float.range(start: start, step: step, end: end)
    }
}
