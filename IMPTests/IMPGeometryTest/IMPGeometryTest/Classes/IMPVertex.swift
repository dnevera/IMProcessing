//
//  IMPVertex.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import Metal

public struct IMPQuad {
    var left_bottom  = float2( -1, -1)
    var left_top     = float2( -1,  1)
    var right_bottom = float2(  1, -1)
    var right_top    = float2(  1,  1)
    
    public func basis(points:IMPQuad) -> float3x3 {
        let A = float3x3(rows:[
            [points.left_bottom.x,points.left_top.x,points.right_bottom.x],
            [points.left_bottom.y,points.left_top.y,points.right_bottom.y],
            [1,1,1]
            ])
        let B = float3(points.right_top.x,points.right_top.y,1)
        let X = A.inverse * B
        // C = (Ai)*B
        return A * float3x3(diagonal: X)
    }
    
    public func projection2D(destination d:IMPQuad) -> float4x4 {
        let t = basis(d) * basis(self).inverse
        
        return float4x4(rows: [
            [t[0,0], t[1,0], 0, t[2,0]],
            [t[0,1], t[1,1], 0, t[2,1]],
            [0     , 0     , 1, 0   ],
            [t[0,2], t[1,2], 0, t[2,2]]
            ])
    }
}

public extension IMPVertex{
    public init(x:Float, y:Float, z:Float, tx:Float, ty:Float){
        self.position = float3(x,y,z)
        self.texcoord = float3(tx,ty,1)
    }
    public var raw:[Float] {
        return [position.x,position.y,position.z,texcoord.x,texcoord.y,1]
    }
}

public protocol IMPVertices{
    var vertices:[IMPVertex] {get}
}


public extension IMPVertices{
    
    public var raw:[Float]{
        var vertexData = [Float]()
        for vertex in vertices{
            vertexData += vertex.raw
        }
        return vertexData
    }
    
    public var count:Int {
        return vertices.count
    }
    
    public var length:Int{
        return vertices.count * sizeofValue(vertices[0])
    }
    
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

public class IMPPlate:IMPVertices{
    
    public let vertices:[IMPVertex]
    public let aspect:Float
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
