//: [Previous](@previous)

import Foundation
import QuartzCore
import simd

public extension Float {

    public func cubicBesierFunction(c1 c1:float2, c2:float2) -> Float {
        let t = cubicBezierBinarySubdivide(x: self, x1: c1.x, x2: c2.x)
        return cubicBezierCalculate(t: t, a1: c1.y, a2: c2.y)
        
    }
    
    func  A(a1 a1:Float, a2:Float) -> Float { return (1.0 - 3.0 * a2 + 3.0 * a1) }
    func  B(a1 a1:Float, a2:Float) -> Float { return (3.0 * a2 - 6.0 * a1) }
    func  C(a1 a1:Float) -> Float  { return (3.0 * a1) }
    
    func cubicBezierCalculate(t t:Float, a1:Float, a2:Float) -> Float {
        return ((A(a1: a1, a2: a2) * t + B(a1: a1, a2: a2)) * t + C(a1: a1)) * t
    }
    
    func cubicBezierSlope(t t:Float, a1:Float, a2:Float) ->Float {
        return 3.0 * A(a1: a1, a2: a2) * t * t + 2.0 * B(a1: a1, a2: a2) * t + C(a1: a1)
    }
    
    func cubicBezierBinarySubdivide(x x:Float, x1: Float, x2: Float) -> Float {
        let epsilon:Float = 0.0000001
        let maxIterations = 10
        
        var start:Float = 0
        var end:Float = 1
        
        var currentX:Float
        var currentT:Float
        
        var i = 0
        repeat {
            currentT = start + (end - start) / 2
            currentX = cubicBezierCalculate(t: currentT, a1: x1, a2: x2) - x;
            
            if (currentX > 0) {
                end = currentT;
            } else {
                start = currentT;
            }
            
            i += 1
            
        } while (fabs(currentX) > epsilon && i < maxIterations)
        
        return currentT
    }
}

public extension CollectionType where Generator.Element == Float {
    public func cubicBezierSpline(c1 c1:float2, c2:float2, scale:Float=0)-> [Float]{
        var curve = [Float]()
        for x in self {
            curve.append(x.cubicBesierFunction(c1: c1, c2: c2))
        }
        return curve
    }
}


public typealias IMPTimingFunction = ((t:Float) -> Float)

public class IMPMediaTimingFunction {
    let function:CAMediaTimingFunction
    
    var controls = [float2](count: 3, repeatedValue: float2(0))
   
    public init(name: String) {
        function = CAMediaTimingFunction(name: name)
        for i in 0..<3 {
            var coords = [Float](count: 2, repeatedValue: 0)
            function.getControlPointAtIndex(i, values: &coords)
            controls[i] = float2(coords)
        }
    }
    
    public var c0:float2 {
        return controls[0]
    }
    public var c1:float2 {
        return controls[1]
    }
    public var c2:float2 {
        return controls[2]
    }
    
    static var  Default   = IMPMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
    static var  Linear    = IMPMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    static var  EaseIn    = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
    static var  EaseOut   = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
    static var  EaseInOut = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
}


public enum IMPTimingCurve: Float {
    
    case Default
    case Linear
    case EaseIn
    case EaseOut
    case EaseInOut
    
    public var function:IMPTimingFunction {
        var curveFunction:IMPMediaTimingFunction
        
        switch self {
        case .Default:
            curveFunction = IMPMediaTimingFunction.Default
        case .Linear:
            curveFunction = IMPMediaTimingFunction.Linear
        case .EaseIn:
            curveFunction = IMPMediaTimingFunction.EaseIn
        case .EaseOut:
            curveFunction = IMPMediaTimingFunction.EaseOut
        case .EaseInOut:
            curveFunction = IMPMediaTimingFunction.EaseInOut
        }
        
        return { (t) -> Float in
            return t.cubicBesierFunction(c1: curveFunction.c1, c2: curveFunction.c2)
        }
    }
}

let a = Array<Float>(Float(0).stride(to: 1, by: 0.01))

//let s = a.cubicBezierSpline(c1: float2(0.25,0.1), c2: float2(0.25,1))
var s = [Float]()

let c = IMPTimingCurve.EaseInOut
for t in a {
    s.append(c.function(t: t))
}

print("curve = \(s); x = 0:1/(length(curve)-1):1; plot(x,curve);")

let curve1 = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)


for i in 0..<3 {
    var coords = [Float](count: 2, repeatedValue: 0)
    curve1.getControlPointAtIndex(i, values: &coords)
    print(coords)
}

print(curve1)
