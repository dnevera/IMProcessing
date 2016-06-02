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


extension NSSize {
    var Float2:float2 {
        return float2(self.width.float,self.height.float)
    }
}

extension NSPoint {
    var Float2:float2 {
        return float2(self.x.float,self.y.float)
    }
}

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

public class MPPhotoPlateEditor: IMPPhotoPlateFilter, UIDynamicItem{
    
    public var cropBounds:IMPRegion? = nil
    
    public var viewPort:CGRect? = nil
    
    public var center:CGPoint = CGPoint(x: 0,y: 0) {
        didSet{
            if let size = viewPort?.size {
                translation = float2(center.x.float,center.y.float) / (float2(size.width.float,size.height.float)/2)
            }
        }
    }
    
    public var bounds:CGRect {
        get {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }
    
    public var transform = CGAffineTransform()
    //
    //  Ignor, or use the follow conversions :
    //
    //    {
    //        get{
    //            let m = model.transform
    //            let c0 = m.columns.0
    //            let c1 = m.columns.1
    //            let tc = model.translation.columns.3
    //            return CGAffineTransform(a:  c0.x.cgfloat, b:  c0.y.cgfloat,
    //                                     c:  c1.x.cgfloat, d:  c1.y.cgfloat,
    //                                     tx: tc.x.cgfloat, ty: tc.y.cgfloat)
    //        }
    //        set {
    //            //
    //            // Acording to UIDynamicItem man transform operates only rotation
    //            //
    //            angle.z = acos(newValue.a).float 
    //        }
    //    }
    
    public var outOfBounds:float2 {
        get {
            
            guard let crop=self.cropBounds else { return float2(0) }
            
            let aspect   = self.aspect
            let model    = self.model
            
            //
            // Model of Cropped Quad
            //
            let cropQuad = IMPQuad(region:crop, aspect: aspect)
            
            //
            // Model of transformed Quad
            // Transformation matrix of the model can be the same which transformation filter has or it can be computed independently
            //
            let transformedQuad = IMPPlate(aspect: aspect).quad(model: model)
            
            //
            // Offset for transformed quad which should contain inscribed croped quad
            //
            // NOTE:
            // 1. quads should be rectangle
            // 2. scale of transformed quad should be great then or equal scaleFactorFor for the transformed model:
            //    IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: model)
            //
            return transformedQuad.translation(quad: cropQuad)
        }
    }
    
    public var anchor:CGPoint? {
        get {
            guard let size = viewPort?.size else { return nil }
            
            var offset = -outOfBounds
            
            if abs(offset.x) > 0 || abs(offset.y) > 0 {
                
                offset = (self.translation+offset) * size.Float2/2
                
                return CGPoint(x: offset.x.cgfloat, y: offset.y.cgfloat)
            }
            
            return nil
        }
    }
}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    var context = IMPContext()
    
    var imageView:IMPView!
    
    lazy var filter:IMPFilter = {
        return IMPFilter(context:self.context)
    }()
    
    lazy var transformFilter:MPPhotoPlateEditor = {
        let f = MPPhotoPlateEditor(context:self.context)
        f.addDestinationObserver(destination: { (destination) in
            f.viewPort = self.imageView.layer.bounds
        })
        return f
    }()
    
