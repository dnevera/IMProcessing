//
//  IMPVertex.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
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
    public func xyProjection(model:IMPMatrixModel) -> [float2] {
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
        
        vertices = [
            A,B,C, A,C,D,   // The main front plate. Here we put image.
        ]
    }
}
