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
    public static let right45    = float3(0,0,45.float.radians)
    public static let left45     = float3(0,0,-45.float.radians)

    var rotationMatrix    = float4x4(matrix_identity_float4x4)
    var translationMatrix = float4x4(matrix_identity_float4x4)
    var scaleMatrix       = float4x4(matrix_identity_float4x4)
    
    public var projection = IMPProjectionModel()
    
    public init(translation:float3 = float3(0),
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

    
    public func lerp(final final:IMPTransfromModel, t:Float) -> IMPTransfromModel {
        var f = self
        f.translation = f.translation.lerp(final: final.translation, t: t)
        f.angle = f.angle.lerp(final: final.angle, t: t)
        f.scale = f.scale.lerp(final: final.scale, t: t)
        return f
    }
    
    public static func with(model model:IMPTransfromModel,
                                  translation:float3?=nil,
                                              angle:float3?=nil,
                                              scale:float3?=nil,
                                            projection:IMPProjectionModel?=nil) -> IMPTransfromModel{
        
        var newModel = IMPTransfromModel() 
        
        if let translation = translation {
            newModel.translation = translation
        }
        else {
            newModel.translation = model.translation
        }
        
        if let angle = angle {
            newModel.angle = angle
        }
        else {
            newModel.angle = model.angle
        }
        
        if let scale = scale {
            newModel.scale = scale
        }
        else {
            newModel.scale = model.scale
        }
        
        if let projection = projection {
            newModel.projection = projection
        }
        else{
            newModel.projection = model.projection
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
            var s = scaleMatrix.cmatrix
            s.scale(factor: scale)
            scaleMatrix =  float4x4(s)
        }
    }
    
    public var translation = float3(0){
        didSet{
            var t = translationMatrix.cmatrix
            t.translate(position: translation)
            translationMatrix = float4x4(t)
        }
    }
}