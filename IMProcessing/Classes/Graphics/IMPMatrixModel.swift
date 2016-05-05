//
//  IMPMatrixModel.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 27.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal
import simd


// MARK: - Matrix transformation model
public extension IMPMatrixModel {
    
    public static let flat       = float3(0,0,0)
    public static let left       = float3(0,0,-90.float.radians)
    public static let right      = float3(0,0,90.float.radians)
    public static let degrees180 = float3(0,0,180.float.radians)
    
    /// Identity matrix
    public static let identity = IMPMatrixModel.init(
        projection: matrix_identity_float4x4,
        transform:  matrix_identity_float4x4,
        transition: matrix_identity_float4x4)
    
    /// Scale operation
    public mutating func scale(x x:Float, y:Float, z:Float)  {
        transform.scale(x: x, y: y, z: z)
    }

    public mutating func scale(vector vector:float3)  {
        transform.scale(x: vector.x, y: vector.y, z: vector.z)
    }

    /// Translate operation
    public mutating func translate(x x:Float, y:Float, z:Float){
        transform.translate(x: x, y: y, z: z)
    }

    /// Translate operation
    public mutating func translate(vector vector:float3){
        transform.translate(x: vector.x, y: vector.y, z: vector.z)
    }

    /// Rotate around operation
    public mutating func rotateAround(x x:Float, y:Float, z:Float){
        transform.rotate(radians: x, x: 1, y: 0, z: 0)
        transform.rotate(radians: y, x: 0, y: 1, z: 0)
        transform.rotate(radians: z, x: 0, y: 0, z: 1)
    }
 
    /// Rotate around operation
    public mutating func rotateAround(vector vector:float3){
        transform.rotate(radians: vector.x, x: 1, y: 0, z: 0)
        transform.rotate(radians: vector.y, x: 0, y: 1, z: 0)
        transform.rotate(radians: vector.z, x: 0, y: 0, z: 1)
    }

    /// Transition on xy-plane
    public mutating func move(x x:Float, y:Float){
        transition.move(x: x, y: y)
    }
 
    /// Transition on xy-plane
    public mutating func move(vector vector:float2){
        transition.move(x: vector.x, y: vector.y)
    }
    
    /// Set new perspective model
    public mutating func setPerspective(radians fovyRadians:Float, aspect:Float, nearZ:Float, farZ:Float) {
        let cotan = 1.0 / tanf(fovyRadians / 2.0)
        
        let m =  [
            [cotan / aspect, 0,     0,                                  0],
            [0,              cotan, 0,                                  0],
            [0,              0,    (farZ + nearZ) / (nearZ - farZ),    -1],
            [0,              0,    (2 * farZ * nearZ) / (nearZ - farZ), 0]
        ]
        projection = matrix_float4x4(columns:m)
    }    
}
