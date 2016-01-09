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

extension float3{
    
    func rgb_2_HSV() -> float3 {
        let K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0)
        let p = mix(float4(self.bg, K.wz), float4(self.gb, K.xy), t: IMPstep(self.b, self.g))
        let q = mix(float4(rgb: p.xyw, a: self.r), float4(self.r, p.yzx), t: IMPstep(p.x, self.r))
        
        let e = Float(1.0e-10)
        let d = q.x - min(q.w, q.y)
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x)
    }
    
    func HSV_2_rgb() -> float3 {
        let K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        let p = abs(fract(self.xxx + K.xyz) * 6.0 - K.www);
        return self.z * mix(K.xxx, clamp(p - K.xxx, min: 0.0, max: 1.0), t: self.y);
    }
}

public extension float3{
    
    var hue:Float       { set{ x = hue } get{ return x } }
    var saturation:Float{ set{ y = saturation } get{ return y } }
    var value:Float     { set{ z = value } get{ return z } }
    
    var r:Float{ set{ x = r } get{ return x } }
    var g:Float{ set{ y = g } get{ return y } }
    var b:Float{ set{ z = b } get{ return z } }
    
    var bg:float2 { get{ return float2(b,g) } }
    var gb:float2 { get{ return float2(g,b) } }
    
    var xxx:float3 { get{ return float3(x,x,x) } }
    
    init(color:IMPColor){
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
    
    init(colors:[String]){
        self.init(colors[0].floatValue,colors[1].floatValue,colors[2].floatValue)
    }
}

public extension float4{
    
    var r:Float{ set{ x = r } get{ return x } }
    var g:Float{ set{ y = g } get{ return y } }
    var b:Float{ set{ z = b } get{ return z } }
    var a:Float{ set{ w = a } get{ return w } }
    
    var rgb:float3 {
        set{
            x = rgb.x
            y = rgb.y
            z = rgb.z
        }
        get{
            return float3(x,y,z)
        }
    }
    
    var bg:float2 { get{ return float2(b,g) } }
    var gb:float2 { get{ return float2(g,b) } }
    var xy:float2 { get{ return float2(x,y) } }
    var wz:float2 { get{ return float2(w,z) } }
    
    var xxx:float3 { get{ return float3(x,x,x) } }
    var yyy:float3 { get{ return float3(y,y,y) } }
    var zzz:float3 { get{ return float3(z,z,z) } }
    var www:float3 { get{ return float3(w,w,w) } }
    
    var xyw:float3 { get{ return float3(x,y,w) } }
    var yzx:float3 { get{ return float3(y,z,x) } }
    var xyz:float3 { get{ return float3(x,y,z) } }
    
    init(_ bg:float2, _ wz:float2){
        self.init(bg.x,bg.y,wz.x,wz.y)
    }
    
    init(_ r:Float, _ xyz:float3){
        self.init(r,xyz.x,xyz.y,xyz.z)
    }
    
    init(rgb:float3,a:Float){
        self.init(rgb.x,rgb.y,rgb.z,a)
    }
    
    init(color:IMPColor){
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
    
    init(colors:[String]){
        self.init(colors[0].floatValue,colors[1].floatValue,colors[2].floatValue,colors[3].floatValue)
    }
}

public func / (left:float2,right:Float) -> float2 {
    return float2(left.x/right,left.y/right)
}

public func / (left:float3,right:Float) -> float3 {
    return float3(left.x/right,left.y/right,left.z/right)
}

public func / (left:float4,right:Float) -> float4 {
    return float4(left.x/right,left.y/right,left.z/right,left.w/right)
}

public func * (left:float2,right:Float) -> float2 {
    return float2(left.x*right,left.y*right)
}

public func * (left:float3,right:Float) -> float3 {
    return float3(left.x*right,left.y*right,left.z*right)
}

public func * (left:float4,right:Float) -> float4 {
    return float4(left.x*right,left.y*right,left.z*right,left.w*right)
}
