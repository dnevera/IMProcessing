//
//  IMPVertex.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import Metal

public struct IMPVertex{
    public var x,y,z: Float     // position data
    public var tx,ty: Float     // texture coords
    var raw:[Float] {
        return [x,y,z,tx,ty]
    }
}
