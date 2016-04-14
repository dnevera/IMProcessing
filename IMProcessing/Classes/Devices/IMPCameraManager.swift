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
    public class IMPCameraManager: NSObject, IMPContextProvider, AVCaptureVideoDataOutputSampleBufferDelegate {
        
        public typealias AccessHandler = ((Bool) -> Void)
        public typealias liveViewEventBlockType     = ((camera:IMPCameraManager)->Void)
        public typealias cameraEventBlockType       = ((camera:IMPCameraManager, ready:Bool)->Void)
        public typealias cameraCompleteBlockType    = ((camera:IMPCameraManager)->Void)
        public typealias videoEventBlockType        = ((camera:IMPCameraManager, running:Bool)->Void)
        
        public typealias capturingCompleteBlockType = ((camera:IMPCameraManager, finished:Bool, file:String, metadata:NSDictionary?, error:NSError?)->Void)
        
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
        public var compression = IMPCameraManager.Compression(isHardware: true, quality: 1){
            didSet{
                updateStillImageSettings()
            }
        }
        
        /// Get front camera capture device reference
        public let frontCamera = IMPCameraManager.camera(.Front)
        
        /// Get back camera caprure reference
        public let backCamera  = IMPCameraManager.camera(.Back)
        
        ///  Auto Exposure at a point of interest.
        ///
        ///  - parameter point:    POI
        ///  - parameter complete: complete operations
        public func autoExposure(atPoint point:CGPoint?=nil, complete:cameraCompleteBlockType?=nil){
            controlCameraExposure(atPoint: point, action: { (poi) in
                self.currentCamera.exposurePointOfInterest = poi
                self.currentCamera.exposureMode = .AutoExpose
                }, complete: complete)
        }
        
        ///  Auto Focus at a point of interest
        ///
        ///  - parameter point:    POI
        ///  - parameter complete: complete focusing block
        public func autoFocus(atPoint point:CGPoint?=nil, complete:cameraCompleteBlockType?=nil)  {
            
            controlCameraFocus(atPoint: point,
                               action: { (poi) in
                                self.currentCamera.focusPointOfInterest = poi
                                self.currentCamera.focusMode = .AutoFocus
                }, complete: nil)
            
            if let complete = complete {
                autofocusCompleteQueue.append(completeAutoFocusFunction(complete: complete))
                currentCamera.addObserver(self, forKeyPath: "adjustingFocus", options: .New, context: &IMPCameraManager.focusPointOfInterestContext)
            }
        }
        
        ///  Reset auto focus to default POI
        ///
        ///  - parameter complete: complete operations
        public func resetFocus(complete:cameraCompleteBlockType?=nil){
            controlCameraFocus(atPoint: nil,
                               action: { (poi) in
                                self.currentCamera.focusPointOfInterest = poi
                                self.currentCamera.focusMode = .ContinuousAutoFocus
                }, complete: complete)
        }
        
        public func resetExposure(complete:cameraCompleteBlockType?=nil){            
            dispatch_async(sessionQueue){
                do {
                    try self.currentCamera.lockForConfiguration()
                    self.currentCamera.setExposureTargetBias(0, completionHandler: { (timer) in
                        self.controlCameraExposure(atPoint: nil, action: { (poi) in
                            self.currentCamera.exposureMode = .ContinuousAutoExposure
                            }, complete: complete)
                    })
                    self.currentCamera.unlockForConfiguration()
                }
                catch let error as NSError {
                    NSLog("IMPCameraManager error: \(error): \(#file):\(#line)")
                }
            }
        }
        
        /// Get/Set current focus mode
        public var focusMode:AVCaptureFocusMode {
            set {
                controlCamera(atPoint: nil,
                              supported: currentCamera.isFocusModeSupported(newValue),
                              action:
                    { (poi) in
                        if  newValue == .ContinuousAutoFocus
                            &&
                            self.currentCamera.focusPointOfInterestSupported
                        {
                            self.currentCamera.focusPointOfInterest = poi
                        }
                        self.currentCamera.focusMode = newValue
                    }
                )
            }
            get {
                return currentCamera.focusMode
            }
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
        
        /// Get/Set current exposure mode
        public var exposureMode:AVCaptureExposureMode {
            set {
                if currentCamera.isExposureModeSupported(newValue){
                    var currentPOI = currentCamera.focusPointOfInterest
                    if newValue == .ContinuousAutoExposure {
                        currentPOI = CGPoint(x: 0.5,y: 0.5)
                    }
                    controlCamera(atPoint: currentPOI,
                                  supported: self.currentCamera.exposurePointOfInterestSupported,
                                  action: { (poi) in
                                    self.currentCamera.exposureMode = newValue
                                    self.currentCamera.exposurePointOfInterest = poi
                    })
                }
            }
            get {
                return currentCamera.exposureMode
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
        
        // Get current camera
        var currentCamera:AVCaptureDevice!{
            return _currentCamera
        }

        var _currentCamera:AVCaptureDevice! {
            willSet{
                if (_currentCamera != nil) {
                    self.removeCameraObservers()
                }
            }
            didSet{
                self.addCameraObservers()
            }
        }

        // Live view
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
        
        func controlCameraFocus(atPoint point:CGPoint?, action:((poi:CGPoint)->Void), complete:cameraCompleteBlockType?=nil) {
            controlCamera(atPoint: point,
                          supported: self.currentCamera.focusPointOfInterestSupported
                            && self.currentCamera.isFocusModeSupported(.AutoFocus),
                          action: action,
                          complete: complete)
        }

        func controlCameraExposure(atPoint point:CGPoint?, action:((poi:CGPoint)->Void), complete:cameraCompleteBlockType?=nil) {
            controlCamera(atPoint: point,
                          supported: self.currentCamera.exposurePointOfInterestSupported
                            && self.currentCamera.isExposureModeSupported(.AutoExpose),
                          action: action,
                          complete: complete)
        }

        func controlCamera(atPoint point:CGPoint?=nil, supported: Bool, action:((poi:CGPoint)->Void), complete:cameraCompleteBlockType?=nil) {
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
        
        static var focusPointOfInterestContext = "focusPointOfInterestContext"
        
        class completeAutoFocusFunction {
            var block:cameraCompleteBlockType? = nil
            init(complete:cameraCompleteBlockType){
                self.block = complete
            }
        }
        
        var autofocusCompleteQueue = [completeAutoFocusFunction]()

        func addCameraObservers() {
            currentCamera.addObserver(self, forKeyPath: "focusPointOfInterest", options: .New, context: nil)
        }
        
        func removeCameraObservers() {
            currentCamera.removeObserver(self, forKeyPath: "focusPointOfInterest", context: nil)
        }

        override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
            
            if  context == &IMPCameraManager.focusPointOfInterestContext {
                
                if let new = change?["new"] as? Int {
                    if new == 0 {
                        currentCamera.removeObserver(self, forKeyPath: "adjustingFocus", context: context)
                        if let complete = autofocusCompleteQueue.popLast()?.block {
                            complete(camera:self)
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
        
        ///  Capture image to file
        ///
        ///  - parameter file:     file path
        ///  - parameter complete: completition block
        public func capturePhoto(file file:String, complete:capturingCompleteBlockType?=nil){
            
            if !isReady{
                complete?(camera: self, finished: false, file: file, metadata: nil, error: nil)
                return
            }
            if stillImageOutput.capturingStillImage {
                complete?(camera: self, finished: false, file: file, metadata: nil, error: nil)
                return
            }
            
            if let complete = complete {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    
                    if let connection = IMPCameraManager.connection(AVMediaTypeVideo, connections: self.stillImageOutput.connections) {
                        
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
                                        
                                        var imageOrientation  = UIImageOrientation.Right
                                        
                                        switch (UIDevice.currentDevice().orientation) {
                                        case .LandscapeLeft:
                                            imageOrientation = self.cameraPosition == .Front ? .Down : .Up
                                        case .LandscapeRight:
                                            imageOrientation = self.cameraPosition == .Front ? .Up : .Down
                                        case .PortraitUpsideDown:
                                            imageOrientation = .Left
                                        default: break
                                        }
                                        
                                        newMeta[IMProcessing.meta.versionKey]          = IMProcessing.meta.version
                                        newMeta[IMProcessing.meta.imageOrientationKey] = imageOrientation.rawValue
                                        newMeta[IMProcessing.meta.imageSourceExposureMode] = self.currentCamera.exposureMode.rawValue
                                        newMeta[IMProcessing.meta.imageSourceFocusMode] = self.currentCamera.focusMode.rawValue
                                        
                                        meta = newMeta
                                    }
                                    
                                    do {
                                        if self.compression.isHardware {
                                            let imageDataJpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                                            try imageDataJpeg.writeToFile(file, options: .AtomicWrite)
                                            complete(camera: self, finished: true, file: file, metadata: meta, error: nil)
                                        }
                                        else{
                                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                                try IMPJpegturbo.writePixelBuffer(pixelBuffer, toJpegFile: file, compression: self.compression.quality.cgloat, inputColorSpace:JPEG_TURBO_BGRA)
                                                complete(camera: self, finished: true, file: file, metadata: meta, error: nil)
                                            }
                                            else {
                                                complete(camera: self, finished: false, file: file, metadata: meta, error: nil)
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