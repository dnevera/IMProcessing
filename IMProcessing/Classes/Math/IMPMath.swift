//
//  IMPMath.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import GLKit

public extension Double{
    
    public var int:Int{
        get{
            return Int(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }

    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
}

public extension Float{
    
    public var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }
    public var int:Int{
        get{
            return self.isFinite ? Int(self):Int.max
        }
        set(newValue){
            self = Float(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }    
}


public extension Float {
    /// Convert radians to degrees
    public var degrees:Float{
        return self * (180 / M_PI.float)
    }
    /// Convert degrees to radians
    public var radians:Float{
        return self * (M_PI.float / 180)
    }
}

public extension Int {
    
    public var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
    
    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
}

public extension CGFloat{
    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = CGFloat(newValue)
        }
    }
}

public func * (left:MTLSize,right:(Float,Float,Float)) -> MTLSize {
    return MTLSize(
        width: Int(Float(left.width)*right.0),
        height: Int(Float(left.height)*right.1),
        depth: Int(Float(left.height)*right.2))
}

public func * (left:CGSize,right:Float) -> CGSize {
    return CGSize(
        width: left.width * right,
        height: left.height * right
    )
}

public func / (left:CGSize,right:Float) -> CGSize {
    return CGSize(
        width: left.width / right,
        height: left.height / right
    )
}


public func != (left:MTLSize,right:MTLSize) ->Bool {
    return (left.width != right.width && left.height != right.height && left.depth != right.depth)
}

public func == (left:MTLSize,right:MTLSize) ->Bool {
    return !(left != right)
}

public func > (left:CGFloat, right:Float) -> Bool{
    return left.float>right
}

public func >= (left:CGFloat, right:Float) -> Bool{
    return left.float>right
}

public func == (left:CGFloat, right:Float) -> Bool{
    return left.float==right
}

public func < (left:CGFloat, right:Float) -> Bool{
    return left.float<right
}

public func <= (left:CGFloat, right:Float) -> Bool{
    return left.float<=right
}

public func / (left:CGFloat, right:Float) -> CGFloat {
    return CGFloat(left.float/right)
}

public func * (left:CGFloat, right:Float) -> CGFloat {
    return CGFloat(left.float*right)
}

public func / (left:Int, right:Float) -> Float {
    return left.float/right
}

public func * (left:Int, right:Float) -> Float {
    return left.float*right
}
