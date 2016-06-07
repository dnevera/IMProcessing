//
//  IMPSimd.swift
//  IMPGeometryTest
//
//  Created by denn on 02.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import simd

// MARK: - Vector extensions

public extension Float {
    public func lerp(final final:Float, t:Float) -> Float {
        return (1-t)*self + t*final
    }
}

public extension float2 {
    public func lerp(final final:float2, t:Float) -> float2 {
        return (1-t)*self + t*final
    }
}

public extension float3 {
    public func lerp(final final:float3, t:Float) -> float3 {
        return (1-t)*self + t*final
    }
    
    
    public var xy:float2 { get{ return float2(x,y) }   set{self.x=newValue.x; self.y=newValue.y}}
    public var xz:float2 { get{ return float2(x,z) }   set{self.x=newValue.x; self.z=newValue.y}}
    public var yz:float2 { get{ return float2(y,z) }   set{self.y=newValue.x; self.z=newValue.y}}
    public var xxx:float3 { get{ return float3(x,x,x)}}
    public var yyy:float3 { get{ return float3(y,y,y)}}
    public var zzz:float3 { get{ return float3(z,z,z)}}
}

public extension float4 {
    public func lerp(final final:float4, t:Float) -> float4 {
        return (1-t)*self + t*final
    }
    
    public var xy:float2 { get{ return float2(x,y) } set{self.x=newValue.x; self.y=newValue.y}}
    public var wz:float2 { get{ return float2(w,z) } set{self.w=newValue.x; self.z=newValue.y}}
    
    public var xxx:float3 { get{ return float3(x,x,x) } }
    public var yyy:float3 { get{ return float3(y,y,y) } }
    public var zzz:float3 { get{ return float3(z,z,z) } }
    public var www:float3 { get{ return float3(w,w,w) } }
    
    public var xyw:float3 { get{ return float3(x,y,w) } set{self.x=newValue.x; self.y=newValue.y; self.w=newValue.z}}
    public var yzx:float3 { get{ return float3(y,z,x) } set{self.y=newValue.x; self.z=newValue.y; self.x=newValue.z}}
    public var xyz:float3 { get{ return float3(x,y,z) } set{self.x=newValue.x; self.y=newValue.y; self.z=newValue.z}}
}


// MARK: - Matrix constructors
public extension float3x3 {
    public init(rows: [[Float]]){
        self.init(matrix_from_rows(vector_float3(rows[0]), vector_float3(rows[1]), vector_float3(rows[2])))
    }
    
    public init(_ columns: [[Float]]){
        self.init(matrix_from_columns(vector_float3(columns[0]), vector_float3(columns[1]), vector_float3(columns[2])))
    }
}

public extension float4x4 {
    public init(rows: [[Float]]){
        self.init(matrix_from_rows(float4(rows[0]), float4(rows[1]), float4(rows[2]),float4(rows[3])))
    }
}

public extension matrix_float3x3{
    
    public init(rows: (float3,float3,float3)){
        self = matrix_from_rows(rows.0, rows.1, rows.2)
    }
    
    public init(rows: [float3]){
        self = matrix_from_rows(rows[0], rows[1], rows[2])
    }
    
    public init(columns: [float3]){
        self = matrix_from_columns(columns[0], columns[1], columns[2])
    }
    
    public init(rows: [[Float]]){
        self = matrix_from_rows(float3(rows[0]), float3(rows[1]), float3(rows[2]))
    }
    
    public init(columns: [[Float]]){
        self = matrix_from_columns(float3(columns[0]), float3(columns[1]), float3(columns[2]))
    }
    
    public func toFloat3x3() -> float3x3 {
        return float3x3(self)
    }    
}


public extension matrix_float4x4{
    
    public init(rows: (float4,float4,float4,float4)){
        self = matrix_from_rows(rows.0, rows.1, rows.2, rows.3)
    }
    
    public init(rows: [float4]){
        self = matrix_from_rows(rows[0], rows[1], rows[2], rows[3])
    }
    
    public init(columns: [float4]){
        self = matrix_from_columns(columns[0], columns[1], columns[2], columns[3])
    }
    
    public init(rows: [[Float]]){
        self = matrix_from_rows(float4(rows[0]), float4(rows[1]), float4(rows[2]), float4(rows[3]))
    }
    
    public init(columns: [[Float]]){
        self = matrix_from_columns(float4(columns[0]), float4(columns[1]), float4(columns[2]), float4(columns[3]))
    }
    
    public func toFloat4x4() -> float4x4 {
        return float4x4(self)
    }
}

// MARK: - Basic matrix transformations
public extension matrix_float4x4 {
    
    public mutating func translate(position p:float3){
        let m0 = self.columns.0
        let m1 = self.columns.1
        let m2 = self.columns.2
        let m3 = self.columns.3
        let m = matrix_float4x4(columns: (
            m0,
            m1,
            m2,
            float4(
                m0.x * p.x + m0.y * p.y + m0.z * p.z + m0.w,
                m1.x * p.x + m1.y * p.y + m1.z * p.z + m1.w,
                m2.x * p.x + m2.y * p.y + m2.z * p.z + m2.w,
                m3.x * p.x + m3.y * p.y + m3.z * p.z + m3.w)
            )
        )
        
        self = matrix_multiply(m,self)
    }
    
