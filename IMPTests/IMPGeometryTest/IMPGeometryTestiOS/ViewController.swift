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
//import GLKit

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
    
    var imageView:IMPImageView!
    
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

    let slider = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blackColor()
        
        transformFilter.addMatrixModelObserver { (destination, model, aspect) in
            //var offset = (1-IMPPlate().scaleFactorFor(model: model))
            //offset = offset > 0.49 ? 0.49 : offset
            //self.cropFilter.region = IMPRegion(left: offset, right: offset, top: offset, bottom: offset)
        }
        
        filter.addFilter(transformFilter)
        filter.addFilter(warpFilter)
        filter.addFilter(cropFilter)
        
        //transformFilter.scale(factor: 0.5)
        
        imageView = IMPImageView(context: (filter.context)!,  frame: CGRectMake( 0, 20,
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
        enableButton.on = true
        enableButton.backgroundColor = IMPColor.clearColor()
        enableButton.tintColor = IMPColor.whiteColor()
        enableButton.addTarget(self, action: #selector(self.disable(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(enableButton)
        
        enableButton.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.snp_bottom).offset(10)
            make.right.equalTo(view).offset(-40)
        }

        slider.value = 0.5
        slider.addTarget(self, action: #selector(ViewController.rotate(_:)), forControlEvents: .ValueChanged)
        view.addSubview(slider)
        
        slider.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-40)
            make.left.equalTo(albumButton.snp_right).offset(20)
            make.right.equalTo(view).offset(-20)
        }
        
        IMPMotionManager.sharedInstance.addRotationObserver { (orientation) in
            self.imageView.setOrientation(orientation, animate: true)
        }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panHandler(_:)))
        imageView.addGestureRecognizer(pan)
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
            panning(gesture)
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
    }
    
    func panning(gesture:UIPanGestureRecognizer)  {
        if !tuoched {
            return
        }
        
        finger_point = convertOrientation(gesture.locationInView(imageView))

        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float
        
        let distancex = 1/w * finger_point_offset.x.float
        let distancey = -1/h * finger_point_offset.y.float
        
        if pointerPlace == .Left {
            warpFilter.sourceQuad.left_bottom.x = warpFilter.sourceQuad.left_bottom.x + distancex
            warpFilter.sourceQuad.left_top.x = warpFilter.sourceQuad.left_top.x + distancex
        }
        else if pointerPlace == .Bottom {
            warpFilter.sourceQuad.left_bottom.y = warpFilter.sourceQuad.left_bottom.y + distancey
            warpFilter.sourceQuad.right_bottom.y = warpFilter.sourceQuad.right_bottom.y + distancey
        }
        else if pointerPlace == .LeftBottom {
            warpFilter.sourceQuad.left_bottom.x = warpFilter.sourceQuad.left_bottom.x + distancex
            warpFilter.sourceQuad.left_bottom.y = warpFilter.sourceQuad.left_bottom.y + distancey
        }
        else if pointerPlace == .LeftTop {
            warpFilter.sourceQuad.left_top.x = warpFilter.sourceQuad.left_top.x + distancex
            warpFilter.sourceQuad.left_top.y = warpFilter.sourceQuad.left_top.y + distancey
        }
            
        else if pointerPlace == .Right {
            warpFilter.sourceQuad.right_bottom.x = warpFilter.sourceQuad.right_bottom.x + distancex
            warpFilter.sourceQuad.right_top.x = warpFilter.sourceQuad.right_top.x + distancex
        }
        else if pointerPlace == .Top {
            warpFilter.sourceQuad.left_top.y = warpFilter.sourceQuad.left_top.y + distancey
            warpFilter.sourceQuad.right_top.y = warpFilter.sourceQuad.right_top.y + distancey
        }
        else if pointerPlace == .RightBottom {
            warpFilter.sourceQuad.right_bottom.x = warpFilter.sourceQuad.right_bottom.x + distancex
            warpFilter.sourceQuad.right_bottom.y = warpFilter.sourceQuad.right_bottom.y + distancey
        }
        else if pointerPlace == .RightTop {
            warpFilter.sourceQuad.right_top.x = warpFilter.sourceQuad.right_top.x + distancex
            warpFilter.sourceQuad.right_top.y = warpFilter.sourceQuad.right_top.y + distancey
        }
        
    }

    func reset(sender:UIButton){
        
        slider.value = 0.5
        rotate(slider)
        warpFilter.sourceQuad = IMPQuad()
        warpFilter.destinationQuad = IMPQuad()
    }

    func disable(sender:UISwitch){
        filter.enabled = sender.on
    }

    func rotate(sender:UISlider){
        dispatch_async(context.dispatchQueue) { () -> Void in
            self.transformFilter.rotate(IMPMatrixModel.right * (sender.value - 0.5) * 2)
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
}

