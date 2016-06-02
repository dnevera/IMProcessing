//: [Previous](@previous)

import Foundation
import Darwin

extension mach_timebase_info{
    static var sharedInstance = mach_timebase_info(0)
    private init(_:Int) {
        self.init()
        mach_timebase_info(&self)
    }
}

extension UInt64 {
    var nanos:UInt64 {
        return  UInt64( (UInt32(self) * mach_timebase_info.sharedInstance.numer) / mach_timebase_info.sharedInstance.denom)
    }
    
    var abs:UInt64 {
        return  UInt64( (UInt32(self) * mach_timebase_info.sharedInstance.denom) / mach_timebase_info.sharedInstance.numer)
    }
}

public class IMPRTTimer {
    
    public typealias UpdateHandler = ((timestamp:UInt64, duration:UInt64)->Void)
    
    public static let nanos_per_usec:UInt64 = 1000
    public static let nanos_per_msec:UInt64 = 1000 * IMPRTTimer.nanos_per_usec
    public static let nanos_per_sec:UInt64  = 1000 * IMPRTTimer.nanos_per_msec
    
    public static let usec_per_msec:UInt64  = 1000
    public static let usec_per_sec:UInt64   = 1000 * IMPRTTimer.usec_per_msec
    
    public static let msec_per_sec:UInt64   = 1000
    
    public let duration:UInt64 // usec
    public let quality:NSQualityOfService
    
    public var isRunning:Bool {
        return condition
    }
    
    public init(usec: UInt64, quality:NSQualityOfService = .Default, update:UpdateHandler) {
        duration = usec
        self.quality = quality
        self.handler = update
    }
    
    public convenience init(msec: UInt64, quality:NSQualityOfService = .UserInteractive, handler:UpdateHandler) {
        self.init(usec: msec * IMPRTTimer.usec_per_msec, quality: quality, update: handler)
    }
    
    public convenience init(sec: UInt64, quality:NSQualityOfService = .UserInteractive, handler:UpdateHandler) {
        self.init(usec: sec * IMPRTTimer.usec_per_sec, quality: quality, update: handler)
    }
    
    public var now:UInt64 {
        return mach_absolute_time()
    }
    
    var lastUpdate:UInt64 = 0
    public func start()  {
        timer_queue.addOperationWithBlock {
            self.condition = true
            let startTime = self.now
            while self.condition {
                let t = self.now
                let lu = self.lastUpdate
                self.lastUpdate = t
                dispatch_async(self.handler_queue) {
                    self.handler(timestamp: t-startTime, duration: t-(lu == 0 ? t : lu) )
                }
                self.wait_until(usec: self.duration)
            }
        }
    }
    
    public func stop(){
        condition = false
        timer_queue.suspended = true
        timer_queue.cancelAllOperations()
        timer_queue.suspended = false
    }
    
    var handler:UpdateHandler
    
    var condition     = true
    let handler_queue = dispatch_queue_create( "rttimer.handler", DISPATCH_QUEUE_SERIAL)
    lazy var timer_queue:NSOperationQueue   =  {
        let t = NSOperationQueue()
        t.name = "rttimer.queue"
        t.qualityOfService = self.quality
        return t
    }()
    
    deinit{
        stop()
    }
    
    func wait_until(nsec nsec:UInt64){
        mach_wait_until(now + UInt64(nsec).abs)
    }
    
    func wait_until(usec usec: UInt64) {
        wait_until(nsec: usec*IMPRTTimer.nanos_per_usec)
    }
}




let tm = IMPRTTimer(msec: 1) { (timestamp,duration) in
    print("\(timestamp,duration)")
}
//tm.start()
//sleep(1)
//tm.stop()
//
//print("stoped")
//sleep(1)
//print("start")
//tm.start()
//sleep(1)
//tm.stop()
//
//


extension _ArrayType where Generator.Element == Float {
    var total: Float {
        guard !isEmpty else { return 0 }
        return  reduce(0, combine: +)
    }
    var average: Float {
        guard !isEmpty else { return 0 }
        return  total / Float(count)
    }
}

extension _ArrayType where Generator.Element == float2 {
    var total: float2 {
        guard !isEmpty else { return float2(0) }
        return reduce(float2(0), combine: +)
    }
    var average: float2 {
        guard !isEmpty else { return float2(0) }
        return  total /// Float(count)
    }
}

public class IMPPanningBehavior{
    
    public struct Deceleration {
        public let duration:Float
        public let distance:float2
        init(initial velocity:float2, offset:float2, spring:Float, resistance:Float){
            
            let norm:Float = 10000
            let v = velocity
            let velocity_mod = simd.distance(v, float2(0))
            
            let velocityAngle  = abs(atan(velocity.y/velocity.x))
            let velocityVector = float2(sin(velocityAngle) * sign(velocity.x),cos(velocityAngle) * sign(velocity.y))
            let x              = simd.distance(offset, float2(0)) * velocityVector
            let force          = (spring * x + resistance * velocityVector) * norm
            let force_mod      = simd.distance(force, float2(0))
            
            guard force_mod > 0 else {
                duration = 0
                distance = float2(0)
                return
            }
            
            duration = velocity_mod/force_mod
            
            let d = (powf(velocity_mod, 2) * float2(1,1))/force/norm
            distance =  d//clamp(d, min: float2(-1), max: float2(1))
        }
    }
    
    public init(precision:Int = 10) {
        self.precision = precision
    }
    
    public var offset = float2(0)
    public let precision:Int
    
    public var deceleration:Deceleration {
        return Deceleration(initial: velocity, offset: offset, spring: springFactor, resistance: resistanceFacor)
    }
    
    public var velocity:float2 {
        set {
            if enabled {
                isUpdating = true
                velocityQueue.append(newValue)
                isUpdating = false
            }
        }
        get{
            if velocityQueue.isEmpty { return lastVelocity }
            return velocityQueue.suffix(self.precision).average
        }
    }
    
    public var resistanceFacor:Float = 50
    public var springFactor:Float = 10
    
    
    public var enabled:Bool = false {
        didSet {
            if enabled {
                lastUpdate = NSDate.timeIntervalSinceReferenceDate()
                //timer.start()
            }
            else {
                //timer.stop()
                self.lastVelocity = self.velocityQueue.suffix(self.precision).average
                self.velocityQueue.removeAll()
                print(" deceleration = \(deceleration) ")
            }
        }
    }
    
    var lastUpdate   = NSTimeInterval(0)
    var lastPosition = float2(0)
    var lastVelocity = float2(0)
    var velocityQueue = [float2]()
    var isUpdating    = false
    
    lazy var timer:IMPRTTimer = IMPRTTimer(usec: 100, update: { (timestamp, duration) in
        dispatch_async(dispatch_get_main_queue(), {
            if self.isUpdating { return }
            self.velocityQueue.append(float2(0))
        })
    }){ (timestamp, duration) in
        //self.lastVelocity = self.velocityQueue.suffix(self.precision).average
        //self.velocityQueue.removeAll()
    }
}

