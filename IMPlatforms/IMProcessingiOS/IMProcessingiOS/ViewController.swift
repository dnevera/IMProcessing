//
//  ViewController.swift
//  IMProcessingiOS
//
//  Created by denis svinarchuk on 24.12.15.
//  Copyright © 2015 ImageMetalling. All rights reserved.
//

import UIKit
import IMProcessing
import SnapKit

let TEST_CAMERA = true
let BLUR_FILTER = false


extension String {
    static func uniqueString() -> String {
        let uuidObj = CFUUIDCreate(nil)
        return CFUUIDCreateString(nil, uuidObj) as String
    }
}

class IMPTestFilter: IMPFilter {
    
    var rangeSolver = IMPHistogramRangeSolver()
    var contrast:IMPContrastFilter!
    var histogram:IMPHistogramAnalyzer!
    
    required init(context: IMPContext) {
        super.init(context: context)
        
        histogram = IMPHistogramAnalyzer(context: context, hardware: .GPU)
        
        histogram.downScaleFactor = 0.5
        
        rangeSolver.clipping.shadows = 0.1
        rangeSolver.clipping.highlights = 0.1
        
        histogram.addSolver(rangeSolver)
        
        histogram.addUpdateObserver { (histogram) -> Void in
            self.contrast.adjustment.minimum = self.rangeSolver.minimum
            self.contrast.adjustment.maximum = self.rangeSolver.maximum
        }
        
        contrast = IMPContrastFilter(context: context)
        contrast.adjustment.blending.opacity = 0.0
        
        contrast.addSourceObserver { (source) -> Void in
            self.histogram.source = source
        }
        
        addFilter(contrast)
    }
}


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    let documentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
    lazy var defaultImagesDirectory:String = {
        let d = "images"
        self.createFolder(d)
        return d
    }()
    var uniqueImageFile:String {
        return String(format: "%@/%@/%@.jpeg", documentsDirectory,defaultImagesDirectory,String.uniqueString())
    }
    
    func createFolder(defaultFolder:String) {
        
        let documentsDirectory = self.documentsDirectory;
        let cacheDirectory = (documentsDirectory as NSString).stringByAppendingPathComponent(defaultFolder) as String
        
        if (NSFileManager.defaultManager().fileExistsAtPath(cacheDirectory) == false) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(cacheDirectory, withIntermediateDirectories:true, attributes:nil)
            }
            catch let error as NSError {
                NSLog("\(error)")
            }
        }
    }
    
    
    var cameraManager:IMPCameraManager!
    var containerView:UIView!
    
    var imageView:IMPImageView!
    var blur:IMPGaussianBlurFilter!
    var test:IMPTestFilter!
    
    var filter:IMPFilter?
    
    let flashButton  = UIButton(type: .System)
    let resetButton  = UIButton(type: .System)
    let pauseButton  = UIButton(type: .System)
    let toggleCamera = UIButton(type: .System)
    let stopButton   = UIButton(type: .System)
    let slider = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.view.backgroundColor = IMProcessing.css.background

        let context = IMPContext(lazy: true)
        
        if BLUR_FILTER {
            blur = IMPGaussianBlurFilter(context: context)
            filter = blur
        }
        else{
            test = IMPTestFilter(context: context)
            filter = test
        }
        

        if !TEST_CAMERA {
            imageView = IMPImageView(context: (filter?.context)!,  frame: CGRectMake( 0, 20,
                self.view.bounds.size.width,
                self.view.bounds.size.height*3/4
                ))
            self.view.insertSubview(imageView, atIndex: 0)
            
            imageView.filter = filter
        }
        else {
            containerView = UIView(frame: CGRectMake( 0, 0,
                self.view.bounds.size.width,
                self.view.bounds.size.height*3/4
                ))
            self.view.insertSubview(containerView, atIndex: 0)
            
            cameraManager = IMPCameraManager(containerView: containerView)
            
            cameraManager.liveView.filter = filter
            
            cameraManager.compression = IMPCameraManager.Compression(isHardware: true, quality: 1)
            
            NSLog(" Camera staring ... ")
            
            //
            //
            //
            cameraManager.start { (granted) -> Void in
                
                //
                // Check applic permissions for the app
                //
                if !granted {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                    
                        //
                        // In case app does not have any perms to access device camera launch System Settings
                        //
                        let alert = UIAlertController(
                            title:   "Camera is not granted",
                            message: "This application does not have permission to use camera. Please update your privacy settings.",
                            preferredStyle: .Alert)
                        
                        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { action -> Void in }
                        alert.addAction(cancelAction)
                        
                        let settingsAction = UIAlertAction(title: "Settings", style: .Default) { action -> Void in
                            if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
                                UIApplication.sharedApplication().openURL(appSettings)
                            }
                        }
                        alert.addAction(settingsAction)
                        
                        self.presentViewController(alert, animated: true, completion: nil)
                    })
                }
                else{
                    NSLog("... focusMode = \(self.cameraManager.focusMode.rawValue) exposureMode = \(self.cameraManager.exposureMode.rawValue)")
                }
            }
            
            cameraManager.addCameraObserver({ (camera, ready) in
                NSLog(" Camera ready = \(ready) ")
                dispatch_async(dispatch_get_main_queue(), {
                    self.stopButton.setTitle(ready ? "Stop" : "Start", forState: .Normal)
                })
            })
            
            cameraManager.addVideoObserver({ (camera, running) in
                NSLog(" Video running = \(running) ")
                dispatch_async(dispatch_get_main_queue(), {
                    self.pauseButton.setTitle(running ? "Pause" : "Pause", forState: .Normal)
                })
            })
            
            cameraManager.addLiveViewReadyObserver({ (camera) in
                NSLog(" Live view ready! ")
            })
            
            //
            // Focus POI
            //
            let focusTap = UITapGestureRecognizer(target: self, action: #selector(focusHandler(_:)))
            focusTap.numberOfTapsRequired = 1
            focusTap.delaysTouchesBegan = true
            cameraManager.liveView.addGestureRecognizer(focusTap)
            
            //
            // Focus POI panning
            //
            let focusPan = UILongPressGestureRecognizer(target: self, action: #selector(focusPanHandler(_:)))
            focusPan.minimumPressDuration = 0.1
            cameraManager.liveView.addGestureRecognizer(focusPan)
            
            //
            // Exposure POI
            //
            let exposureDoubleTap = UITapGestureRecognizer(target: self, action: #selector(exposureHandler(_:)))
            exposureDoubleTap.numberOfTapsRequired = 2
            exposureDoubleTap.delaysTouchesBegan = false
            cameraManager.liveView.addGestureRecognizer(exposureDoubleTap)

            
            let zoomDoubleTap = UITapGestureRecognizer(target: self, action: #selector(zoomHandler(_:)))
            zoomDoubleTap.numberOfTapsRequired = 2
            zoomDoubleTap.numberOfTouchesRequired = 2
            cameraManager.liveView.addGestureRecognizer(zoomDoubleTap)

        }

        let triggerButton = UIButton(type: .System)
        if TEST_CAMERA {
            triggerButton.backgroundColor = IMPColor.clearColor()
            triggerButton.tintColor = IMPColor.whiteColor()
            triggerButton.setImage(IMPImage(named: "trigger"), forState: .Normal)
            triggerButton.addTarget(self, action: #selector(self.capturePhoto(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(triggerButton)
            
            triggerButton.snp_makeConstraints(closure: { (make) in
                make.top.equalTo(containerView.snp_bottom).offset(10)
                make.centerX.equalTo(view).offset(0)
            })
            

            flashButton.setTitle("Flash Off", forState: .Normal)
            flashButton.addTarget(self, action: #selector(self.flashToggle(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(flashButton)
            
            flashButton.snp_makeConstraints(closure: { (make) in
                make.top.equalTo(containerView.snp_bottom).offset(20)
                make.left.equalTo(view).offset(10)
            })            

            
            stopButton.setTitle("Stop", forState: .Normal)
            stopButton.addTarget(self, action: #selector(self.stopCamera(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(stopButton)
            
            stopButton.snp_makeConstraints(closure: { (make) in
                make.centerY.equalTo(triggerButton.snp_centerY).offset(0)
                make.left.equalTo(view).offset(10)
            })
            
            pauseButton.setTitle("Pause", forState: .Normal)
            pauseButton.addTarget(self, action: #selector(self.pauseCamera(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(pauseButton)
            
            pauseButton.snp_makeConstraints(closure: { (make) in
                make.centerY.equalTo(triggerButton.snp_centerY).offset(0)
                make.left.equalTo(stopButton.snp_right).offset(20)
            })
            
            
            toggleCamera.setTitle("Back", forState: .Normal)
            toggleCamera.addTarget(self, action: #selector(self.toggeleCamera(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(toggleCamera)
            
            toggleCamera.snp_makeConstraints(closure: { (make) in
                make.centerY.equalTo(triggerButton.snp_centerY).offset(0)
                make.right.equalTo(view).offset(-10)
            })
            
            resetButton.setTitle("Reset", forState: .Normal)
            resetButton.addTarget(self, action: #selector(self.resetHandler(_:)), forControlEvents: .TouchUpInside)
            view.addSubview(resetButton)
            resetButton.snp_makeConstraints(closure: { (make) in
                make.centerY.equalTo(triggerButton.snp_centerY).offset(0)
                make.right.equalTo(toggleCamera.snp_left).offset(-10)
            })
            
        }
        
        let albumButton = UIButton(type: .System)
        
        albumButton.backgroundColor = IMPColor.clearColor()
        albumButton.tintColor = IMPColor.whiteColor()
        albumButton.setImage(IMPImage(named: "select-photos"), forState: .Normal)
        albumButton.addTarget(self, action: #selector(self.openAlbum(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(albumButton)
        
        albumButton.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-40)
            make.left.equalTo(view).offset(40)
        }
        
        
        
        slider.value = TEST_CAMERA ? 0.5 : 0.0
        slider.addTarget(self, action: #selector(ViewController.changeValue(_:)), forControlEvents: .ValueChanged)
        view.addSubview(slider)
        
        slider.snp_makeConstraints { (make) -> Void in
            if TEST_CAMERA {
                make.top.equalTo(triggerButton.snp_bottom).offset(5)
                make.left.equalTo(view).offset(20)
            }
            else {
                make.bottom.equalTo(view).offset(-40)
                make.left.equalTo(albumButton.snp_right).offset(20)
            }
            make.right.equalTo(view).offset(-20)
        }
        
        if !TEST_CAMERA{
            IMPMotionManager.sharedInstance.addRotationObserver { (orientation) -> Void in
                self.imageView.setOrientation(orientation, animate:true)
            }
        }
        else {
            albumButton.hidden = true
        }
    }
    
    
    func resetHandler(sender:UIButton)  {
        cameraManager.resetFocus { (camera) in
            NSLog("... focus has reseted at default POI")
        }
        cameraManager.resetExposure { (camera) in
            NSLog("... exposure has reseted at default POI --> compensation = \(self.cameraManager.exposureCompensation)")
            dispatch_async(dispatch_get_main_queue(), {
                let range = abs(self.cameraManager.exposureCompensationRange.min)+abs(self.cameraManager.exposureCompensationRange.max)
                self.slider.value = self.cameraManager.exposureCompensation / (range/2) + 0.5
            })
        }
    }
    
    func focusPanHandler(gesture: UITapGestureRecognizer) {
        let point = gesture.locationInView(self.cameraManager.liveView)

        switch gesture.state {
        case .Began:
            
            cameraManager.autoFocus(atPoint: point)
            cameraManager.autoExposure(atPoint: point)
            
        case .Changed:
            
            cameraManager.smoothFocusEnabled = true
            cameraManager.autoFocus(atPoint: point)
            cameraManager.autoExposure(atPoint: point)
            
        case .Ended:
            
            cameraManager.autoFocus(atPoint: point, complete: { (camera) in
                self.cameraManager.smoothFocusEnabled = false
                NSLog("... panning focus at \(point) done!")
            })
            cameraManager.autoExposure(atPoint: point)
            
        default:
            break
        }
    }

    func focusHandler(gesture: UITapGestureRecognizer) {
        let point = gesture.locationInView(cameraManager.liveView)
        if gesture.state == .Ended {
            
            NSLog("... auto focus at \(point) start ... mode = \(cameraManager.focusMode.rawValue)")
            cameraManager.autoFocus(atPoint: point, complete: { (camera) in
                NSLog("... auto focus at \(point) done! mode = \(camera.focusMode.rawValue)")
            })
        }
    }

    func exposureHandler(gesture: UITapGestureRecognizer) {
        if gesture.state == .Ended {
            let point = gesture.locationInView(cameraManager.liveView)
            
            NSLog("... auto exposure at \(point) start ...")
            cameraManager.autoExposure(atPoint: point, complete: { (camera) in
                NSLog("... auto exposure at \(point) done! mode = \(camera.exposureMode.rawValue)")
            })
        }
    }

    var zoomed = false
    var inZooming = false
    func zoomHandler(gesture:UITapGestureRecognizer)  {
        if gesture.state == .Ended {
            if inZooming {
                return
            }
            
            inZooming = true
            NSLog("... zoom \(zoomed ? "in" : "out" ) ...")
            cameraManager.setZoom(factor: zoomed ? 1 : 4.532 , animate: true, complete: { (camera, factor) in
                self.inZooming = false
                NSLog("... zoommed \(self.zoomed ? "in" : "out" ) ...")
                self.zoomed = !self.zoomed
            })
        }
    }
    
    func changeValue(sender:UISlider){
        dispatch_async(filter!.context.dispatchQueue) { () -> Void in
            if BLUR_FILTER {
                self.blur.radius = (128 * sender.value).int
            }
            else{
                
                if TEST_CAMERA {
                    let range = abs(self.cameraManager.exposureCompensationRange.min)+abs(self.cameraManager.exposureCompensationRange.max)
                    self.cameraManager.exposureCompensation = (sender.value - 0.5) * range/2
                }
                else {
                    self.test.contrast.adjustment.blending.opacity = sender.value
                }
            }
        }
    }
    
    func capturePhoto(sender:UIButton){
        NSLog("... capture... ")
        cameraManager.capturePhoto(file: uniqueImageFile) { (camera, finished, file, metadata, error) in
            NSLog("... captured : finished = \(finished) file = \(NSURL(fileURLWithPath: file).pathComponents?.last) meta = \(metadata) error = \(error)")
        }
    }

    var currentFlash:Int = 0
    func flashToggle(sender:UIButton){
        currentFlash += 1
        if currentFlash > 2 {
            currentFlash = 0
        }
        cameraManager.flashMode = [.Off,.On,.Auto][currentFlash]
        let name = ["Off", "On", "Auto"][currentFlash]
        dispatch_async(dispatch_get_main_queue()) { 
            sender.setTitle(String(format: "Flash %@", name), forState: .Normal)
        }
    }
    
    func stopCamera(sender:UIButton){
        if cameraManager.isReady {
            print("... stop ... ")
            cameraManager.stop()
        }
        else {
            print("... start ... ")
            cameraManager.start({ (granted) in
                print("... starting ... \(granted)")
            })
        }
    }
    
    func pauseCamera(sender:UIButton){
        if cameraManager.isRunning {
            print("... resume ... ")
            cameraManager.pause()
        }
        else {
            print("... paused ... ")
            cameraManager.resume()
        }
    }
    
    func toggeleCamera(sender:UIButton){
        
        dispatch_async(dispatch_get_main_queue()) { 
            
            let blurredView = UIVisualEffectView(effect: UIBlurEffect(style:.Dark))
            blurredView.frame = self.containerView.bounds
            self.containerView.addSubview(blurredView)
            blurredView.alpha = 0.0
            
            UIView.animateWithDuration(0.5, animations: {
                blurredView.alpha = 1.0
            })
            
            self.cameraManager.toggleCamera { (camera, toggled) in
                dispatch_async(dispatch_get_main_queue()) {
                    UIView.animateWithDuration(0.5, animations: {
                            blurredView.alpha = 0.0
                        }, completion: { (finished) in
                            blurredView.removeFromSuperview()
                    })
                }
            }
        }
    }
    
    func openAlbum(sender:UIButton){
        imagePicker = UIImagePickerController()
    }
    
    var imagePicker:UIImagePickerController!{
        didSet{
            self.imagePicker.delegate = self
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            if let actualPicker = self.imagePicker{
                self.presentViewController(actualPicker, animated:true, completion:nil)
            }
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        let chosenImage:UIImage? = info[UIImagePickerControllerOriginalImage] as? UIImage
        
        if let actualImage = chosenImage{
            
            let image = IMPImageProvider(context: imageView.context, image: actualImage, maxSize: 1500)
            imageView?.filter?.source = image
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

