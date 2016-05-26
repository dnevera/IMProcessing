//
//  ViewController.swift
//  IMPGeometryTestiOS
//
//  Created by denis svinarchuk on 05.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import UIKit
import IMProcessing
import SnapKit
import AssetsLibrary
import ImageIO

extension String{
    static func uniqString() -> String{
        return CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String;
    }
}

extension IMPImage {
    var metaData:[String: AnyObject]? {
        get{
            let imgdata = NSData(data: UIImageJPEGRepresentation(self, 0.5)!)
            var meta:NSDictionary? = nil
            if let source = CGImageSourceCreateWithData(imgdata, nil) {
                meta = CGImageSourceCopyPropertiesAtIndex(source,0,nil)
            }
            return meta as! [String: AnyObject]?
        }
    }
    
    
}

class IMPFileManager{
    
    init(defaultFolder:String){
        self.current = defaultFolder
        self.createDefaultFolder(self.current!)
    }
    
    var documentsDirectory:NSString{
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        return paths [0] as NSString
    }
    
    var current:String?{
        didSet{
            self.createDefaultFolder(self.current!)
        }
    }
    
    internal
    func createDefaultFolder(folder:String) {
        
        let cacheDirectory = self.documentsDirectory.stringByAppendingPathComponent(folder);
        
        if NSFileManager.defaultManager().fileExistsAtPath(cacheDirectory) == false{
            do{
                try NSFileManager.defaultManager().createDirectoryAtPath(cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            catch  {
                NSLog(" *** %@ cloud no be created...", cacheDirectory)
            }
        }
    }
    
    func filePathForKey(fileKey: String?) ->String {
        
        var file:String?
        
        if fileKey == nil {
            file = String.uniqString()
        }
        else{
            file = fileKey
        }
        return String(format: "%@/%@/%@.jpeg", self.documentsDirectory, self.current!, file!)
    }
}


public func == (left:NSPoint, right:NSPoint) -> Bool{
    return left.x==right.x && left.y==right.y
}

public func != (left:NSPoint, right:NSPoint) -> Bool{
    return !(left==right)
}

public func - (left:NSPoint, right:NSPoint) -> NSPoint {
    return NSPoint(x: left.x-right.x, y: left.y-right.y)
}

public func + (left:NSPoint, right:NSPoint) -> NSPoint {
    return NSPoint(x: left.x+right.x, y: left.y+right.y)
}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    var context = IMPContext()
    
    var imageView:IMPView!
    
    lazy var filter:IMPFilter = {
        return IMPFilter(context:self.context)
    }()
    
    lazy var transformFilter:IMPPhotoPlateFilter = {
        return IMPPhotoPlateFilter(context:self.context)
    }()
    
    lazy var cropFilter: IMPCropFilter = {
        return IMPCropFilter(context:self.context)
    }()
    
    lazy var warpFilter: IMPWarpFilter = {
        return IMPWarpFilter(context:self.context)
    }()
    
    var workingFolder = IMPFileManager(defaultFolder: "images")
    
    let slider = UISlider()
    let scaleSlider = UISlider()
    
    
    var currentScaleFactor:Float {
        return IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: transformFilter.model)
    }
    
    
    ///
    ///  Current crop region with the transformation model
    ///
    var currentCropRegion:IMPRegion {
        let offset = (1 - currentScaleFactor * transformFilter.scale.x ) / 2
        return IMPRegion(left: offset, right: offset, top: offset, bottom: offset)
    }
    
    
    ///  Check bounds of inscribed Rectangular
    func checkBounds() {
        
        let aspect   = transformFilter.aspect
        let model    = transformFilter.model
        //
        // Model of Cropped Quad
        //
        let cropQuad = IMPQuad(region:currentCropRegion, aspect: aspect)
        
        //
        // Model of
        //
        let transformedQuad = IMPPlate(aspect: aspect).quad(model: model)
        
        //
        // Offset for transformed quad which should contain inscribed croped quad
        //
        // NOTE: 
        // 1. quads should be rectangle
        // 2. scale of transformed quad should be greate then of equal scaleFactorFor for the transformed model:
        //    IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: model)
        //
        let offset   = transformedQuad.translation(quad: cropQuad)
        
        animateTranslation(-offset)
    }
    
