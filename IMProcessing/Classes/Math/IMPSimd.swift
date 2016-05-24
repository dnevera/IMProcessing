//
//  IMPSimd.swift
//  IMPGeometryTest
//
//  Created by denn on 02.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import simd


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
    
    public mutating func translate(x x:Float, y:Float, z:Float){
        let m0 = self.columns.0
        let m1 = self.columns.1
        let m2 = self.columns.2
        let m3 = self.columns.3
        self = matrix_float4x4(columns: (
            m0,
            m1,
            m2,
            float4(
                m0.x * x + m0.y * y + m0.z * z + m0.w,
                m1.x * x + m1.y * y + m1.z * z + m1.w,
                m2.x * x + m2.y * y + m2.z * z + m2.w,
                m3.x * x + m3.y * y + m3.z * z + m3.w)
            )
        )
    }
    
    public mutating func scale(x x:Float, y:Float, z:Float)  {
        let m0 = self.columns.0
        let m1 = self.columns.1
        let m2 = self.columns.2
        let m3 = self.columns.3
        
        let rows = [
            [m0.x * x, m1.x * x, m2.x * x, m3.x ],
            [m0.y * y, m1.y * y, m2.y * y, m3.y ],
            [m0.z * z, m1.z * z, m2.z * z, m3.z ],
            [m0.w,     m1.w,     m2.w,     m3.w ],
            ]
        
        self = matrix_float4x4(rows: rows)
    }
  
    public mutating func rotate(radians radians:Float, x:Float, y:Float, z:Float) {
        
        let v =  normalize(float3(x,y,z))
        let cos = cosf(radians)
        let cosp = 1.0 - cos
        let sin = sinf(radians)
        
        let m = [
            [cos  + cosp * v[0] * v[0],
                cosp * v[0] * v[1] + v[2] * sin,
                cosp * v[0] * v[2] - v[1] * sin,
                0.0],
            [cosp * v[0] * v[1] - v[2] * sin,
                cos  + cosp * v[1] * v[1],
                cosp * v[1] * v[2] + v[0] * sin,
                0.0],
            [cosp * v[0] * v[2] + v[1] * sin,
                cosp * v[1] * v[2] - v[0] * sin,
                cos  + cosp * v[2] * v[2],
                0.0],
            [0.0,0.0,0.0,
                1.0]
        ]
        
        self = matrix_multiply(self,  matrix_float4x4(rows: m))
    }
    
    public mutating func move(x x:Float, y: Float){
        self = matrix_multiply(self,
                               matrix_float4x4(columns:[
                                float4(1, 0, 0, x),
                                float4(0, 1, 0, y),
                                float4(0, 0, 1, 0),
                                float4(0, 0, 0, 1)]))
    }
}

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