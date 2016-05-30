//
//  IMPDisplayTimer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 28.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


//#if os(iOS)
import UIKit

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

public class IMPDisplayTimer {
    
    public enum UpdateCurveOptions{
        case Linear
        case EaseIn
        case EaseOut
        case EaseInOut
        case Decelerate
    }
    
    public typealias UpdateHandler   = ((atTime:NSTimeInterval)->Void)
    public typealias CompleteHandler = ((flag:Bool)->Void)
    
    
    public static func execute(duration duration: NSTimeInterval,
                                        options:IMPTimingCurve = .Default,
                                        update:UpdateHandler,
                                        complete:CompleteHandler? = nil) -> IMPDisplayTimer {
        
        let timer = IMPDisplayTimer(duration: duration,
                                    timingFunction: options.function,
                                    update: update,
                                    complete: complete)
        timer.start()
        return timer
    }
 
    public func cancel() {
        stop(true)
    }

    public func invalidate() {
        stop(false)
    }
    
    var timingFunction:IMPTimingFunction
    var timeElapsed:NSTimeInterval = 0
    
    let updateHandler:UpdateHandler
    let completeHandler:CompleteHandler?
    let duration:NSTimeInterval
    var displayLink:CADisplayLink? = nil
    
    
    init(duration:NSTimeInterval, timingFunction:IMPTimingFunction, update:UpdateHandler, complete:CompleteHandler?){
        self.duration = duration
        self.timingFunction = timingFunction
        updateHandler = update
        completeHandler = complete
    }
    
    func start() {
        if duration > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                
                self.timeElapsed = 0
                
                self.displayLink  = CADisplayLink(target: self, selector: #selector(self.changeAnimation))
                self.displayLink!.frameInterval = 1
                
                self.displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode:NSRunLoopCommonModes)
            }
        }
        else {
            dispatch_async(dispatch_get_main_queue()) {
                self.stop(true)
            }
        }
    }
    
    func stop(flag:Bool) {
        self.displayLink?.invalidate()
        self.displayLink = nil
        if let c = self.completeHandler {
            c(flag: flag)
        }
    }
    
    @objc func changeAnimation() {
        
        guard self.duration > 0    else {return}
        guard let displayLink = self.displayLink else {return}
        
        if timeElapsed > duration {
            stop(true)
            return
        }
        
        timeElapsed += displayLink.duration
        
        var atTime = (timeElapsed/duration).float
        
        let t = NSTimeInterval(timingFunction(t: atTime > 1 ? 1 : atTime))
        
        updateHandler(atTime:  t)
        
    }
}
//#endif