    public mutating func scale(factor f:float3)  {
        let m0 = self.columns.0
        let m1 = self.columns.1
        let m2 = self.columns.2
        let m3 = self.columns.3
        
        let rows = [
            [m0.x * f.x, m1.x * f.x, m2.x * f.x, m3.x ],
            [m0.y * f.y, m1.y * f.y, m2.y * f.y, m3.y ],
            [m0.z * f.z, m1.z * f.z, m2.z * f.z, m3.z ],
            [m0.w,     m1.w,     m2.w,     m3.w ],
            ]
        
        self = matrix_float4x4(rows: rows)
    }
  
    public mutating func rotate(radians radians:Float, point:float3) {
        
        let v =  normalize(point)
        let cos = cosf(radians)
        let cosp = 1.0 - cos
        let sin = sinf(radians)
        
        let m = [
            [cos  + cosp * v[0] * v[0],
             cosp * v[0] * v[1] + v[2] * sin,
             cosp * v[0] * v[2] - v[1] * sin,
             0],
            [cosp * v[0] * v[1] - v[2] * sin,
             cos  + cosp * v[1] * v[1],
             cosp * v[1] * v[2] + v[0] * sin,
             0],
            [cosp * v[0] * v[2] + v[1] * sin,
             cosp * v[1] * v[2] - v[0] * sin,
             cos  + cosp * v[2] * v[2],
             0],
            [0.0, 0.0, 0.0, 1.0]
        ]
        
        self = matrix_multiply(matrix_float4x4(rows: m),self)
    }
    
    
//    public mutating func rotate(radians radians:Float, axis:float3=float3(0,0,1), about point:float3=float3(0)) {
//        var rotation = matrix_identity_float4x4
//        
//        var t        = matrix_float4x4(rows:[
//            float4(1, 0, 0, point.x),
//            float4(0, 1, 0, point.y),
//            float4(0, 0, 1, point.z),
//            float4(0, 0, 0, 1)])
//        var ti       = matrix_invert(t)
//        
//        rotation.rotate(radians: radians, point: axis)
//     
//        let r = (float4x4(ti) * float4x4(rotation) * float4x4(t)).cmatrix
//        
//        self = matrix_multiply(self,r)
//        
//    }
//    
//    public mutating func rotate_(radians radians:Float, axis rot:float3, about point:float3) {
//        
//        let c = cos(radians)
//        let s = sin(radians)
//        let t = 1.0 - c
//        
//        let m00 = c + rot.x*rot.x*t
//        let m11 = c + rot.y*rot.y*t
//        let m22 = c + rot.z*rot.z*t
//        
//        
//        var tmp1 = rot.x*rot.y*t
//        var tmp2 = rot.z*s
//        let m10  = tmp1 + tmp2
//        let m01  = tmp1 - tmp2
//        
//        
//        tmp1 = rot.x*rot.z*t
//        tmp2 = rot.y*s
//        let m20 = tmp1 - tmp2
//        let m02 = tmp1 + tmp2
//        
//        tmp1 = rot.y*rot.z*t
//        tmp2 = rot.x*s
//        let m21 = tmp1 + tmp2
//        let m12 = tmp1 - tmp2
//        
//        
//        let a1 = point.x
//        let a2 = point.y
//        let a3 = point.z
//        
//        let m03 = a1 - a1 * m00 - a2 * m01 - a3 * m02
//        let m13 = a2 - a1 * m10 - a2 * m11 - a3 * m12
//        let m23 = a3 - a1 * m20 - a2 * m21 - a3 * m22
//        let m30:Float = 0
//        let m31:Float = 0
//        let m32:Float = 0
//        let m33:Float = 1
//        
//        
//        let m = [
//            [m00,m01,m02,m03],
//            [m10,m11,m12,m23],
//            [m20,m21,m22,m23],
//            [m30,m31,m32,m33]
//        ]
//        
//        self = matrix_multiply(self,  matrix_float4x4(rows: m))
//    }
//    
    public mutating func move(position position:float3){
        //var v = float4(position.x, position.y, position.z,1)
        //v = matrix_multiply(v, self)
        var v = position
        
        self = matrix_multiply(self,matrix_float4x4(rows:[
                                float4(1, 0, 0, v.x),
                                float4(0, 1, 0, v.y),
                                float4(0, 0, 1, v.z),
                                float4(0, 0, 0, 1)]))
    }
    
    // 2D operations under XY-plain
    public mutating func move(position position:float2){
        move(position: float3(position.x,position.y,0))
    }
}

// MARK: - Basic algebra
public extension float2x2 {
    var determinant:Float {
        get {
            let t = cmatrix.columns
            return t.0.x*t.1.y - t.0.y*t.1.x
        }
    }
}

public extension float3x3 {
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

extension float2: Equatable {}
extension float3: Equatable {}
extension float4: Equatable {}

public func == (left:float2,right:float2) -> Bool {
    return (left.x == right.x) && (left.y == right.y)
}

public func != (left:float2,right:float2) -> Bool {
    return !(left == right)
}

public func == (left:float3,right:float3) -> Bool {
    return (left.x == right.x) && (left.y == right.y) && (left.z == right.z)
}

public func != (left:float3,right:float3) -> Bool {
    return !(left == right)
}

public func == (left:float4,right:float4) -> Bool {
    return (left.x == right.x) && (left.y == right.y) && (left.z == right.z) && (left.w == right.w)
}

public func != (left:float4,right:float4) -> Bool {
    return !(left == right)
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