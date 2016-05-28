//
//  IMPDisplayTimer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 28.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import SnapKit
import ImageIO


#if os(iOS)
public class IMPDisplayTimer {
    
    public enum UpdateCurveOptions{
        case Linear
        case EaseIn
        case EaseOut
        case EaseInOut
    }
    
    public typealias UpdateHandler   = ((atTime:NSTimeInterval)->Void)
    public typealias CompleteHandler = ((flag:Bool)->Void)
    
    public static func execute(duration duration: NSTimeInterval, options:UpdateCurveOptions = .Linear, update:UpdateHandler, complete:CompleteHandler? = nil){
        let timer = IMPDisplayTimer(duration: duration, options: options, update: update, complete: complete)
        timer.start()
    }
    
    
    var options:UpdateCurveOptions = .Linear
    let updateHandler:UpdateHandler
    let completeHandler:CompleteHandler?
    let duration:NSTimeInterval
    
    init(duration:NSTimeInterval, options:UpdateCurveOptions, update:UpdateHandler, complete:CompleteHandler?){
        self.duration = duration
        self.options = options
        updateHandler = update
        completeHandler = complete
    }
    
    var frameCounter  = 0
    
    var frameInterval:Int {
        set{
            if newValue < 1 {
                displayLink?.frameInterval = 1
            }
            else if newValue > 4 {
                displayLink?.frameInterval = 4
            }
            else {
                displayLink?.frameInterval = newValue
            }
        }
        get{
            guard let d = displayLink else { return 0 }
            return d.frameInterval
        }
    }
    
    func start() {
        if duration > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.frameCounter = 0
                self.displayLink  = CADisplayLink(target: self, selector: #selector(self.changeAnimation))
                self.displayLink?.addToRunLoop(NSRunLoop.currentRunLoop(), forMode:NSRunLoopCommonModes)
                self.frameInterval = 1
            }
        }
    }
    
    func stop() {
        dispatch_async(dispatch_get_main_queue()) {
            self.displayLink?.invalidate()
            if let c = self.completeHandler {
                c(flag: true)
            }
        }
    }
    
    static var easyInControlPoints    = [float2] (arrayLiteral: float2(0,0), float2(0.4, 0.07), float2(1,1))
    static var easyOutControlPoints   = [float2] (arrayLiteral: float2(0,0), float2(0.6, 0.93), float2(1,1))
    static var easyInOutControlPoints = [float2] (arrayLiteral: float2(0,0), float2(0.25, 0.05), float2(0.75, 0.95), float2(1,1))
    
    var displayLink:CADisplayLink? = nil
    
    func newCurve() -> [Float] {
        var c = [Float]()
        
        guard self.duration > 0 else { return c }
        
        if let link = self.displayLink {
            let step  = Float(link.duration)/Float(self.duration)
            var range = Array<Float>(Float(0).stride(through: 1, by: step))
            
            if range.last < 1 {
                range.append(1)
            }
            
            switch options {
            case .EaseIn:
                c = range.cubicSpline(IMPDisplayTimer.easyInControlPoints)
            case .EaseOut:
                c = range.cubicSpline(IMPDisplayTimer.easyOutControlPoints)
            case .EaseInOut:
                c = range.cubicSpline(IMPDisplayTimer.easyInOutControlPoints)
            default:
                c = range
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
                self.stop()
                return
            }
            
            self.updateHandler(atTime:  NSTimeInterval(curve[self.frameCounter]))
            
            self.frameCounter += 1
        }
    }
}
#endif
