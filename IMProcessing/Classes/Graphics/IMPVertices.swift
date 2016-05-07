//
//  IMPVertex.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

// MARK: - Vertex structure
public extension IMPVertex{
    public init(x:Float, y:Float, z:Float, tx:Float, ty:Float){
        self.position = float3(x,y,z)
        self.texcoord = float3(tx,ty,1)
    }
    /// Get vertex raw buffer
    public var raw:[Float] {
        return [position.x,position.y,position.z,texcoord.x,texcoord.y,1]
    }
}

///  @brief Vertices protocol
public protocol IMPVertices{
    var vertices:[IMPVertex] {get}
}

// MARK: - Vertices basic read properties
public extension IMPVertices{
    
    /// Raw buffer
    public var raw:[Float]{
        var vertexData = [Float]()
        for vertex in vertices{
            vertexData += vertex.raw
        }
        return vertexData
    }
    
        /// Vertices count
    public var count:Int {
        return vertices.count
    }
    
        /// Vertices buffer langth
    public var length:Int{
        return vertices.count * sizeofValue(vertices[0])
    }
    
    ///  XY plane projection
    ///
    ///  - parameter model: 3D matrix transformation model
    ///
    ///  - returns: x,y coordinates
    public func xyProjection(model model:IMPMatrixModel) -> [float2] {
        var points = [float2]()
        for v in vertices {
            
            let xyzw = float4(v.position.x,v.position.y,v.position.z,1)
            
            let result = float4x4(model.projection) * float4x4(model.transform) * xyzw
            let t = (1+result.z)/2
            let xy = result.xy/t
            
            points.append(xy)
            
        }
        return points
    }
    

    ///  Scale factor to find largest inscribed quadrangle
    ///
    ///  - parameter model: transformation matrix model
    ///
    ///  - returns: scale factor
    public func scaleFactorFor(model model:IMPMatrixModel) -> Float {
        let points = xyProjection(model: model)
        
        var left:Float   = 0
        var right:Float  = 0
        var bottom:Float = 0
        var top:Float    = 0
        
        for p in points {
            
            if p.x<0 {
                if abs(p.x) > left {
                    left = abs(p.x)
                }
            }
            
            if p.x>=0 {
                if abs(p.x) > right {
                    right = abs(p.x)
                }
            }
            
            if p.y<0 {
                if abs(p.y) > bottom {
                    bottom = abs(p.y)
                }
            }
            
            if p.y>=0 {
                if abs(p.y) > top {
                    top = abs(p.y)
                }
            }
        }
        
        let W:Float = 2 
        let H:Float = 2
        let w = left + right
        let h = top + bottom
        
        var scale = min(W / w, H / h)
        
        return scale > 1 ? 2-scale : scale
    }
}

/// Photo plate model
public class IMPPlate:IMPVertices{
    
    /// Plate vertices
    public let vertices:[IMPVertex]
    
    /// Aspect ratio of the plate sides
    public let aspect:Float
    
    /// Processing region
    public let region:IMPRegion
    
    public init(aspect a:Float=1,region r:IMPRegion=IMPRegion()){
        aspect = a
        region = r
        // Front
        let A = IMPVertex(x: -a, y:   1, z:  0, tx: region.left,    ty: region.top)      // left-top
        let B = IMPVertex(x: -a, y:  -1, z:  0, tx: region.left,    ty: 1-region.bottom) // left-bottom
        let C = IMPVertex(x:  a, y:  -1, z:  0, tx: 1-region.right, ty: 1-region.bottom) // right-bottom
        let D = IMPVertex(x:  a, y:   1, z:  0, tx: 1-region.right, ty: region.top)      // right-top
        
        let Q = IMPVertex(x: -1.0*a, y:   1.0, z:  -1, tx: 0, ty: 0) // virtual depth = 0
        let R = IMPVertex(x:  1.0*a, y:   1.0, z:  -1, tx: 0, ty: 0)
        let S = IMPVertex(x: -1.0*a, y:  -1.0, z:  -1, tx: 0, ty: 0)
        let T = IMPVertex(x:  1.0*a, y:  -1.0, z:  -1, tx: 0, ty: 0)
        
//        vertices = [
//            A,B,C ,A,C,D,   // The main front plate. Here we put image.
//            R,T,S ,Q,R,S,   // Back
//            
//            Q,S,B ,Q,B,A,   //Left
//            D,C,T ,D,T,R,   //Right
//            
//            Q,A,D ,Q,D,R,   //Top
//            B,S,T ,B,T,C    //Bot
//        ]

        vertices = [
            A,B,C, A,C,D,   // The main front plate. Here we put image.
        ]
    }
}
