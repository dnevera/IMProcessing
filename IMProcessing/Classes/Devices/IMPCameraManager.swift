//
//  IMPCameraManager.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 04.03.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    
    import UIKit
    import AVFoundation
    import CoreMedia
    import CoreMedia.CMBufferQueue
    
    
    public extension AVCaptureVideoOrientation {
                
//
//  AVCaptureVideoOrientation
//        case Portrait            // Indicates that video should be oriented vertically, home button on the bottom.
//        case PortraitUpsideDown  // Indicates that video should be oriented vertically, home button on the top.
//        case LandscapeRight      // Indicates that video should be oriented horizontally, home button on the right.
//        case LandscapeLeft       // Indicates that video should be oriented horizontally, home button on the left.
//
//  UIDeviceOrientation
//        case Unknown            -> Portrait
//        case Portrait           -> Portrait            // Device oriented vertically, home button on the bottom
//        case PortraitUpsideDown -> PortraitUpsideDown  // Device oriented vertically, home button on the top
//        case LandscapeLeft      -> LandscapeRight      // Device oriented horizontally, home button on the right !!!
//        case LandscapeRight     -> LandscapeLeft       // Device oriented horizontally, home button on the left !!!
//        case FaceUp             -> Portrait            // Device oriented flat, face up
//        case FaceDown           -> Portrait            // Device oriented flat, face down

        
        init?(deviceOrientation:UIDeviceOrientation) {
            switch deviceOrientation {
            case .PortraitUpsideDown:
                self.init(rawValue: AVCaptureVideoOrientation.PortraitUpsideDown.rawValue)
            case .LandscapeLeft:
                self.init(rawValue: AVCaptureVideoOrientation.LandscapeRight.rawValue)
            case .LandscapeRight:
                self.init(rawValue: AVCaptureVideoOrientation.LandscapeLeft.rawValue)
            default:
                self.init(rawValue: AVCaptureVideoOrientation.Portrait.rawValue)
            }
        }
    }
    
    public extension CMTime {
  
        /// Get exposure duration
        public var duration:(value:Int, scale:Int) {
            return (Int(self.value),Int(self.timescale))
        }
        
        /// Create new exposure duration
        public init(duration: (value:Int, scale:Int)){
            self = CMTimeMake(Int64(duration.value), Int32(duration.scale))
        }
    }
    
    /// Camera manager
    public class IMPCameraManager: NSObject, IMPContextProvider, AVCaptureVideoDataOutputSampleBufferDelegate {
        
        public typealias PointBlockType = ((camera:IMPCameraManager, point:CGPoint)->Void)
        
        ///  Focus settings
        ///
        ///  - Auto:           Auto focus mode at POI with beginning and completition blocks
        ///  - ContinuousAuto: Continuous Auto focus mode with beginning and completition blocks
        ///  - Locked:         Locked Focus mode
        ///  - Reset:          Reset foucus to center POI
        public enum Focus{
            
            case Auto          (atPoint:CGPoint, restriction:AVCaptureAutoFocusRangeRestriction?, begin:PointBlockType?, complete:PointBlockType?)
            case ContinuousAuto(atPoint:CGPoint, restriction:AVCaptureAutoFocusRangeRestriction?, begin:PointBlockType?, complete:PointBlockType?)
            case Locked(position:Float?, complete:PointBlockType?)
            case Reset(complete:PointBlockType?)

            /// Device focus mode
            public var mode: AVCaptureFocusMode {
                switch self {
                case .Auto(_,_,_,_): return .AutoFocus
                case .ContinuousAuto(_,_,_,_): return .ContinuousAutoFocus
                case .Locked(_,_): return .Locked
                case .Reset(_): return .ContinuousAutoFocus
                }
            }
            
            /// Focus range restriction
            public var restriction:AVCaptureAutoFocusRangeRestriction {
                if let r = self.realRestriction {
                    return r
                }
                else {
                    return .None
                }
            }

            var realRestriction:AVCaptureAutoFocusRangeRestriction? {
                switch self {
                case .Auto(_,let restriction,_,_): return restriction
                case .ContinuousAuto(_,let restriction,_,_): return restriction
                default:
                    return .None
                }
            }

            // Lens desired position
            var position:Float? {
                switch self {
                case .Locked(let position,_): return position
                default:
                    return nil
                }
            }
            
            // POI of focusing
            var poi: CGPoint? {
                switch self {
                case .Auto(let focusPoint,_,_,_): return focusPoint
                case .ContinuousAuto(let focusPoint,_,_,_): return focusPoint
                case .Locked(_,_): return nil
                case .Reset(_): return CGPoint(x: 0.5,y: 0.5)
                }
            }

            // Begining block calls when lens start to change its position
            var begin: PointBlockType? {
                switch self {
                case .Auto(_, _, let beginBlock, _): return beginBlock
                case .ContinuousAuto(_, _, let beginBlock, _): return beginBlock
                case .Locked(_,_): return nil
                case .Reset(_): return nil
                }
            }

            // Completetion block calls when focus has adjusted
            var complete: PointBlockType? {
                switch self {
                case .Auto(_,_,_, let completeBlock): return completeBlock
                case .ContinuousAuto(_,_,_, let completeBlock): return completeBlock
                case .Locked(_,let completeBlock): return completeBlock
                case .Reset(let completeBlock): return completeBlock
                }
            }
        }

        ///  Exposure settings
        ///
        ///  - Custom:         Custom exposure with duration
        ///  - Auto:           Auto exposure mode at POI with beginning and completition blocks
        ///  - ContinuousAuto: Continuous Auto exposure mode with beginning and completition blocks
        ///  - Locked:         Locked exposure mode
        ///  - Reset:          Reset exposure to center POI
        public enum Exposure {
            
            case Custom(duration:CMTime,iso:Float,begin:PointBlockType?,complete:PointBlockType?)
            case Auto(atPoint:CGPoint,begin:PointBlockType?,complete:PointBlockType?)
            case ContinuousAuto(atPoint:CGPoint,begin:PointBlockType?,complete:PointBlockType?)
            case Locked(complete:PointBlockType?)
            case Reset(complete:PointBlockType?)
            
            /// Device focus mode
            public var mode: AVCaptureExposureMode {
                switch self {
                case .Custom(_,_,_,_): return .Custom
                case .Auto(_,_,_): return .AutoExpose
                case .ContinuousAuto(_,_,_): return .ContinuousAutoExposure
                case .Locked(_): return .Locked
                case .Reset(_): return .ContinuousAutoExposure
                }
            }
            
            var duration: CMTime {
                switch self {
                case .Custom(let duration,_,_,_): return duration
                default: return AVCaptureExposureDurationCurrent
                }
            }
            
            var iso:Float{
                switch self {
                case .Custom(_,let iso,_,_): return iso
                default: return AVCaptureISOCurrent
                }
            }
            
            // POI of exposure
            var poi: CGPoint? {
                switch self {
                case .Custom(_,_,_,_): return nil
                case .Auto(let focusPoint,_,_): return focusPoint
                case .ContinuousAuto(let focusPoint,_,_): return focusPoint
                case .Locked(_): return nil
                case .Reset(_): return CGPoint(x: 0.5,y: 0.5)
                }
            }
            
            //
            var begin: PointBlockType? {
                switch self {
                case .Custom(_,_, let beginBlock, _): return beginBlock
                case .Auto(_, let beginBlock, _): return beginBlock
                case .ContinuousAuto(_, let beginBlock, _): return beginBlock
                case .Locked(_): return nil
                case .Reset(_): return nil
                }
            }
            
            // Completetion block calls when focus has adjusted
            var complete: PointBlockType? {
                switch self {
                case .Custom(_,_,_, let completeBlock): return completeBlock
                case .Auto(_,_, let completeBlock): return completeBlock
                case .ContinuousAuto(_,_, let completeBlock): return completeBlock
                case .Locked(let completeBlock): return completeBlock
                case .Reset(let completeBlock): return completeBlock
                }
            }
        }

        
        public typealias AccessHandler = ((Bool) -> Void)
        public typealias CameraCompleteBlockType    = ((camera:IMPCameraManager)->Void)
        public typealias LiveViewEventBlockType     = CameraCompleteBlockType
        public typealias CameraEventBlockType       = ((camera:IMPCameraManager, ready:Bool)->Void)
        public typealias VideoEventBlockType        = ((camera:IMPCameraManager, running:Bool)->Void)
        public typealias ZomingCompleteBlockType    = ((camera:IMPCameraManager, factor:Float)->Void)

        public typealias capturingCompleteBlockType = ((camera:IMPCameraManager, finished:Bool, file:String?, metadata:NSDictionary?, error:NSError?)->Void)
        
        //
        // Public API
        //
        
        ///  @brief Still image compression settings
        public struct Compression {
            public let isHardware:Bool
            public let quality:Float
            public init() {
                isHardware = true
                quality = 1
            }
            public init(isHardware:Bool, quality:Float){
                self.isHardware = isHardware
                self.quality = quality
            }
        }
        
        /// Test camera session state
        public var isReady:Bool {
            return session.running
        }
        
        /// Test camera video streaming state
        public var isRunning:Bool {
            return !isVideoPaused
        }
        
        
        /// Live view Metal device context
        public var context:IMPContext!
        
        /// Live video viewport
        public var liveView:IMPView {
            return _liveView
        }
        
        ///
        ///  Create Camera Manager instance
        ///
        ///  - parameter containerView: container view contains live view window
        ///
        public init(containerView:UIView, context:IMPContext? = nil) {
            
            super.init()
            
            defer{
                _currentCamera = backCamera
                
                var _context:IMPContext!
                
                if context == nil {
                    dispatch_sync(sessionQueue, { () -> Void in
                        self.context = IMPContext(lazy: true)
                    })
                }
                else {
                    self.context = context
                }
                
                liveView.frame = CGRect(x: 0, y: 0,
                                        width: containerView.bounds.size.width,
                                        height: containerView.bounds.size.height)
                containerView.addSubview(liveView)
                
                dispatch_sync(sessionQueue, { () -> Void in
                    self.initSession()
                })
            }
        }
        
        ///
        ///  Start camera manager capturing video frames
        ///
        ///  - parameter access: access handler
        ///
        public func start(access:AccessHandler?=nil) {
            requestAccess({ (granted) -> Void in
                if granted {
                    
                    //
                    // start...
                    //
                    
                    if !self.session.running {
                        self.isVideoStarted = false
                        dispatch_async(self.sessionQueue, { () -> Void in
                            self.isVideoPaused = false
                            self.session.startRunning()
                        })
                    }
                }
                if let a = access {
                    a(granted)
                }
            })
        }
        
        ///  Stop camera manager capturing video frames
        public func stop() {
            if session.running {
                dispatch_async(sessionQueue, { () -> Void in
                    self.session.stopRunning()
                    self.isVideoStarted = false
                })
            }
        }
        
        ///  Pause video frames capturing and present in liveView
        public func pause() {
            isVideoPaused = true
            self.videoObserversHandle()
        }
        
        ///  Resume paused presentation of video frames in liveView
        public func resume() {
            if !isReady{
                start()
            }
            else {
                isVideoPaused = false
            }
        }
        
        ///  Toggling between cameras
        ///
        ///  - parameter complete: complete operations after togglinig
        public func toggleCamera(complete:((camera:IMPCameraManager, toggled:Bool)->Void)?=nil) {
            dispatch_async(sessionQueue){
                let position = self.cameraPosition
                self.rotateCamera()                
                if let complete = complete {
                    complete(camera: self, toggled: position == self.cameraPosition)
                }
            }
        }
        
        /// Make compression of still images with hardware compression layer instead of turbojpeg lib
        public var compression = IMPCameraManager.Compression(isHardware: true, quality: 1){
            didSet{
                updateStillImageSettings()
            }
        }
        
        /// Get front camera capture device reference
        public let frontCamera = IMPCameraManager.camera(.Front)
        
        /// Get back camera caprure reference
        public let backCamera  = IMPCameraManager.camera(.Back)
        
        lazy var currentFocus:Focus = {
            switch self.currentCamera.focusMode {
            case .Locked:
                return .Locked(position: nil, complete: nil)
            case .AutoFocus:
                return .Auto(atPoint: CGPoint(x: 0.5,y: 0.5), restriction: nil, begin: nil,complete: nil)
            case .ContinuousAutoFocus:
                return .ContinuousAuto(atPoint: CGPoint(x: 0.5,y: 0.5), restriction: nil, begin: nil,complete: nil)
            }
        }()
        
        /// Get/Set current focus settings
        public var focus:Focus {
            set {
                currentFocus = newValue
                controlCameraFocus(atPoint: currentFocus.poi,
                                   action: { (poi) in
                                    
                                    if newValue.mode != .Locked {
                                        self.currentCamera.focusPointOfInterest = poi
                                    }
                                    
                                    if let position = newValue.position {
                                        if self.currentCamera.isFocusModeSupported(.Locked) {
                                            self.currentCamera.setFocusModeLockedWithLensPosition(position, completionHandler: { (time) in
                                                if let complete = self.currentFocus.complete {
                                                    complete(camera: self, point: self.focusPOI)
                                                }
                                            })
                                        }
                                    }
                                    else {
                                        if self.currentCamera.autoFocusRangeRestrictionSupported {
                                            if let r = self.currentFocus.realRestriction {
                                                self.currentCamera.autoFocusRangeRestriction = r
                                            }
                                        }
                                        self.currentCamera.focusMode = self.currentFocus.mode
                                    }
                                    
                    }, complete: nil)
            }
            get {
                return currentFocus
            }
        }
        
        /// Get the camera focus point of interest (POI)
        public var focusPOI:CGPoint {
            return currentCamera.focusPointOfInterest
        }

        
        lazy var currentExposure:Exposure = {
            switch self.currentCamera.exposureMode {
            case .Locked:
                return .Locked(complete: nil)
            case .AutoExpose:
                return .Auto(atPoint: CGPoint(x: 0.5,y: 0.5),begin: nil,complete: nil)
            case .ContinuousAutoExposure:
                return .ContinuousAuto(atPoint: CGPoint(x: 0.5,y: 0.5),begin: nil,complete: nil)
            default:
                return .Locked(complete: nil)
            }
        }()
        

        /// Get/Set current exposure settings
        public var exposure:Exposure {
            set {
                currentExposure = newValue
                controlCameraFocus(atPoint: currentExposure.poi,
                                   action: { (poi) in
                                    if newValue.mode == .Custom{
                                        
                                        if let begin = newValue.begin {
                                            begin(camera: self, point: self.exposurePOI)
                                        }
                                        
                                        var duration = newValue.duration
                                        
                                        if newValue.duration<self.exposureDurationRange.min{
                                            duration = self.exposureDurationRange.min
                                        }
                                        else if newValue.duration>self.exposureDurationRange.max{
                                            duration = self.exposureDurationRange.max
                                        }
                                        
                                        var iso = newValue.iso
                                        
                                        if iso < self.exposureISORange.min {
                                            iso = self.exposureISORange.min
                                        }
                                        else if iso > self.exposureISORange.max {
                                            iso = self.exposureISORange.max
                                        }
                                        
                                        self.currentCamera.setExposureModeCustomWithDuration(
                                                duration, ISO: iso, completionHandler: { (time) in
                                                if let complete = newValue.complete {
                                                    complete(camera: self, point: self.exposurePOI)
                                                }
                                        })
                                    }
                                    else{
                                        if newValue.mode != .Locked {
                                            self.currentCamera.exposurePointOfInterest = poi
                                        }
                                        
                                        self.currentCamera.exposureMode = self.currentExposure.mode
                                        
                                        if newValue.mode == .Locked {
                                            if let complete = newValue.complete {
                                                complete(camera: self, point: self.exposurePOI)
                                            }
                                        }

                                    }
                    }, complete: nil)
            }
            get {
                return currentExposure
            }
        }
        
        /// Get the camera exposure point of interest (POI)
        public var exposurePOI:CGPoint {
            return currentCamera.exposurePointOfInterest
        }

        /// Get the camera exposure duration range limit
        public lazy var exposureDurationRange:(min:CMTime,max:CMTime) = {
            return (self.currentCamera.activeFormat.minExposureDuration,self.currentCamera.activeFormat.maxExposureDuration)
        }()

        /// Get curent exposure duration
        public var exposureDuration:CMTime{
            return self.currentCamera.exposureDuration
        }

        /// Get the camera ISO range limit
        public lazy var exposureISORange:(min:Float,max:Float) = {
            return (self.currentCamera.activeFormat.minISO, self.currentCamera.activeFormat.maxISO)
        }()
        
        /// Get current ISO speed value
        public var exposureISO:Float{
            return self.currentCamera.ISO
        }
        
        /// Get current lens position
        public var lensPosition:Float {
            return self.currentCamera.lensPosition
        }
        
        /// Set focusing smooth mode
        public var smoothFocusEnabled:Bool {
            set {
                controlCamera(supported: currentCamera.smoothAutoFocusSupported, action: { (poi) in
                    self.currentCamera.smoothAutoFocusEnabled = newValue
                })
            }
            get {
                return currentCamera.smoothAutoFocusSupported && currentCamera.smoothAutoFocusEnabled
            }
        }
        
        /// Get exposure compensation range in f-stops
        public lazy var exposureCompensationRange:(min:Float,max:Float) = {
            return (self.currentCamera.minExposureTargetBias,self.currentCamera.maxExposureTargetBias)
        }()
        
        /// Set exposure compensation in f-stops
        public var exposureCompensation:Float {
            set{
                if self.currentCamera == nil {
                    return
                }
                dispatch_async(sessionQueue){
                    do {
                        try self.currentCamera.lockForConfiguration()
                        self.currentCamera.setExposureTargetBias(newValue, completionHandler:nil)
                        self.currentCamera.unlockForConfiguration()
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
            
            get {
                return currentCamera.exposureTargetBias
            }
        }
        
        ///  Add new observer calls when camera device change session state on ready to capture and vice versa.
        ///
        ///  - parameter observer: camera event block
        public func addCameraObserver(observer:CameraEventBlockType){
            cameraEventHandlers.append(observer)
        }
        
        ///  Add new observer calls when video capturing change video streanming state.
        ///
        ///  - parameter observer: camera event block
        public func addVideoObserver(observer:VideoEventBlockType){
            videoEventHandlers.append(observer)
        }
        
        ///  Add new observer calls when the first frame from video stream presents in live viewport after camera starting.
        ///
        ///  - parameter observer: camera event block
        public func addLiveViewReadyObserver(observer:LiveViewEventBlockType){
            liveViewReadyHandlers.append(observer)
        }
        
        /// Test camera torch
        public var hasTorch:Bool {
            return currentCamera.hasTorch
        }

        /// Change torch mode. It can be .Off, .On, .Auto
        public var torchMode:AVCaptureTorchMode {
            set{
                if hasFlash && newValue != currentCamera.torchMode &&
                    currentCamera.isTorchModeSupported(newValue)
                {
                    do{
                        try currentCamera.lockForConfiguration()
                        currentCamera.torchMode = newValue
                        currentCamera.unlockForConfiguration()
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
            get{
                return currentCamera.torchMode
            }
        }

        /// Test camera flash
        public var hasFlash:Bool {
            return currentCamera.hasFlash
        }
        
        /// Change flash mode. It can be .Off, .On, .Auto
        public var flashMode:AVCaptureFlashMode {
            set{
                if hasFlash && newValue != currentCamera.flashMode &&
                currentCamera.isFlashModeSupported(newValue)
                {
                    do{
                        try currentCamera.lockForConfiguration()
                        currentCamera.flashMode = newValue
                        currentCamera.unlockForConfiguration()
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
            get{
                return currentCamera.flashMode
            }
        }
        
        /// Get maximum video zoom factor presentation
        public lazy var maximumZoomFactor:Float = {
            return self.currentCamera.activeFormat.videoMaxZoomFactor.float
        }()
        
        
        ///  Set current zoom presentation of video
        ///
        ///  - parameter factor:   zoom factor
        ///  - parameter animate:  animate or not zomming proccess before presentation
        ///  - parameter complete: complete block
        public func setZoom(factor factor:Float, animate:Bool=true, complete:ZomingCompleteBlockType?=nil) {
            if factor >= 1.0 && factor <= maximumZoomFactor {
                dispatch_async(sessionQueue){
                    do{
                        try self.currentCamera.lockForConfiguration()
                        
                        self.zomingCompleteQueue.append(CompleteZomingFunction(complete: complete, factor: factor))
                        
                        if animate {
                            self.currentCamera.rampToVideoZoomFactor(factor.cgfloat, withRate: 30)
                        }
                        else{
                            self.currentCamera.videoZoomFactor = factor.cgfloat
                        }
                        self.currentCamera.unlockForConfiguration()
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
        }
        
        /// Cancel zooming
        public func cancelZoom(){
            dispatch_async(sessionQueue){
                do{
                    try self.currentCamera.lockForConfiguration()
                    self.currentCamera.cancelVideoZoomRamp()
                    self.currentCamera.unlockForConfiguration()
                }
                catch let error as NSError {
                    NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                }
            }
        }
        
        deinit{
            removeCameraObservers()
        }
        
        public var frameRate:Int {
            get {
                return currentFrameRate
            }
            set {
                resetFrameRate(newValue)
            }
        }
        
        var  currentFrameRate:Int = 30
        
        func resetFrameRate(frameRate:Int){
            
            currentFrameRate = frameRate
            
            let activeCaptureFormat = self.currentCamera.activeFormat
            
            for rate in activeCaptureFormat.videoSupportedFrameRateRanges as! [AVFrameRateRange] {
                if( frameRate >= rate.minFrameRate.int && frameRate <= rate.maxFrameRate.int ) {
                    do{
                        try currentCamera.lockForConfiguration()
                        
                        currentCamera.activeVideoMinFrameDuration = CMTimeMake(1, Int32(frameRate))
                        currentCamera.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(frameRate))
                        
                        currentCamera.unlockForConfiguration()
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
        }

        
        //
        // Internal utils and vars
        //
        
        // Get current camera
        var currentCamera:AVCaptureDevice!{
            return _currentCamera
        }

        var _currentCamera:AVCaptureDevice! {
            willSet{
                if (_currentCamera != nil) {
                    removeCameraObservers()
                }
            }
            didSet{
                addCameraObservers()
                resetFrameRate(currentFrameRate)
            }
        }

        // Live view
        private lazy var _liveView:IMPView = {
            let view  = IMPView(context: self.context)
            view.isPaused = true
            view.backgroundColor = IMPColor.clearColor()
            view.autoresizingMask = [.FlexibleLeftMargin,.FlexibleRightMargin,.FlexibleTopMargin,.FlexibleBottomMargin]
            view.filter = IMPFilter(context: self.context)
            view.ignoreDeviceOrientation = true
            view.animationDuration = 0
            view.viewReadyHandler = {
                self.liveViewReadyObserversHandle()
            }
            
            return view
        }()
        
        
        var isVideoStarted   = false
        var isVideoPaused    = true {
            didSet {
                isVideoSuspended = oldValue
            }
        }
        var isVideoSuspended      = false
        
        var cameraEventHandlers = [CameraEventBlockType]()
        var videoEventHandlers  = [VideoEventBlockType]()
        var liveViewReadyHandlers = [LiveViewEventBlockType]()
        
        func cameraObserversHandle() {
            for o in cameraEventHandlers {
                o(camera: self, ready: isReady)
            }
        }
        
        func videoObserversHandle() {
            for o in videoEventHandlers {
                o(camera: self, running: isRunning)
            }
        }
        
        func liveViewReadyObserversHandle() {
            for o in liveViewReadyHandlers{
                o(camera: self)
            }
        }
        
        //  Check access to camera
        //
        //  - parameter complete: complete hanlder
        //
        func requestAccess(complete:AccessHandler) {
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: {
                (granted: Bool) -> Void in
                complete(granted)
            });
        }
        
        func controlCameraFocus(atPoint point:CGPoint?, action:((poi:CGPoint)->Void), complete:CameraCompleteBlockType?=nil) {
            controlCamera(atPoint: point,
                          supported: self.currentCamera.focusPointOfInterestSupported
                            && self.currentCamera.isFocusModeSupported(.AutoFocus),
                          action: action,
                          complete: complete)
        }

        func controlCameraExposure(atPoint point:CGPoint?, action:((poi:CGPoint)->Void), complete:CameraCompleteBlockType?=nil) {
            controlCamera(atPoint: point,
                          supported: self.currentCamera.exposurePointOfInterestSupported
                            && self.currentCamera.isExposureModeSupported(.AutoExpose),
                          action: action,
                          complete: complete)
        }

        func controlCamera(atPoint point:CGPoint?=nil, supported: Bool, action:((poi:CGPoint)->Void), complete:CameraCompleteBlockType?=nil) {
            if self.currentCamera == nil {
                return
            }
            
            if supported
            {
                dispatch_async(sessionQueue){
                    
                    let poi = point == nil ? CGPoint(x:0.5,y: 0.5) : self.pointOfInterestForLocation(point!)
                    
                    do {
                        try self.currentCamera.lockForConfiguration()
                        
                        action(poi: poi)
                        
                        self.currentCamera.unlockForConfiguration()
                        
                        if let complete = complete {
                            complete(camera:self)
                        }
                    }
                    catch let error as NSError {
                        NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                    }
                }
            }
        }

        
        //
        // Observe camera properties...
        //
        
        class CompleteZomingFunction {
            var block:ZomingCompleteBlockType? = nil
            var factor:Float = 0
            init(complete:ZomingCompleteBlockType?, factor:Float){
                self.block = complete
                self.factor = factor
            }
        }
        
        var zomingCompleteQueue = [CompleteZomingFunction]()

        func addCameraObservers() {
            currentCamera.addObserver(self, forKeyPath: "videoZoomFactor", options: .New, context: nil)
            currentCamera.addObserver(self, forKeyPath: "adjustingFocus", options: .New, context: nil)
            currentCamera.addObserver(self, forKeyPath: "adjustingExposure", options: .New, context: nil)
        }
        
        func removeCameraObservers() {
            currentCamera.removeObserver(self, forKeyPath: "videoZoomFactor", context: nil)
            currentCamera.removeObserver(self, forKeyPath: "adjustingFocus", context: nil)
            currentCamera.removeObserver(self, forKeyPath: "adjustingExposure", context: nil)
        }

        override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
            
            if keyPath == "adjustingFocus"{
                if let new = change?["new"] as? Int {
                    if new == 1 {
                        if let begin = currentFocus.begin{
                            begin(camera: self, point: self.focusPOI)
                        }
                    }
                    else if new == 0 {
                        if currentFocus.position == nil {
                            //
                            // .Locked at lens position is ignored
                            //
                            if let complete = currentFocus.complete{
                                complete(camera: self, point: self.focusPOI)
                                switch currentFocus {
                                case .Reset(_): currentFocus = .Reset(complete: nil)
                                default: break
                                }
                            }
                        }
                    }
                }
            }
                
            else if keyPath == "adjustingExposure"{
                
                if currentExposure.mode == .Custom {
                    return
                }
                
                if let new = change?["new"] as? Int {
                    if new == 1 {
                        if let begin = currentExposure.begin{
                            begin(camera: self, point: self.exposurePOI)
                        }
                    }
                    else if new == 0 {
                        if let complete = currentExposure.complete{
                            complete(camera: self, point: self.exposurePOI)
                            switch currentExposure {
                            case .Reset(_): currentExposure = .Reset(complete: nil)
                            default: break
                            }
                        }
                    }
                }
            }
                
            else if keyPath == "videoZoomFactor" {
                if let new = change?["new"] as? Float {
                    if let complete = zomingCompleteQueue.last {
                        if let block = complete.block {
                            if complete.factor == new {
                                zomingCompleteQueue.removeAll()
                                block(camera: self, factor: complete.factor)
                            }
                        }
                    }
                }
            }
        }
        
        func updateStillImageSettings() {
            if compression.isHardware {
                stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG, AVVideoQualityKey: compression.quality]
            }
            else {
                stillImageOutput.outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
            }
        }
        
        func runningNotification(event:NSNotification) {
            for  o in cameraEventHandlers {
                o(camera: self, ready:isReady)
            }
        }
        
        var sessionQueue = dispatch_queue_create(IMProcessing.names.prefix+"preview.video", DISPATCH_QUEUE_SERIAL)
        
        func updateConnection()  {
            //
            // Current capture connection
            //
            currentConnection = liveViewOutput.connectionWithMediaType(AVMediaTypeVideo)
            
            currentConnection.automaticallyAdjustsVideoMirroring = false
            
            if (currentConnection.supportsVideoOrientation){
                currentConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
            }
            
            if (currentConnection.supportsVideoMirroring) {
                currentConnection.videoMirrored = currentCamera == frontCamera
            }
            
        }
        
        func initSession() {
            if session == nil {
                
                do {
                    session = AVCaptureSession()
                    
                    if let s = session{
                        s.beginConfiguration()
                        
                        s.sessionPreset = AVCaptureSessionPresetPhoto
                        
                        //
                        // Input
                        //
                        videoInput = try videoInput ?? AVCaptureDeviceInput(device: currentCamera)
                        
                        if s.canAddInput(videoInput) {
                            s.addInput(videoInput)
                        }
                        
                        //
                        // Video Output
                        //
                        liveViewOutput = AVCaptureVideoDataOutput()
                        liveViewOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                        liveViewOutput.alwaysDiscardsLateVideoFrames = true
                        liveViewOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
                        
                        if s.canAddOutput(liveViewOutput) {
                            s.addOutput(liveViewOutput)
                        }
                        
                        //
                        // Full size Image
                        //
                        stillImageOutput = AVCaptureStillImageOutput()
                        
                        if s.canAddOutput(stillImageOutput) {
                            s.addOutput(stillImageOutput)
                        }
                        
                        s.canSetSessionPreset(AVCaptureSessionPresetPhoto)
                        
                        s.commitConfiguration()

                        updateStillImageSettings()
                        
                        updateConnection()
                        
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name: AVCaptureSessionDidStartRunningNotification, object: session)
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name:
                            AVCaptureSessionDidStopRunningNotification, object: session)
                    }
                }
                catch let error as NSError {
                    NSLog("IMPCameraManager error: \(error) \(#file):\(#line)")
                }
            }
        }
        
        lazy var hasFrontCamera:Bool = {
            let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
            for d in devices{
                if d.position == .Front {
                    return true
                }
            }
            return false
        }()
        
        func rotateCamera() {
            do {
                if !hasFrontCamera {
                    return;
                }
                
                session.beginConfiguration()
                
                session.removeInput(videoInput)
                
                if (self.currentCamera == self.backCamera) {
                    _currentCamera = self.frontCamera;
                }
                else{
                    _currentCamera = self.backCamera;
                }
                
                videoInput = try AVCaptureDeviceInput(device: currentCamera)
                
                if session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                }
                
                session.commitConfiguration()
                
                updateConnection()
                
            }
            catch let error as NSError {
                NSLog("IMPCameraManager error: \(error) \(#file):\(#line)")
            }
        }
        
        var capturingPhotoInProgress = false
        var session:AVCaptureSession!
        var videoInput:AVCaptureDeviceInput!
        
        lazy var cameraPosition:AVCaptureDevicePosition = {
            return self.videoInput.device.position
        }()
        
        var liveViewOutput:AVCaptureVideoDataOutput!
        var stillImageOutput:AVCaptureStillImageOutput!
        var currentConnection:AVCaptureConnection!
        
        static func camera(position:AVCaptureDevicePosition) -> AVCaptureDevice? {
            guard let device = AVCaptureDevice.devices().filter({ $0.position == position })
                .first as? AVCaptureDevice else {
                    return nil
            }
            do {
                try device.lockForConfiguration()
                if device.isWhiteBalanceModeSupported(.ContinuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .ContinuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
            }
            catch  {
                return nil
            }
            
            return device
        }
        
        func pointOfInterestForLocation(location:CGPoint) -> CGPoint {
            
            let  frameSize = self.liveView.bounds.size
            var  newLocaltion = location
            
            if self.cameraPosition == .Front {
                newLocaltion.x = frameSize.width - location.x
            }
            
            return CGPointMake(newLocaltion.y / frameSize.height, 1 - (newLocaltion.x / frameSize.width));
        }

        static func connection(mediaType:String, connections:NSArray) -> AVCaptureConnection? {
            
            var videoConnection:AVCaptureConnection? = nil
            
            for connection in connections  {
                for port in connection.inputPorts {
                    if  port.mediaType.isEqual(mediaType) {
                        videoConnection = connection as? AVCaptureConnection
                        break;
                    }
                }
                if videoConnection != nil {
                    break;
                }
            }
            
            return videoConnection;
        }
        
        var imageProvider:IMPImageProvider?
        
        lazy var previewBufferQueue:CMBufferQueue? = {
            var queue : CMBufferQueue?
            var err : OSStatus = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &queue)
            if err != 0 || queue == nil
            {
                //let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
                return nil
            }
            else
            {
                return queue
            }
        }()
    }
    
    // MARK: - Capturing API
    public extension IMPCameraManager {
        //
        // Capturing video frames and update live-view to apply IMP-filter.
        //
        public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {            
            
            if capturingPhotoInProgress {
                return
            }
            
            if isVideoPaused {
                return
            }
                        
            if connection == currentConnection {
                
                if !isVideoStarted || isVideoSuspended{
                    isVideoStarted = true
                    isVideoSuspended = false
                    videoObserversHandle()
                }
                
                if let previewBuffer = previewBufferQueue {
                    
                    // This is a shallow queue, so if image
                    // processing is taking too long, we'll drop this frame for preview (this
                    // keeps preview latency low).
                    
                    let err = CMBufferQueueEnqueue(previewBuffer, sampleBuffer)
                    
                    if err == 0 {
                        dispatch_async(dispatch_get_main_queue(), {
                            if let  sbuf = CMBufferQueueGetHead(previewBuffer) {
                                if let pixelBuffer = CMSampleBufferGetImageBuffer(sbuf as! CMSampleBuffer) {
                                    self.updateProvider(pixelBuffer)
                                }
                            }
                            CMBufferQueueReset(self.previewBufferQueue!)
                        })
                    }
                    
                }
                else if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    updateProvider(pixelBuffer)
                }
            }
        }
        
        func updateProvider(pixelBuffer: CVImageBuffer)  {
            if imageProvider == nil {
                imageProvider = IMPImageProvider(context: liveView.context, pixelBuffer: pixelBuffer)
            }
            else {
                imageProvider?.update(pixelBuffer: pixelBuffer)
            }
            liveView.filter?.source = imageProvider
        }
        
        ///  Capture image to file
        ///
        ///  - parameter file:     file path. Path can be nil, in this case photo captures to Camera Roll
        ///  - parameter complete: completition block
        public func capturePhoto(file file:String?=nil, complete:capturingCompleteBlockType?=nil){
            
            if !isReady{
                complete?(camera: self, finished: false, file: file, metadata: nil, error: nil)
                return
            }
            if stillImageOutput.capturingStillImage {
                complete?(camera: self, finished: false, file: file, metadata: nil, error: nil)
                return
            }
            
            let deviceOrientation = UIDevice.currentDevice().orientation
            var isConnectionSupportsOrientation = false

            if let complete = complete {
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    
                    if let connection = IMPCameraManager.connection(AVMediaTypeVideo, connections: self.stillImageOutput.connections) {
                        
                        connection.automaticallyAdjustsVideoMirroring = false
                        
                        if (connection.supportsVideoOrientation){
                            connection.videoOrientation =  AVCaptureVideoOrientation(deviceOrientation: deviceOrientation)!
                            isConnectionSupportsOrientation = true
                        }
                        
                        self.capturingPhotoInProgress = true
                        
                        self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (sampleBuffer, error) in
                            
                            if error != nil {
                                self.capturingPhotoInProgress = false
                                complete(camera: self, finished: false, file: file, metadata: nil, error: error)
                            }
                            else{
                                
                                if let sampleBuffer = sampleBuffer {
                                    
                                    let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
                                    
                                    var meta = attachments as NSDictionary?
                                    
                                    if let d = meta {
                                        
                                        let newMeta = d.mutableCopy() as! NSMutableDictionary
                                        
                                        newMeta[IMProcessing.meta.versionKey]           = IMProcessing.meta.version
                                        newMeta[IMProcessing.meta.deviceOrientationKey] = deviceOrientation.rawValue
                                        if isConnectionSupportsOrientation {
                                            //newMeta[IMProcessing.meta.imageOrientationKey]  = 1
                                        }
                                        
                                        newMeta[IMProcessing.meta.imageSourceExposureMode] = self.currentCamera.exposureMode.rawValue
                                        newMeta[IMProcessing.meta.imageSourceFocusMode] = self.currentCamera.focusMode.rawValue
                                        
                                        meta = newMeta
                                    }
                                    
                                    do {
                                        if self.compression.isHardware {
                                            let imageDataJpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                                            if let file = file {
                                                try imageDataJpeg.writeToFile(file, options: .AtomicWrite)
                                                complete(camera: self, finished: true, file: file, metadata: meta, error: nil)
                                            }
                                            else {
                                                if let image = UIImage(data: imageDataJpeg) {
                                                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                                    complete(camera: self, finished: true, file: file, metadata: meta, error: nil)
                                                }
                                            }
                                        }
                                        else{
                                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                                if let file = file {
                                                    try IMPJpegturbo.writePixelBuffer(pixelBuffer, toJpegFile: file, compression: self.compression.quality.cgfloat, inputColorSpace:JPEG_TURBO_BGRA)
                                                    complete(camera: self, finished: true, file: file, metadata: meta, error: nil)
                                                }
                                                else {
                                                    complete(camera: self, finished: true, file: nil, metadata: meta, error: nil)
                                                }
                                            }
                                            else {
                                                let error = NSError(domain: IMProcessing.names.prefix+"camera.roll",
                                                    code: 0,
                                                    userInfo: [
                                                        NSLocalizedDescriptionKey: String(format: NSLocalizedString("Hardware saving to camer roll is only supported", comment:"")),
                                                        NSLocalizedFailureReasonErrorKey: String(format: NSLocalizedString("Saving to Camera Roll error", comment:""))
                                                    ])
                                                complete(camera: self, finished: false, file: file, metadata: meta, error: error)
                                            }
                                        }
                                    }
                                    catch let error as NSError{
                                        complete(camera: self, finished: false, file: file, metadata: meta, error: error)
                                    }
                                }
                                self.capturingPhotoInProgress = false
                            }
                        })
                    }
                }
            }
        }
    }
    
#endif