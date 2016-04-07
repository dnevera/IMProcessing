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
        
        public typealias cameraEventBlockType = ((camera:IMPCameraManager)->Void)
        public typealias cameraReadyBlockType = ((camera:IMPCameraManager, ready:Bool)->Void)
        
        //
        // Public API
        //
        
        ///  @brief Still image compression settings
        public struct Compression {
            let isHardware:Bool
            let quality:Float
        }
        
        public typealias AccessHandler = ((Bool) -> Void)
        
        public var isRunnig:Bool {
            return session.running
        }

        public var isPaused:Bool {
            return isVideoPaused
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
        public func start(access:AccessHandler) {
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
                access(granted)
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
            self.videoStopObserversHandle()
        }
        
        ///  Resume paused presentation of video frames in liveView
        public func resume() {
            isVideoPaused = false
        }
        
        /// Live view Metal device context
        public var context:IMPContext!
        
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
        
        /// Live video viewport
        public var liveView:IMPView {
            return _liveView
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
                    videoStartObserversHandle()
                }
                
                if (connection.supportsVideoOrientation){
                    connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                }
                
                if (connection.supportsVideoMirroring) {
                    connection.videoMirrored = false
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
        
        public func addCameraReadyObserver(observer:cameraReadyBlockType){
            readyHandlers.append(observer)
        }
        
        ///  Add new observer calls when video capturing session starts first time after creating or resumnig after pause.
        ///
        ///  - parameter observer: camera event block
        public func addVideoStartObserver(observer:cameraEventBlockType){
            videoStartHandlers.append(observer)
        }

        /// Add new observer calls when camera stops for capturing.
        ///
        ///  - parameter observer: camera event block
        public func addVideoStopObserver(observer:cameraEventBlockType){
            videoStopHandlers.append(observer)
        }

        ///  Add new observer calls when the first frame from video stream presents in live viewport after camera starting.
        ///
        ///  - parameter observer: camera event block
        public func addLiveViewReadyObserver(observer:cameraEventBlockType){
            liveViewReadyHandlers.append(observer)
        }
        
        
        //
        // Internal utils and vars
        //
        var isVideoStarted   = false
        var isVideoPaused    = true {
            didSet {
                isVideoSuspended = oldValue
            }
        }
        var isVideoSuspended      = false
        
        var readyHandlers  = [cameraReadyBlockType]()
        var videoStartHandlers  = [cameraEventBlockType]()
        var videoStopHandlers   = [cameraEventBlockType]()
        var liveViewReadyHandlers = [cameraEventBlockType]()
        
        func videoStartObserversHandle() {
            for o in videoStartHandlers {
                o(camera: self)
            }
        }

        func videoStopObserversHandle() {
            for o in videoStopHandlers {
                o(camera: self)
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
            for  o in readyHandlers {
                o(camera: self, ready: isRunnig)
            }
        }
        
        var sessionQueue = dispatch_queue_create(IMProcessing.names.prefix+"preview.video", DISPATCH_QUEUE_SERIAL)
        
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
                        updateStillImageSettings()
                        
                        //
                        // Current capture connection
                        //
                        currentConnection = liveViewOutput.connectionWithMediaType(AVMediaTypeVideo)
                        currentConnection.automaticallyAdjustsVideoMirroring = false
                        
                        s.commitConfiguration()
                        
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name: AVCaptureSessionDidStartRunningNotification, object: session)
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.runningNotification(_:)), name:
                            AVCaptureSessionDidStopRunningNotification, object: session)
                    }
                }
                catch {}
            }
        }
        var session:AVCaptureSession!
        
        var videoInput:AVCaptureDeviceInput!
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