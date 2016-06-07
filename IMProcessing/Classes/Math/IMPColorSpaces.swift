//
//  IMPColorSpaces.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 23.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import simd

func IMPstep(edge:Float, _ x:Float) -> Float {
    return step(x, edge: edge)
}

public extension float3{
    
    public func tohsv() -> float3 {
        let K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0)
        let p = mix(float4(self.bg, K.wz), float4(self.gb, K.xy), t: IMPstep(self.b, self.g))
        let q = mix(float4(rgb: p.xyw, a: self.r), float4(self.r, p.yzx), t: IMPstep(p.x, self.r))
        
        let e = Float(1.0e-10)
        let d = q.x - min(q.w, q.y)
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x)
    }
    
    public func torgb() -> float3 {
        let K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        let p = abs(fract(self.xxx + K.xyz) * 6.0 - K.www);
        return self.z * mix(K.xxx, clamp(p - K.xxx, min: 0.0, max: 1.0), t: self.y);
    }
}

public extension float3{
    
    public var hue:Float       { set{ x = hue } get{ return x } }
    public var saturation:Float{ set{ y = saturation } get{ return y } }
    public var value:Float     { set{ z = value } get{ return z } }
    
    public var r:Float{ set{ x = r } get{ return x } }
    public var g:Float{ set{ y = g } get{ return y } }
    public var b:Float{ set{ z = b } get{ return z } }
    
    public var bg:float2 { get{ return float2(b,g) } }
    public var gb:float2 { get{ return float2(g,b) } }
    
    public func normalized() -> float3 {
        var vector = self
        var sum = vector.x+vector.y+vector.z
        if (sum==0.0) {
            sum = 1.0
        }
        vector.x/=sum
        vector.y/=sum
        vector.z/=sum
        return vector
    }

    public init(color:IMPColor){
        #if os(iOS)
            var r = CGFloat(0)
            var g = CGFloat(0)
            var b = CGFloat(0)
            var a = CGFloat(0)
            color.getRed(&r, green:&g, blue:&b, alpha:&a)
            self.init(Float(r),Float(g),Float(b))
        #else
            self.init(Float(color.redComponent),Float(color.greenComponent),Float(color.blueComponent))
        #endif
    }
    
    public init(colors:[String]){
        self.init(colors[0].floatValue,colors[1].floatValue,colors[2].floatValue)
    }
}

public extension float4{
    
    public var r:Float{ set{ x = r } get{ return x } }
    public var g:Float{ set{ y = g } get{ return y } }
    public var b:Float{ set{ z = b } get{ return z } }
    public var a:Float{ set{ w = a } get{ return w } }
    
    public var rgb:float3 {
        set{
            x = rgb.x
            y = rgb.y
            z = rgb.z
        }
        get{
            return float3(x,y,z)
        }
    }
    
    public var bg:float2 { get{ return float2(b,g) } }
    public var gb:float2 { get{ return float2(g,b) } }
    
    public func normalized() -> float4 {
        var vector = self
        var sum = vector.x+vector.y+vector.z+vector.w
        if (sum==0.0) {
            sum = 1.0
        }
        vector.x/=sum
        vector.y/=sum
        vector.z/=sum
        vector.w/=sum
        return vector
    }
    
    public init(_ bg:float2, _ wz:float2){
        self.init(bg.x,bg.y,wz.x,wz.y)
    }
    
    public init(_ r:Float, _ xyz:float3){
        self.init(r,xyz.x,xyz.y,xyz.z)
    }
    
    public init(rgb:float3,a:Float){
        self.init(rgb.x,rgb.y,rgb.z,a)
    }
    
    public init(color:IMPColor){
        #if os(iOS)
            var r = CGFloat(0)
            var g = CGFloat(0)
            var b = CGFloat(0)
            var a = CGFloat(0)
            color.getRed(&r, green:&g, blue:&b, alpha:&a)
            self.init(Float(r),Float(g),Float(b),Float(a))
        #else
            self.init(Float(color.redComponent),Float(color.greenComponent),Float(color.blueComponent),Float(color.alphaComponent))
        #endif
    }
    
    public init(colors:[String]){
        self.init(colors[0].floatValue,colors[1].floatValue,colors[2].floatValue,colors[3].floatValue)
    }
}

