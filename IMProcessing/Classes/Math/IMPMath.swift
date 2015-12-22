//
//  IMPMath.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation

extension Double{
    var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
}

extension Float{
    var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }
}