    //
    // Just trivial example! In real app we should implement some based on RT-timer
    //
    let animatorQ = dispatch_queue_create("animator", DISPATCH_QUEUE_CONCURRENT)
    func animateTranslation(offset:float2)  {
        
        let cicles = 200
        let shift = offset / cicles.float
        let duration:UInt32 = 50000
        
        let final_translation = transformFilter.translation + offset
        
        dispatch_async(animatorQ) {
            
            for _ in 0..<cicles {
                dispatch_async(dispatch_get_main_queue() , {
                    self.transformFilter.translation += shift
                })
                usleep(duration / UInt32(cicles))
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.transformFilter.translation = final_translation
            })
        }
    }
    
    func updateCrop()  {
        self.cropFilter.region = currentCropRegion
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        
        transformFilter.backgroundColor = IMPColor.grayColor()
        
        filter.addFilter(transformFilter)
        filter.addFilter(warpFilter)
        filter.addFilter(cropFilter)
        
        imageView = IMPView(context: (filter.context)!,  frame: CGRectMake( 0, 20,
            self.view.bounds.size.width,
            self.view.bounds.size.height*3/4
            ))
        self.view.insertSubview(imageView, atIndex: 0)
        
        imageView.filter = filter
        
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
        
        let resetButton = UIButton(type: .System)
        
        resetButton.setTitle("Reset", forState: .Normal)
        resetButton.backgroundColor = IMPColor.clearColor()
        resetButton.tintColor = IMPColor.whiteColor()
        resetButton.addTarget(self, action: #selector(self.reset(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(resetButton)
        
        resetButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.snp_bottom).offset(10)
            make.left.equalTo(view).offset(40)
        }
        
        
        let enableButton = UISwitch()
        enableButton.on = enableWarpFilter
        enableButton.backgroundColor = IMPColor.clearColor()
        enableButton.tintColor = IMPColor.whiteColor()
        enableButton.addTarget(self, action: #selector(self.toggleWarpFilter(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(enableButton)
        
        enableButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.snp_bottom).offset(10)
            make.right.equalTo(view).offset(-40)
        }
        
        
        slider.value = 0.5
        slider.addTarget(self, action: #selector(ViewController.rotate(_:)), forControlEvents: .ValueChanged)
        view.addSubview(slider)
        
        slider.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-60)
            make.left.equalTo(albumButton.snp_right).offset(20)
            make.right.equalTo(view).offset(-20)
        }
        
        
        scaleSlider.value = 0.5
        scaleSlider.addTarget(self, action: #selector(ViewController.scale(_:)), forControlEvents: .ValueChanged)
        view.addSubview(scaleSlider)
        
        scaleSlider.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-20)
            make.left.equalTo(albumButton.snp_right).offset(20)
            make.right.equalTo(view).offset(-20)
        }
        
        IMPMotionManager.sharedInstance.addRotationObserver { (orientation) in
            self.imageView.setOrientation(orientation, animate: true)
        }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panHandler(_:)))
        imageView.addGestureRecognizer(pan)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        longPress.minimumPressDuration = 0.1
        imageView.addGestureRecognizer(longPress)
    }
    
    var finger_point_offset = NSPoint()
    var finger_point_before = NSPoint()
    
    var finger_point = NSPoint() {
        didSet{
            finger_point_before = oldValue
            finger_point_offset = finger_point_before - finger_point
        }
    }
    
    var tuoched = false
    
    enum PointerPlace {
        case LeftBottom
        case LeftTop
        case RightBottom
        case RightTop
        case Top
        case Bottom
        case Left
        case Right
        case Undefined
    }
    
    var pointerPlace:PointerPlace = .Undefined
    
    func panHandler(gesture:UIPanGestureRecognizer)  {
        if gesture.state == .Began {
            tapDown(gesture)
        }
        else if gesture.state == .Changed {
            if enableWarpFilter{
                panningWarp(gesture)
            }
            else {
                translateImage(gesture)
            }
        }
        else if gesture.state == .Ended{
            tapUp()
        }
    }
    
    //
    // Convert orientation from Portrait to others
    //
    func  convertOrientation(point:NSPoint) -> NSPoint {
        
        let o = imageView.orientation
        
        if o == .Portrait {
            return point
        }
        
        //
        // adjust absolute coordinates to relative
        //
        var new_point = point
        
        let w = imageView.bounds.size.width.float
        let h = imageView.bounds.size.height.float
        
        new_point.x = new_point.x/w.cgfloat * 2 - 1
        new_point.y = new_point.y/h.cgfloat * 2 - 1
        
        // make relative point
        var p = float4(new_point.x.float,new_point.y.float,0,1)
        
        // make idenity transformation
        var identity = IMPMatrixModel.identity
        
        if o == .PortraitUpsideDown {
            //
            // rotate up-side-down
            //
            identity.rotateAround(vector: IMPMatrixModel.degrees180)
            
            // transform point
            p  =  float4x4(identity.transform) * p
            
            // back to absolute coords
            new_point.x = (p.x.cgfloat+1)/2 * w
            new_point.y = (p.y.cgfloat+1)/2 * h
        }
        else {
            if o == .LandscapeLeft {
                identity.rotateAround(vector: IMPMatrixModel.right)
                
            }else if o == .LandscapeRight {
                identity.rotateAround(vector: IMPMatrixModel.left)
            }
            p  =  float4x4(identity.transform) * p
            
            new_point.x = (p.x.cgfloat+1)/2 * h
            new_point.y = (p.y.cgfloat+1)/2 * w
        }
        
        
        return new_point
    }
    
    func tapDown(gesture:UIPanGestureRecognizer) {
        
        finger_point = convertOrientation(gesture.locationInView(imageView))
        
        finger_point_before = finger_point
        finger_point_offset = NSPoint(x: 0,y: 0)
        tuoched = true
        
        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float
        
        if finger_point.x > w/3 && finger_point.x < w*2/3 && finger_point.y < h/2 {
            pointerPlace = .Top
        }
        else if finger_point.x < w/2 && finger_point.y >= h/3 && finger_point.y <= h*2/3 {
            pointerPlace =  .Left
        }
        else if finger_point.x < w/3 && finger_point.y < h/3 {
            pointerPlace = .LeftTop
        }
        else if finger_point.x < w/3 && finger_point.y > h*2/3 {
            pointerPlace = .LeftBottom
        }
            
        else if finger_point.x > w/3 && finger_point.x < w*2/3 && finger_point.y > h/2 {
            pointerPlace = .Bottom
        }
        else if finger_point.x > w/2 && finger_point.y >= h/3 && finger_point.y <= h*2/3 {
            pointerPlace = .Right
        }
        else if finger_point.x > w/3 && finger_point.y < h/3 {
            pointerPlace = .RightTop
        }
        else if finger_point.x > w/3 && finger_point.y > h*2/3 {
            pointerPlace = .RightBottom
        }
        
    }
    
    func tapUp() {
        tuoched = false
        if !enableWarpFilter {
            checkBounds()
        }
    }
    
    func panningDistance() -> float2 {
        
        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float
        
        let x = 1/w * finger_point_offset.x.float
        let y = -1/h * finger_point_offset.y.float
        
        let f = IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: transformFilter.model)
        
        return float2(x,y) * f * transformFilter.scale.x
    }
    
    func translateImage(gesture:UIPanGestureRecognizer)  {
        
        if !tuoched {
            return
        }
        
        finger_point = convertOrientation(gesture.locationInView(imageView))
        
        let distance = panningDistance()
        
        transformFilter.translation -= distance
    }
    
    func panningWarp(gesture:UIPanGestureRecognizer)  {
        
        if !tuoched {
            return
        }
        
        finger_point = convertOrientation(gesture.locationInView(imageView))
        
        let distance = panningDistance()
        
        if pointerPlace == .Left {
            warpFilter.sourceQuad.left_bottom.x = warpFilter.sourceQuad.left_bottom.x + distance.x
            warpFilter.sourceQuad.left_top.x = warpFilter.sourceQuad.left_top.x + distance.x
        }
        else if pointerPlace == .Bottom {
            warpFilter.sourceQuad.left_bottom.y = warpFilter.sourceQuad.left_bottom.y + distance.y
            warpFilter.sourceQuad.right_bottom.y = warpFilter.sourceQuad.right_bottom.y + distance.y
        }
        else if pointerPlace == .LeftBottom {
            warpFilter.sourceQuad.left_bottom.x = warpFilter.sourceQuad.left_bottom.x + distance.x
            warpFilter.sourceQuad.left_bottom.y = warpFilter.sourceQuad.left_bottom.y + distance.y
        }
        else if pointerPlace == .LeftTop {
            warpFilter.sourceQuad.left_top.x = warpFilter.sourceQuad.left_top.x + distance.x
            warpFilter.sourceQuad.left_top.y = warpFilter.sourceQuad.left_top.y + distance.y
        }
            
        else if pointerPlace == .Right {
            warpFilter.sourceQuad.right_bottom.x = warpFilter.sourceQuad.right_bottom.x + distance.x
            warpFilter.sourceQuad.right_top.x = warpFilter.sourceQuad.right_top.x + distance.x
        }
        else if pointerPlace == .Top {
            warpFilter.sourceQuad.left_top.y = warpFilter.sourceQuad.left_top.y + distance.y
            warpFilter.sourceQuad.right_top.y = warpFilter.sourceQuad.right_top.y + distance.y
        }
        else if pointerPlace == .RightBottom {
            warpFilter.sourceQuad.right_bottom.x = warpFilter.sourceQuad.right_bottom.x + distance.x
            warpFilter.sourceQuad.right_bottom.y = warpFilter.sourceQuad.right_bottom.y + distance.y
        }
        else if pointerPlace == .RightTop {
            warpFilter.sourceQuad.right_top.x = warpFilter.sourceQuad.right_top.x + distance.x
            warpFilter.sourceQuad.right_top.y = warpFilter.sourceQuad.right_top.y + distance.y
        }
        
    }
    
    func longPress(gesture:UIPanGestureRecognizer)  {
        if gesture.state == .Began {
            filter.enabled = false
        }
        else if gesture.state == .Ended {
            filter.enabled = true
        }
    }
    
    func reset(sender:UIButton){
        
        slider.value = 0.5
        rotate(slider)
        
        scaleSlider.value = 0.5
        scale(scaleSlider)
        
        transformFilter.translation = float2(0)
        
        warpFilter.sourceQuad = IMPQuad()
        warpFilter.destinationQuad = IMPQuad()
    }
    
    var enableWarpFilter = false
    
    func toggleWarpFilter(sender:UISwitch){
        enableWarpFilter = sender.on
    }
    
    var timer:NSTimer?
    
    func checkBoundsAfterRotation()  {
        dispatch_async(dispatch_get_main_queue()) {
            self.checkBounds()
        }
    }
    
    func rotate(sender:UISlider){
        dispatch_async(context.dispatchQueue) { () -> Void in
            self.transformFilter.angle = IMPMatrixModel.right * (sender.value - 0.5)
            self.updateCrop()
            
            dispatch_async(dispatch_get_main_queue(), {
                if self.timer != nil {
                    self.timer?.invalidate()
                }
                self.timer = NSTimer.scheduledTimerWithTimeInterval(0.03, target: self, selector: #selector(self.checkBoundsAfterRotation), userInfo: nil, repeats: false)
            })
        }
    }
    
    func checkBoundsAfterScale()  {
        dispatch_async(dispatch_get_main_queue()) {
            self.checkBounds()
        }
    }

    func scale(sender:UISlider){
        dispatch_async(context.dispatchQueue) { () -> Void in
            
            var scale = sender.value * 2
            
            if scale < 1 {
                //
                // scale can't be less then 1 while we try to crop
                //
                scale = 1
            }
            
            self.transformFilter.scale(factor: scale)
            self.updateCrop()
            
            dispatch_async(dispatch_get_main_queue(), {
                if self.timer != nil {
                    self.timer?.invalidate()
                }
                self.timer = NSTimer.scheduledTimerWithTimeInterval(0.03, target: self, selector: #selector(self.checkBoundsAfterScale), userInfo: nil, repeats: false)
            })
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
            
            guard let orientation = actualImage.metaData?[IMProcessing.meta.imageOrientationKey] else {
                return
            }
            
            let exifOrientation:Int = Int(orientation as! NSNumber)
            
            NSLog("image exif orientation = \(orientation) image.imageOrientation = \(actualImage.imageOrientation.rawValue)")
            
            let data = UIImageJPEGRepresentation(actualImage, 1.0)
            
            let path = workingFolder.filePathForKey(nil)
            
            data?.writeToFile(path, atomically: true)
            
            do{
                let image = try IMPJpegProvider(context: context, file: path, maxSize: 1500, orientation: IMPExifOrientation(rawValue: exifOrientation))
                imageView?.filter?.source = image
            }
            catch let error as NSError {
                NSLog("Load image: \(error))")
            }
            catch {
                NSLog("Load image error ... )")
            }
        }
    }
}

