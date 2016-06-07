//
//  IMPMatrixModel.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 27.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal
import simd

public extension IMPTransfromModel{
    public func transform(point point:NSPoint) -> NSPoint {
        let p = transform(point: float2(point.x.float,point.y.float))
        return NSPoint(x:p.x.cgfloat,y:p.y.cgfloat)
    }
}

public struct IMPProjectionModel{
    
    var projectionMatrix  = float4x4(matrix_identity_float4x4)
    
    public var fovy:Float = M_PI.float/2
    public var aspect:Float = 1
    public var near:Float = 0
    public var far:Float = 1
    
    public var matrix:float4x4{
        get {
            let cotan = 1.0 / tanf(fovy / 2.0)
            let m =  [
                [cotan / aspect, 0,     0,                              0],
                [0,              cotan, 0,                              0],
                [0,              0,    (far + near) / (near - far),    -1],
                [0,              0,    (2 * far * near) / (near - far), 0]
            ]
            return float4x4(matrix_float4x4(columns:m))
        }
    }
}

public struct IMPTransfromModel{
    
    public static let flat       = float3(0,0,0)
    public static let left       = float3(0,0,-90.float.radians)
    public static let right      = float3(0,0,90.float.radians)
    public static let degrees180 = float3(0,0,180.float.radians)

    var rotationMatrix    = float4x4(matrix_identity_float4x4)
    var translationMatrix = float4x4(matrix_identity_float4x4)
    var scaleMatrix       = float4x4(matrix_identity_float4x4)
    
    public var projection = IMPProjectionModel()

    public init(translation translation:float3 = float3(0),
                            angle:float3 = float3(0),
                            scale:float3=float3(1),
                            projection:IMPProjectionModel = IMPProjectionModel()){
        defer{
            self.projection = projection
            self.angle = angle
            self.translation = translation
            self.scale = scale
        }
    }

    public static func with(translation translation:float3 = float3(0),
                                        angle:float3 = float3(0),
                                        scale:float3=float3(1),
                                        projection:IMPProjectionModel = IMPProjectionModel()) -> IMPTransfromModel {
        return IMPTransfromModel(translation: translation, angle: angle, scale: scale, projection: projection)
    }

    
    public static func with(model model:IMPTransfromModel,
                                  translation translation:float3?=nil,
                                              angle:float3?=nil,
                                              scale:float3?=nil,
                                            projection:IMPProjectionModel?=nil) -> IMPTransfromModel{
        
        var newModel = IMPTransfromModel(translation: model.translation,
                                         angle: model.angle,
                                         scale: model.scale,
                                         projection: model.projection)
        
        if let translation = translation {
            newModel.translation = translation
        }
        
        if let angle = angle {
            newModel.angle = angle
        }
        
        if let scale = scale {
            newModel.scale = scale
        }
        
        if let projection = projection {
            newModel.projection = projection
        }
        
        return newModel
    }
    
    public var matrix:float4x4 {
        return projection.matrix * (rotationMatrix * translationMatrix * scaleMatrix)
    }
    
    public func transform(vector vector:float3) -> float3 {
        return (matrix * float4(vector.x,vector.y,vector.z,1)).xyz
    }

    public func transform(point point:float2) -> float2 {
        return transform(vector: float3(point.x,point.y,0)).xy
    }
    
    public var angle = float3(0) {
        didSet{
            var a = rotationMatrix.cmatrix
            a.rotate(radians: angle.x, point:float3(1,0,0))
            a.rotate(radians: angle.y, point:float3(0,1,0))
            a.rotate(radians: angle.z, point:float3(0,0,1))
            rotationMatrix = float4x4(a)
        }
    }
    
    public var scale = float3(0) {
        didSet{
            let m0 = scaleMatrix.cmatrix.columns.0
            let m1 = scaleMatrix.cmatrix.columns.1
            let m2 = scaleMatrix.cmatrix.columns.2
            let m3 = scaleMatrix.cmatrix.columns.3
            let f = scale
            
            let rows = [
                [m0.x * f.x, m1.x * f.x, m2.x * f.x, m3.x ],
                [m0.y * f.y, m1.y * f.y, m2.y * f.y, m3.y ],
                [m0.z * f.z, m1.z * f.z, m2.z * f.z, m3.z ],
                [m0.w,     m1.w,     m2.w,     m3.w ],
                ]
            
            scaleMatrix =  float4x4(rows:rows)
        }
    }
    
    public var translation = float3(0){
        didSet{
            let m0 = translationMatrix.cmatrix.columns.0
            let m1 = translationMatrix.cmatrix.columns.1
            let m2 = translationMatrix.cmatrix.columns.2
            let m3 = translationMatrix.cmatrix.columns.3
            
            var p = translation
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
            translationMatrix = translationMatrix * float4x4(m)
        }
    }
}


//// MARK: - Matrix transformation model
//public extension IMPMatrixModel {
//    
//    public static let flat       = float3(0,0,0)
//    public static let left       = float3(0,0,-90.float.radians)
//    public static let right      = float3(0,0,90.float.radians)
//    public static let degrees180 = float3(0,0,180.float.radians)
//    
//    
//    //public var transformation:float4x4 {
//    //    return projection * tra
//    //}
//    
//    /// Identity matrix
//    public static let identity = IMPMatrixModel.init(
//        projection: matrix_identity_float4x4,
//        transform:  matrix_identity_float4x4,
//        translation: matrix_identity_float4x4)
//    
//    /// Scale operation
//    public mutating func scale(x x:Float, y:Float, z:Float)  {
//        transform.scale(factor: float3(x,y,z))
//    }
//
//    public mutating func scale(factor vector:float3)  {
//        transform.scale(factor: vector)
//    }
//
//    /// Translate operation
//    public mutating func translate(x x:Float, y:Float, z:Float){
//        transform.translate(position: float3(x,y,z))
//    }
//
//    /// Translate operation
//    public mutating func translate(position vector:float3){
//        transform.translate(position: vector)
//    }
//
//    /// Rotate around operation
//    public mutating func rotate(radians angle:float3){
//        transform.rotate(radians: angle.x, point:float3(1,0,0))
//        transform.rotate(radians: angle.y, point:float3(0,1,0))
//        transform.rotate(radians: angle.z, point:float3(0,0,1))
//    }
//
//    public mutating func move(position position:float3){
//        //let t = float4(position.x,position.y,position.z,1)
//        //translation.move(position: matrix_multiply(t, transform).xyz)
//        translation.move(position: position)
//        //transform.move(position: position)
//    }
//
//    public mutating func move(x x:Float, y:Float, z:Float=0){
//        move(position: float3(x,y,z))
//    }
//
//    /// Transition on xy-plane
//    public mutating func move(position position:float2){
//        move(position: float3(position.x,position.y,0))
//    }
//
//    public mutating func move(x x:Float, y:Float){
//        move(position: float2(x,y))
//    }
// 
//    /// Set new perspective model
//    public mutating func setPerspective(radians fovyRadians:Float, aspect:Float, nearZ:Float, farZ:Float) {
//        let cotan = 1.0 / tanf(fovyRadians / 2.0)
//        
//        let m =  [
//            [cotan / aspect, 0,     0,                                  0],
//            [0,              cotan, 0,                                  0],
//            [0,              0,    (farZ + nearZ) / (nearZ - farZ),    -1],
//            [0,              0,    (2 * farZ * nearZ) / (nearZ - farZ), 0]
//        ]
//                
//        projection = matrix_float4x4(columns:m)
//    }
//}
