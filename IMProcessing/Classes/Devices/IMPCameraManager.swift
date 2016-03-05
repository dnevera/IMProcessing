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
        //
        // Public API
        //
        
        ///  @brief Still image compression settings
        public struct Compression {
            let isHardware:Bool
            let quality:Float
        }
        
        public typealias AccessHandler = ((Bool) -> Void)
        
        ///
        ///  Create Camera Manager instance
        ///
        ///  - parameter containerView: container view contains live view window
        ///
        public init(containerView:UIView) {
            
            super.init()
            
            defer{
                _currentCamera = backCamera
                
                var _context:IMPContext!
                
                dispatch_sync(sessionQueue, { () -> Void in
                    _context = IMPContext(lazy: true)
                })
                
                self.liveView = IMPView(context: _context)
                self.liveView.frame = containerView.bounds
                self.liveView.backgroundColor = IMPColor.yellowColor()
                self.liveView.autoresizingMask = [.FlexibleLeftMargin,.FlexibleRightMargin,.FlexibleTopMargin,.FlexibleBottomMargin]
                containerView.addSubview(self.liveView)
                
                self.liveView.filter = IMPFilter(context: _context)
                
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
                        dispatch_async(self.sessionQueue, { () -> Void in
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
                })
            }
        }
        
        public func pause() {
        }
        
        public func resume() {
        }
        
        /// Live view Metal devilce context
        public var context:IMPContext! {
            get{
                return liveView.context
            }
        }
        
        /// Live view
        public var liveView:IMPView!
        
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
        // Capturing video frames and update live-view to apply IMP-filter
        //
        public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
            
            if connection == currentConnection {
                
                if (connection.supportsVideoOrientation){
                    connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                }
                
                if (connection.supportsVideoMirroring) {
                    connection.videoMirrored = false
                }
                
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    if liveView.source == nil {
                        liveView.source = IMPImageProvider(context: liveView.context, pixelBuffer: pixelBuffer)
                    }
                    else {
                        liveView.source?.update(pixelBuffer: pixelBuffer)
                    }
                }
            }
        }
        
        //
        // Internal utils and vars
        //
        
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