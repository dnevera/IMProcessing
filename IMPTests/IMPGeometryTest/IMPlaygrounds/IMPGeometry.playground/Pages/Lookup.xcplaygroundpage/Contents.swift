//: [Previous](@previous)

import Foundation
import Accelerate
import simd

public extension Float {
    public func lerp(final final:Float, t:Float) -> Float {
        return (1-t)*self + t*final
    }
}

func sample(value value:Float, table:[Float], start:Int) -> Float{
    
    var x:Float = 0
    var y:Float = 1
    
    let v = table[start]
    
    if abs(v - value) <= 1e-4 {
        return v
    }
    
    if v < value {
        
        for i in start..<table.count {
            
            let nv = table[i]
            
            if abs(value - nv) <= 1e-6 {
                return value
            }
            else if nv > value {
                y = nv
                break
            }
            
            x = nv
        }
    }
    else {
        for i in start.stride(to: 0, by: -1) {
            
            let nv = table[i]
            
            if abs(value - nv) <= 1e-6 {
                return value
            }
            else if nv < value {
                x = nv
                break
            }
            
            y = nv
        }
    }
    
    return x.lerp(final: y, t: value)
}

sample(value: 0.01, table: [Float](arrayLiteral: 0, 0.1, 0.3, 0.6, 0.7, 1), start: 2)
