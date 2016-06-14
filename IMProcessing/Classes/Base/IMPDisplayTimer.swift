//
//  IMPDisplayTimer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 28.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

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

public class IMPDisplayTimer:NSObject {
    
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
                                        resolution:Int = 20,
                                        update:UpdateHandler,
                                        complete:CompleteHandler? = nil) -> IMPDisplayTimer {
        
        let timer = IMPDisplayTimer(duration: duration,
                                    timingFunction: options.function,
                                    resolution: resolution,
                                    update: update,
                                    complete: complete)
        IMPDisplayTimer.timerList.append(timer)
        timer.start()
        return timer
    }

    
    public static func cancelAll() {
        while let t = IMPDisplayTimer.timerList.last {
            t.cancel()
        }
    }

    public static func invalidateAll() {
        while let t = IMPDisplayTimer.timerList.last {
            t.invalidate()
        }
    }

    public func cancel() {
        stop(true)
    }

    public func invalidate() {
        stop(false)
    }
    
    static var timerList = [IMPDisplayTimer]()
    
    var timingFunction:IMPTimingFunction
    var timeElapsed:NSTimeInterval = 0
    
    let updateHandler:UpdateHandler
    let completeHandler:CompleteHandler?
    let duration:NSTimeInterval
    let resulution:Int
    var timer:IMPRTTimer? = nil
    
    
    private init(duration:NSTimeInterval,
                 timingFunction:IMPTimingFunction,
                 resolution r:Int,
                 update:UpdateHandler,
                 complete:CompleteHandler?){
        self.resulution = r
        self.duration = duration
        self.timingFunction = timingFunction
        updateHandler = update
        completeHandler = complete
    }
    
    func removeFromList()  {
        if let index = IMPDisplayTimer.timerList.indexOf(self) {
            IMPDisplayTimer.timerList.removeAtIndex(index)
        }
    }
    
    func start() {
        if duration > 0 {
            
            self.timeElapsed = 0
            
            self.timer = IMPRTTimer(usec: 50, update: { (timestamp, duration) in
                
                guard self.duration > 0    else {return}
                
                if self.timeElapsed > self.duration {
                    self.stop(true)
                    return
                }
                
                self.timeElapsed +=  NSTimeInterval(duration)/NSTimeInterval(IMPRTTimer.nanos_per_sec)
                
                let atTime = (self.timeElapsed/self.duration).float
                
                let t = NSTimeInterval(self.timingFunction(t: atTime > 1 ? 1 : atTime))
                
                //dispatch_async(dispatch_get_main_queue()) {
                    self.updateHandler(atTime:  t)
                //}
            })
            
            self.timer?.start()
        }
        else {
            self.stop(true)
        }
    }
    
    func stop(flag:Bool) {
        removeFromList()
        timer?.stop()
        timer = nil
        if let c = self.completeHandler {
            dispatch_async(dispatch_get_main_queue()) {
                c(flag: flag)
            }
        }
    }
}
//#endif