    lazy var cropFilter: IMPCropFilter = {
        let f = IMPCropFilter(context:self.context)
        f.addDestinationObserver(destination: { (destination) in
            self.transformFilter.cropBounds = f.region
        })
        return f
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
    
    var outOfBounds:float2 {
        get {
            let aspect   = transformFilter.aspect
            let model    = transformFilter.model
            
            //
            // Model of Cropped Quad
            //
            let cropQuad = IMPQuad(region:cropFilter.region, aspect: aspect)
            
            //
            // Model of transformed Quad
            // Transformation matrix of the model can be the same which transformation filter has or it can be computed independently
            //
            let transformedQuad = IMPPlate(aspect: aspect).quad(model: model)
            
            //
            // Offset for transformed quad which should contain inscribed croped quad
            //
            // NOTE:
            // 1. quads should be rectangle
            // 2. scale of transformed quad should be great then or equal scaleFactorFor for the transformed model:
            //    IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: model)
            //
            return transformedQuad.translation(quad: cropQuad)
        }
    }
    
    ///  Check bounds of inscribed Rectangular
    func checkBounds(duration:NSTimeInterval) {
        animateTranslation(-outOfBounds, duration: duration)
    }

    //
    // Display link timer 
    //
    var currentTranslationTimer:IMPDisplayTimer? {
        willSet {
            if let t = currentTranslationTimer {
                t.invalidate()
            }
        }
    }
    
    let animateDuration:NSTimeInterval = 0.2
    
    func animateTranslation(offset:float2, duration:NSTimeInterval)  {
        
        let start = transformFilter.translation
        let final = start + offset
        
        currentTranslationTimer = IMPDisplayTimer.execute(
            duration: duration,
            options: .EaseIn,
            update: { (atTime) in
                self.transformFilter.translation = start.lerp(final: final, t: atTime.float)
            })
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
      
        let flipButton = UIButton(type: .System)
        
        flipButton.setTitle("Flip", forState: .Normal)
        flipButton.backgroundColor = IMPColor.clearColor()
        flipButton.tintColor = IMPColor.whiteColor()
        flipButton.addTarget(self, action: #selector(self.flip(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(flipButton)
        
        flipButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.snp_bottom).offset(10)
            make.left.equalTo(view).offset(100)
        }

        let leftButton = UIButton(type: .System)
        
        leftButton.setTitle("Left", forState: .Normal)
        leftButton.backgroundColor = IMPColor.clearColor()
        leftButton.tintColor = IMPColor.whiteColor()
        leftButton.addTarget(self, action: #selector(self.rotateFixed(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(leftButton)
        
        leftButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.snp_bottom).offset(10)
            make.left.equalTo(view).offset(140)
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
        
        
        scaleSlider.value = 0
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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        tap.numberOfTapsRequired = 1
        tap.numberOfTouchesRequired = 1
        imageView.addGestureRecognizer(tap)
        
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
    
    func tapHandler(gesture:UIPanGestureRecognizer)  {
        if gesture.state == .Began {
           animator.removeAllBehaviors()
        }
    }
    
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
            tapUp(gesture)
        }
        else if gesture.state == .Cancelled {
            tapUp(gesture)
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
        
        animator.removeAllBehaviors()

        if tuoched {
            return
        }

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
    
    var deceleration:UIDynamicItemBehavior?
    var spring:UIAttachmentBehavior?
    
    func checkTranslationBounds(){
        
        guard let anchor = transformFilter.anchor else { return }
        
        let spring = UIAttachmentBehavior(item: transformFilter, attachedToAnchor: anchor)
        
        spring.length    = 0
        spring.damping   = 1
        spring.frequency = 2
        
        animator.addBehavior(spring)
        self.spring = spring
    }

    func decelerateToBonds(gesture:UIPanGestureRecognizer? = nil) {
        var velocity = CGPoint()
        
        if let g = gesture {
            velocity = g.velocityInView(imageView)
            velocity = CGPoint(x: velocity.x,y: -velocity.y)
        }
        
        let decelerate = UIDynamicItemBehavior(items: [transformFilter])
        decelerate.addLinearVelocity(velocity, forItem: transformFilter)
        decelerate.resistance = 3
        
        decelerate.action = {
            self.checkTranslationBounds()
        }
        self.animator.addBehavior(decelerate)
        self.deceleration = decelerate
    }
    
    func tapUp(gesture:UIPanGestureRecognizer) {
        tuoched = false
        decelerateToBonds(gesture)
    }
    
    lazy var animator:UIDynamicAnimator = UIDynamicAnimator(referenceView: self.imageView)
    
    func panningDistance() -> float2 {
        
        if currentTranslationTimer != nil {
            currentTranslationTimer = nil
        }
        
        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float
        
        let x = 1/w * finger_point_offset.x.float
        let y = -1/h * finger_point_offset.y.float
        
        //let f = 1/IMPPlate(aspect: transformFilter.aspect).scaleFactorFor(model: transformFilter.model)
        
        return float2(x,y) * transformFilter.scale.x
    }
    
    var lastDistance = float2(0)
    
    func translateImage(gesture:UIPanGestureRecognizer)  {
        
        if !tuoched {
            return
        }
        
        finger_point = convertOrientation(gesture.locationInView(imageView))
        
        lastDistance  = panningDistance()
        
        transformFilter.translation -= lastDistance * (float2(1)-abs(outOfBounds))
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
            animator.removeAllBehaviors()
           // filter.enabled = false
        }
        else if gesture.state == .Ended {
           // filter.enabled = true
        }
    }
    
    func flip(sender:UIButton){
        self.filter.source?.reflectHorizontal()
    }

    func rotateFixed(sender:UIButton){
        self.filter.source?.rotateLeft()
    }

    func reset(sender:UIButton){
        
        slider.value = 0.5
        rotate(slider)
        
        scaleSlider.value = 0
        scale(scaleSlider)
        
        transformFilter.translation = float2(0)
        
        warpFilter.sourceQuad = IMPQuad()
        warpFilter.destinationQuad = IMPQuad()
    }
    
    var enableWarpFilter = false
    
    func toggleWarpFilter(sender:UISwitch){
        enableWarpFilter = sender.on
    }
        
    func checkBoundsAfterTransformation()  {
        animator.removeAllBehaviors()
        decelerateToBonds()
        checkTranslationBounds()
    }
    
    func rotate(sender:UISlider){
        transformFilter.angle = IMPMatrixModel.right * (sender.value - 0.5)
        updateCrop()
        checkBoundsAfterTransformation()
    }
    
    func scale(sender:UISlider){            
        var scale = (sender.value * 4 + 1)
        
        if scale < 1 {
            //
            // scale can't be less then 1 while we try to crop
            //
            scale = 1
        }
        
        transformFilter.scale(factor: scale)
        checkBoundsAfterTransformation()
    }

    var aflag = true
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if aflag {
            imagePicker = UIImagePickerController()
            aflag = false
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
                let image = try IMPJpegProvider(context: context, file: path, maxSize: 1000, orientation: IMPExifOrientation(rawValue: exifOrientation))
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

