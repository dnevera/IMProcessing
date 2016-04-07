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
    
    
    /// Camera manager
    public class IMPCameraManager: NSObject,IMPContextProvider,AVCaptureVideoDataOutputSampleBufferDelegate {
        
        public typealias AccessHandler = ((Bool) -> Void)
        public typealias liveViewEventBlockType = ((camera:IMPCameraManager)->Void)
        public typealias cameraEventBlockType   = ((camera:IMPCameraManager, ready:Bool)->Void)
        public typealias videoEventBlockType    = ((camera:IMPCameraManager, running:Bool)->Void)
        
        //
        // Public API
        //
        
        ///  @brief Still image compression settings
        public struct Compression {
            let isHardware:Bool
            let quality:Float
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
                
                liveView.frame = containerView.frame
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
        
        ///  Stop camera manager captuirin video frames
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
        
        public func toggleCamera() -> Bool {
            let position = cameraPosition
            rotateCamera()
            return position == cameraPosition
        }
        
        /// Make compression of still images with hardware compression layer instead of turbojpeg lib
        public var compression = IMPCameraManager.Compression(isHardware: false, quality: 1){
            didSet{
                updateStillImageSettings()
            }
        }
        
        /// Get front camera capture device reference
        public var frontCamera = IMPCameraManager.camera(.Front)
        
        /// Get back camera caprure reference
        public var backCamera  = IMPCameraManager.camera(.Back)
        
        /// Get current camera
        public var currentCamera:AVCaptureDevice!{
            return _currentCamera
        }
        
        //
        // Capturing video frames and update live-view to apply IMP-filter.
        //
        public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
            
            if isVideoPaused {
                return
            }
            
            if connection == currentConnection {
                
                if !isVideoStarted || isVideoSuspended{
                    isVideoStarted = true
                    isVideoSuspended = false
                    videoObserversHandle()
                }
                
                
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    if liveView.filter?.source == nil {
                        liveView.filter?.source = IMPImageProvider(context: liveView.context, pixelBuffer: pixelBuffer)
                    }
                    else {
                        liveView.filter?.source?.update(pixelBuffer: pixelBuffer)
                    }
                }
            }
        }
        
        ///  Add new observer calls when camera device change session state on ready to capture and vice versa.
        ///
        ///  - parameter observer: camera event block
        public func addCameraObserver(observer:cameraEventBlockType){
            cameraEventHandlers.append(observer)
        }
        
        ///  Add new observer calls when video capturing change video streanming state.
        ///
        ///  - parameter observer: camera event block
        public func addVideoObserver(observer:videoEventBlockType){
            videoEventHandlers.append(observer)
        }
        
        ///  Add new observer calls when the first frame from video stream presents in live viewport after camera starting.
        ///
        ///  - parameter observer: camera event block
        public func addLiveViewReadyObserver(observer:liveViewEventBlockType){
            liveViewReadyHandlers.append(observer)
        }
        
        //
        // Internal utils and vars
        //
        
        /// Live view
        private lazy var _liveView:IMPView = {
            let view  = IMPView(context: self.context)
            view.backgroundColor = IMPColor.clearColor()
            view.autoresizingMask = [.FlexibleLeftMargin,.FlexibleRightMargin,.FlexibleTopMargin,.FlexibleBottomMargin]
            view.filter = IMPFilter(context: self.context)
            
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
        
        var cameraEventHandlers = [cameraEventBlockType]()
        var videoEventHandlers  = [videoEventBlockType]()
        var liveViewReadyHandlers = [liveViewEventBlockType]()
        
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
        
        ///  Check access to camera
        ///
        ///  - parameter complete: complete hanlder
        ///
        func requestAccess(complete:AccessHandler) {
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: {
                (granted: Bool) -> Void in
                complete(granted)
            });
        }
        
        var        _currentCamera:AVCaptureDevice!
        
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
                        
                        s.commitConfiguration()
                        
                        //
                        // Full size Image
                        //
                        stillImageOutput = AVCaptureStillImageOutput()
                        updateStillImageSettings()

                        updateConnection()
                        
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name: AVCaptureSessionDidStartRunningNotification, object: session)
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name:
                            AVCaptureSessionDidStopRunningNotification, object: session)
                    }
                }
                catch let error as NSError {
                    NSLog("IMPCameraManager error: \(error) \(__FILE__):\(__LINE__)")
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
                NSLog("IMPCameraManager error: \(error) \(__FILE__):\(__LINE__)")
            }
        }
        
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
        
    }
    
#endif