//
//  IMPDisplayTimer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 28.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


#if os(iOS)
    import UIKit

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
    
    public static func execute(duration duration: NSTimeInterval, options:UpdateCurveOptions = .Linear, update:UpdateHandler, complete:CompleteHandler? = nil) -> IMPDisplayTimer {
        let timer = IMPDisplayTimer(duration: duration, options: options, update: update, complete: complete)
        timer.start()
        return timer
    }
    
    public func invalidate() {
        stop(false)
    }
    
    var options:UpdateCurveOptions = .Linear
    let updateHandler:UpdateHandler
    let completeHandler:CompleteHandler?
    let duration:NSTimeInterval
    var frameCounter  = 0
    var displayLink:CADisplayLink? = nil


    init(duration:NSTimeInterval, options:UpdateCurveOptions, update:UpdateHandler, complete:CompleteHandler?){
        self.duration = duration
        self.options = options
        updateHandler = update
        completeHandler = complete
    }
    
    func start() {
        if duration > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.frameCounter = 0
                
                self.displayLink  = CADisplayLink(target: self, selector: #selector(self.changeAnimation))
                self.displayLink!.frameInterval = 1
                
                self.displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode:NSRunLoopCommonModes)
            }
        }
    }
    
    func stop(flag:Bool) {
        self.displayLink?.invalidate()
        self.displayLink = nil
        if let c = self.completeHandler {
            dispatch_async(dispatch_get_main_queue()) {
                c(flag: flag)
            }
        }
    }
    
    static let easyInControlPoints    = [float2] (arrayLiteral: float2(0,0), float2(0.3, 0.1),  float2(1,1))
    static let easyOutControlPoints   = [float2] (arrayLiteral: float2(0,0), float2(0.7, 0.9),  float2(1,1))
    static let easyInOutControlPoints = [float2] (arrayLiteral: float2(0,0), float2(0.25, 0.05), float2(0.75, 0.95), float2(1,1))
    
    
    func newCurve() -> [Float] {
        var c = [Float]()
        
        guard self.duration > 0 else { return c }
        
        if let link = self.displayLink {
            
            let step  = Float(link.duration)/Float(self.duration)
            
            func range(step:Float) -> [Float]{
                var range = Array<Float>(Float(0).stride(through: 1, by: step))
                
                if range.last < 1 {
                    range.append(1)
                }
                return range
            }
            
            switch options {
            case .EaseIn:
                c = range(step).cubicSpline(IMPDisplayTimer.easyInControlPoints)
            case .EaseOut:
                c = range(step).cubicSpline(IMPDisplayTimer.easyOutControlPoints)
            case .EaseInOut:
                c = range(step).cubicSpline(IMPDisplayTimer.easyInOutControlPoints)
            case .Decelerate:
                c = Array<Float>(Float(1).stride(through: 0, by: -step).map({pow($0,2)}))
            default:
                c = range(step)
            }
        }

        return c
    }
    
    lazy var updateCurve:[Float] = {
        return self.newCurve()
    }()
    
    @objc func changeAnimation() {

        guard duration > 0    else {return}
        
        let curve = updateCurve ?? newCurve()
        
        guard !curve.isEmpty   else {return}
        
        dispatch_async(dispatch_get_main_queue()) {
            
            guard self.displayLink != nil else {return}
            
            if self.frameCounter >= curve.count {
                self.stop(true)
                return
            }
            
            self.updateHandler(atTime:  NSTimeInterval(curve[self.frameCounter]))
            
            self.frameCounter += 1
        }
    }
}
#endif
