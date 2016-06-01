//
//  IMPRTTimer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 01.06.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

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
    
    public init(usec: UInt64, quality:NSQualityOfService = .Background, update:UpdateHandler, complete:UpdateHandler?=nil) {
        duration = usec
        self.quality = quality
        self.update = update
        self.complete = complete
    }
    
    public convenience init(msec: UInt64, quality:NSQualityOfService = .Background, update:UpdateHandler, complete:UpdateHandler?=nil) {
        self.init(usec: msec * IMPRTTimer.usec_per_msec, quality: quality, update: update, complete: complete)
    }
    
    public convenience init(sec: UInt64, quality:NSQualityOfService = .Background, update:UpdateHandler, complete:UpdateHandler?=nil) {
        self.init(usec: sec * IMPRTTimer.usec_per_sec, quality: quality, update: update, complete: complete)
    }
    
    public var now:UInt64 {
        return mach_absolute_time()
    }
    
    var lastUpdate:UInt64 = 0
    var startTime:UInt64 = 0
    public func start()  {
        
        if self.condition {
            return
        }
        
        lastUpdate = 0
        timer_queue.addOperationWithBlock {
            self.condition = true
            self.startTime = self.now
            while self.condition {
                let t = self.now
                let lu = self.lastUpdate
                self.lastUpdate = t
                dispatch_async(self.handler_queue) {
                    self.update(timestamp: t-self.startTime, duration: t-(lu == 0 ? t : lu) )
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
        if let c = self.complete {
            let t = self.now
            let lu = self.lastUpdate
            self.lastUpdate = t
            dispatch_async(self.handler_queue) {
               c(timestamp: t-self.startTime, duration: t-(lu == 0 ? t : lu) )
            }
        }
    }

    var update:UpdateHandler
    var complete:UpdateHandler?
    
    var condition     = true
    let handler_queue = dispatch_queue_create(IMProcessing.names.prefix + "rttimer.handler", DISPATCH_QUEUE_SERIAL)
    lazy var timer_queue:NSOperationQueue   =  {
        let t = NSOperationQueue()
        t.name = IMProcessing.names.prefix + "rttimer.queue"
        t.qualityOfService = self.quality
        return t
    }()
    
    deinit{
        stop()
    }
    
    lazy var info:mach_timebase_info = {
        var i = mach_timebase_info()
        mach_timebase_info(&i)
        return i
    }()

    func wait_until(nsec nsec:UInt64){
        mach_wait_until(now + UInt64(nsec).abs)
    }
    
    func wait_until(usec usec: UInt64) {
        wait_until(nsec: usec*IMPRTTimer.nanos_per_usec)
    }
}
