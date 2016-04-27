//
//  IMPVertex.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import Metal

public extension IMPVertex{
    public init(x:Float, y:Float, z:Float, tx:Float, ty:Float){
        self.position = float3(x,y,z)
        self.texcoord = float2(tx,ty)
    }    
    public var raw:[Float] {
        return [position.x,position.y,position.z,texcoord.x,texcoord.y]
    }
}
