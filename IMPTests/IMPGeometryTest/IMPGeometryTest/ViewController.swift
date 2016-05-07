//
//  ViewController.swift
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Cocoa
import IMProcessing
import SnapKit
import Quartz
import ApplicationServices

class IMPLabel: NSTextField {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        bezeled = false
        editable = false
        alignment = .Center
        textColor = IMPColor.lightGrayColor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

class ViewController: NSViewController {
    
    var context = IMPContext()
    var imageView:IMPImageView!
    
    //
    // Основной фильтр
    //
    var filter:IMPFilter!
    var transformer: IMPPhotoPlateFilter!
    var photoCutter: IMPPhotoPlateFilter!
    var cutter: IMPCropFilter!
    var warp: IMPWarpFilter!
    
    var mouse_point_offset = NSPoint()
    var mouse_point_before = NSPoint()
    var mouse_point = NSPoint() {
        didSet{
            mouse_point_before = oldValue
            mouse_point_offset = mouse_point_before - mouse_point
        }
    }
    
    var tuoched = false
    var warpDelta:Float = 0.005
    
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
    
    override func mouseDown(theEvent: NSEvent) {
        let event_location = theEvent.locationInWindow
        mouse_point = self.imageView.convertPoint(event_location,fromView:nil)
        mouse_point_before = mouse_point
        mouse_point_offset = NSPoint(x: 0,y: 0)
        tuoched = true

        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float

        if mouse_point.x > w/3 && mouse_point.x < w*2/3 && mouse_point.y < h/2 {
            pointerPlace = .Bottom
        }
        else if mouse_point.x < w/2 && mouse_point.y >= h/3 && mouse_point.y <= h*2/3 {
            pointerPlace = .Left
        }
        else if mouse_point.x < w/3 && mouse_point.y < h/3 {
            pointerPlace = .LeftBottom
        }
        else if mouse_point.x < w/3 && mouse_point.y > h*2/3 {
            pointerPlace = .LeftTop
        }
            
        else if mouse_point.x > w/3 && mouse_point.x < w*2/3 && mouse_point.y > h/2 {
            pointerPlace = .Top
        }
        else if mouse_point.x > w/2 && mouse_point.y >= h/3 && mouse_point.y <= h*2/3 {
            pointerPlace = .Right
        }
        else if mouse_point.x > w/3 && mouse_point.y < h/3 {
            pointerPlace = .RightBottom
        }
        else if mouse_point.x > w/3 && mouse_point.y > h*2/3 {
            pointerPlace = .RightTop
        }
    }
    
    override func mouseUp(theEvent: NSEvent) {
        tuoched = false
    }
    
    func pointerMoved(theEvent: NSEvent)  {
        if !tuoched {
            return
        }
        
        let event_location = theEvent.locationInWindow
        mouse_point = self.imageView.convertPoint(event_location,fromView:nil)
        
        let w = self.imageView.frame.size.width.float
        let h = self.imageView.frame.size.height.float
        
        let distancex = 1/w * mouse_point_offset.x.float
        let distancey = 1/h * mouse_point_offset.y.float
        
        if pointerPlace == .Left {
            warp.sourceQuad.left_bottom.x = warp.sourceQuad.left_bottom.x + distancex
            warp.sourceQuad.left_top.x = warp.sourceQuad.left_top.x + distancex
        }
        else if pointerPlace == .Bottom {
            warp.sourceQuad.left_bottom.y = warp.sourceQuad.left_bottom.y + distancey
            warp.sourceQuad.right_bottom.y = warp.sourceQuad.right_bottom.y + distancey
        }
        else if pointerPlace == .LeftBottom {
            warp.sourceQuad.left_bottom.x = warp.sourceQuad.left_bottom.x + distancex
            warp.sourceQuad.left_bottom.y = warp.sourceQuad.left_bottom.y + distancey
        }
        else if pointerPlace == .LeftTop {
            warp.sourceQuad.left_top.x = warp.sourceQuad.left_top.x + distancex
            warp.sourceQuad.left_top.y = warp.sourceQuad.left_top.y + distancey
        }
            
        else if pointerPlace == .Right {
            warp.sourceQuad.right_bottom.x = warp.sourceQuad.right_bottom.x + distancex
            warp.sourceQuad.right_top.x = warp.sourceQuad.right_top.x + distancex
        }
        else if pointerPlace == .Top {
            warp.sourceQuad.left_top.y = warp.sourceQuad.left_top.y + distancey
            warp.sourceQuad.right_top.y = warp.sourceQuad.right_top.y + distancey
        }
        else if pointerPlace == .RightBottom {
            warp.sourceQuad.right_bottom.x = warp.sourceQuad.right_bottom.x + distancex
            warp.sourceQuad.right_bottom.y = warp.sourceQuad.right_bottom.y + distancey
        }
        else if pointerPlace == .RightTop {
            warp.sourceQuad.right_top.x = warp.sourceQuad.right_top.x + distancex
            warp.sourceQuad.right_top.y = warp.sourceQuad.right_top.y + distancey
        }
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        pointerMoved(theEvent)
    }
    
    override func touchesMovedWithEvent(theEvent: NSEvent) {
        pointerMoved(theEvent)        
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if !IMPContext.supportsSystemDevice {
            
            self.asyncChanges({ () -> Void in
                let alert = NSAlert(error: NSError(domain: "com.imagemetalling.08", code: 0, userInfo: [
                    NSLocalizedFailureReasonErrorKey:"MTL initialization error",
                    NSLocalizedDescriptionKey:"The system does not support MTL..."
                    ]))
                alert.runModal()
            })
            return
        }
        
        configurePannel()
        
        filter = IMPFilter(context: context)
        
        transformer = IMPPhotoPlateFilter(context: context)
        photoCutter = IMPPhotoPlateFilter(context: context)
        cutter = IMPCropFilter(context: context)
        warp = IMPWarpFilter(context: context)
        
        filter.addFilter(transformer)
        
        filter.addFilter(warp)        

        filter.addFilter(photoCutter)        
        filter.addFilter(cutter)
        
        imageView = IMPImageView(context: context, frame: view.bounds)
        imageView.filter = filter
        imageView.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        
        transformer.addMatrixModelObserver { (destination, model, aspect) in
            
            let plate = IMPPlate(aspect: aspect)
            
            var offset = (1-plate.scaleFactorFor(model: model))/2

            offset = offset > 0.49 ? 0.49 : offset
            
            let region = IMPRegion(left: offset, right: offset, top: offset, bottom: offset)
            
            //self.cutter.region = region
        }
                
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(imageView.superview!).offset(10)
            make.bottom.equalTo(imageView.superview!).offset(0)
            make.left.equalTo(imageView.superview!).offset(10)
            make.right.equalTo(pannelScrollView.snp_left).offset(0)
        }
        
        IMPDocument.sharedInstance.addDocumentObserver { (file, type) -> Void in
            if type == .Image {
                do{
                    //
                    // Загружаем файл и связываем источником фильтра
                    //
                    
                    self.imageView.filter?.source = try IMPImageProvider(context: self.context, file: file)
                    
                    
                    self.asyncChanges({ () -> Void in
                        self.zoomFit()
                    })
                }
                catch let error as NSError {
                    self.asyncChanges({ () -> Void in
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    })
                }
            }
        }
        
        IMPMenuHandler.sharedInstance.addMenuObserver { (item) -> Void in
            if let tag = IMPMenuTag(rawValue: item.tag) {
                switch tag {
                case .zoomFit:
                    self.zoomFit()
                case .zoom100:
                    self.zoom100()
                }
            }
        }
        
        reset(nil)
    }
    
    //
    // Вся остальная часть относится к визуальному представления данных
    //
    
    private func zoomFit(){
        asyncChanges { () -> Void in
            self.imageView.sizeFit()
        }
    }
    
    private func zoom100(){
        asyncChanges { () -> Void in
            self.imageView.sizeOriginal()
        }
    }
    
    override func viewDidAppear() {
        if IMPContext.supportsSystemDevice {
            super.viewDidAppear()
            asyncChanges { () -> Void in
                self.imageView.sizeFit()
            }
        }
    }
    
    var q = dispatch_queue_create("ViewController", DISPATCH_QUEUE_CONCURRENT)
    
    private func asyncChanges(block:()->Void) {
        dispatch_async(q, { () -> Void in
            //
            // немного того, но... :)
            //
            dispatch_after(0, dispatch_get_main_queue()) { () -> Void in
                block()
            }
        })
    }
    
    
    var pannelScrollView = NSScrollView()
    var sview:NSView!
    var allHeights = CGFloat(0)
    
    private func configurePannel(){
        
        pannelScrollView.wantsLayer = true
        view.addSubview(pannelScrollView)
        
        pannelScrollView.drawsBackground = false
        pannelScrollView.allowsMagnification = false
        pannelScrollView.contentView.wantsLayer = true
        
        sview = NSView(frame: pannelScrollView.bounds)
        sview.wantsLayer = true
        sview.layer?.backgroundColor = IMPColor.clearColor().CGColor
        pannelScrollView.documentView = sview
        
        configureControls()
        
        pannelScrollView.snp_makeConstraints { (make) -> Void in
            make.width.equalTo(280)
            make.top.equalTo(pannelScrollView.superview!).offset(10)
            make.bottom.equalTo(pannelScrollView.superview!).offset(10)
            make.right.equalTo(pannelScrollView.superview!).offset(-10)
        }
        
        sview.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(sview.superview!).offset(0)
            make.left.equalTo(sview.superview!).offset(0)
            make.right.equalTo(sview.superview!).offset(0)
            containerWidthConstraint = make.height.equalTo(currentHeigh).constraint
        }
    }
    
    private func configureControls() -> NSView {
        
        
        let rotationXLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(rotationXLabel)
        rotationXLabel.stringValue = "Rotate X"
        rotationXLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(sview).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        rotationXSlider = NSSlider(frame: view.bounds)
        rotationXSlider.minValue = 0
        rotationXSlider.maxValue = 100
        rotationXSlider.integerValue = 50
        rotationXSlider.action = #selector(ViewController.rotate(_:))
        rotationXSlider.continuous = true
        sview.addSubview(rotationXSlider)
        rotationXSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationXLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        let rotationYLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(rotationYLabel)
        rotationYLabel.stringValue = "Rotate Y"
        rotationYLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationXSlider.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        rotationYSlider = NSSlider(frame: view.bounds)
        rotationYSlider.minValue = 0
        rotationYSlider.maxValue = 100
        rotationYSlider.integerValue = 50
        rotationYSlider.action = #selector(ViewController.rotate(_:))
        rotationYSlider.continuous = true
        sview.addSubview(rotationYSlider)
        rotationYSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationYLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        let rotationZLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(rotationZLabel)
        rotationZLabel.stringValue = "Rotate Z"
        rotationZLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationYSlider.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        rotationZSlider = NSSlider(frame: view.bounds)
        rotationZSlider.minValue = 0
        rotationZSlider.maxValue = 100
        rotationZSlider.integerValue = 50
        rotationZSlider.action = #selector(ViewController.rotate(_:))
        rotationZSlider.continuous = true
        sview.addSubview(rotationZSlider)
        rotationZSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationZLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        //
        // Scale
        //
        let verticalLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(verticalLabel)
        verticalLabel.stringValue = "Scale"
        verticalLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationZSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        scaleSlider = NSSlider(frame: view.bounds)
        scaleSlider.minValue = 0
        scaleSlider.maxValue = 100
        scaleSlider.integerValue = 100
        scaleSlider.action = #selector(ViewController.scale(_:))
        scaleSlider.continuous = true
        sview.addSubview(scaleSlider)
        scaleSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(verticalLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        
        //
        // MOVE X
        //
        let moveXLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(moveXLabel)
        moveXLabel.stringValue = "Move X"
        moveXLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(scaleSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        moveXSlider = NSSlider(frame: view.bounds)
        moveXSlider.minValue = 0
        moveXSlider.maxValue = 100
        moveXSlider.integerValue = 50
        moveXSlider.action = #selector(ViewController.move(_:))
        moveXSlider.continuous = true
        sview.addSubview(moveXSlider)
        moveXSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveXLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        //
        // MOVE Y
        //
        let moveYLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(moveYLabel)
        moveYLabel.stringValue = "Move Y"
        moveYLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveXSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        moveYSlider = NSSlider(frame: view.bounds)
        moveYSlider.minValue = 0
        moveYSlider.maxValue = 100
        moveYSlider.integerValue = 50
        moveYSlider.action = #selector(ViewController.move(_:))
        moveYSlider.continuous = true
        sview.addSubview(moveYSlider)
        moveYSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveYLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        //
        // CROP
        //
        let cropLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(cropLabel)
        cropLabel.stringValue = "Crop"
        cropLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveYSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        cropSlider = NSSlider(frame: view.bounds)
        cropSlider.minValue = 0
        cropSlider.maxValue = 100
        cropSlider.integerValue = 0
        cropSlider.action = #selector(ViewController.crop(_:))
        cropSlider.continuous = true
        sview.addSubview(cropSlider)
        cropSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(cropLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
        
        
        let reset = NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        reset.title = "Reset"
        reset.target = self
        reset.action = #selector(ViewController.reset(_:))
        sview.addSubview(reset)
        
        reset.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(cropSlider.snp_bottom).offset(20)
            make.width.equalTo(120)
            make.left.equalTo(sview).offset(5)
        }
        allHeights += 20

        let flipHorizontal =  NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        
        var attrTitle = NSMutableAttributedString(string: "Flip Horizontal")
        attrTitle.addAttribute(NSForegroundColorAttributeName, value: IMPColor.whiteColor(), range: NSMakeRange(0, attrTitle.length))
        
        flipHorizontal.attributedTitle = attrTitle
        flipHorizontal.setButtonType(.SwitchButton)
        flipHorizontal.target = self
        flipHorizontal.action = #selector(ViewController.flipHorizontalHandler(_:))
        flipHorizontal.state = 0
        sview.addSubview(flipHorizontal)
        
        flipHorizontal.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(reset.snp_bottom).offset(10)
            make.left.equalTo(sview).offset(10)
            make.width.equalTo(120)
            make.height.equalTo(20)
        }
        allHeights += 20
        
        let flipVertical =  NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))

        attrTitle = NSMutableAttributedString(string: "Flip Vertical")
        attrTitle.addAttribute(NSForegroundColorAttributeName, value: IMPColor.whiteColor(), range: NSMakeRange(0, attrTitle.length))
        
        flipVertical.attributedTitle = attrTitle
        flipVertical.setButtonType(.SwitchButton)
        flipVertical.target = self
        flipVertical.action = #selector(ViewController.flipVerticalHandler(_:))
        flipVertical.state = 0
        sview.addSubview(flipVertical)
        
        flipVertical.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(flipHorizontal.snp_bottom).offset(10)
            make.left.equalTo(sview).offset(10)
            make.width.equalTo(120)
            make.height.equalTo(20)
        }
        allHeights += 20

        let left90 =  NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        
        attrTitle = NSMutableAttributedString(string: "Left")
        attrTitle.addAttribute(NSForegroundColorAttributeName, value: IMPColor.whiteColor(), range: NSMakeRange(0, attrTitle.length))
        
        left90.attributedTitle = attrTitle
        left90.setButtonType(.SwitchButton)
        left90.target = self
        left90.action = #selector(ViewController.left(_:))
        left90.state = 0
        sview.addSubview(left90)
        
        left90.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(flipVertical.snp_bottom).offset(10)
            make.left.equalTo(sview).offset(10)
            make.width.equalTo(120)
            make.height.equalTo(20)
        }
        allHeights += 20

        let disable =  NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        
        attrTitle = NSMutableAttributedString(string: "Enable")
        attrTitle.addAttribute(NSForegroundColorAttributeName, value: IMPColor.whiteColor(), range: NSMakeRange(0, attrTitle.length))
        
        disable.attributedTitle = attrTitle
        disable.setButtonType(.SwitchButton)
        disable.target = self
        disable.action = #selector(ViewController.disable(_:))
        disable.state = 1
        sview.addSubview(disable)
        
        disable.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(left90.snp_bottom).offset(10)
            make.left.equalTo(sview).offset(10)
            make.width.equalTo(120)
            make.height.equalTo(20)
        }
        allHeights += 20
        
        return disable
    }
    
    var rotationXSlider:NSSlider!
    var rotationYSlider:NSSlider!
    var rotationZSlider:NSSlider!
    var scaleSlider:NSSlider!
    var moveXSlider:NSSlider!
    var moveYSlider:NSSlider!
    var cropSlider:NSSlider!
    
    func rotate(sender:NSSlider){
        asyncChanges { () -> Void in
            let anglex = (self.rotationXSlider.floatValue-50)/100 * M_PI.float
            let angley = (self.rotationYSlider.floatValue-50)/100 * M_PI.float
            let anglez = (self.rotationZSlider.floatValue-50)/100 * M_PI.float
            let a = float3(anglex,angley,anglez)
            self.transformer.rotate(a)
        }
    }
    
    func scale(sender:NSSlider){
        asyncChanges { () -> Void in
            let scale = (sender.floatValue*2)/100
            self.transformer.scale(float3(scale))
            self.transformer.dirty = true
        }
    }
    
    func move(sender:NSSlider){
        asyncChanges { () -> Void in
            let transition = float2(x:(self.moveXSlider.floatValue-50)/100*4,y:(self.moveYSlider.floatValue-50)/100*4)
            self.transformer.move(transition)
        }
    }
    
    func crop(sender:NSSlider){
        asyncChanges { () -> Void in
            let crop = sender.floatValue/300
            let region = IMPRegion(left: crop, right: crop, top: crop, bottom: crop)
            //
            // самый быстрый вариант
            //
            self.cutter.region = region
            
            //
            // устанавливает кроп на все дейтсвие, т.е. прикладывает к странсфорации
            //
            //self.transformer.crop(region)
            
            //
            // тоже самое что и self.cutter.region = region
            // поскольку следующий в стеке фильтров, но медленнее
            //
            //self.photoCutter.crop(region)
        }
    }
    
    func reset(sender:NSButton?){
        
        rotationXSlider.intValue = 50
        rotationYSlider.intValue = 50
        rotationZSlider.intValue = 50
        rotate(rotationXSlider)
        
        scaleSlider.intValue = 50
        scale(scaleSlider)
        
        moveXSlider.integerValue = 50
        moveYSlider.integerValue = 50
        move(moveXSlider)
        
        cropSlider.integerValue = 0
        crop(cropSlider)
        
        warp.sourceQuad = IMPQuad()
        warp.destinationQuad = IMPQuad()
    }
    
    func  flipHorizontalHandler(sender:NSButton) {
        transformer.reflection = (horizontal:sender.state == 1 ? .Mirroring : .None, vertical: transformer.reflection.vertical)
    }

    func  flipVerticalHandler(sender:NSButton) {
        transformer.reflection = (vertical:sender.state == 1 ? .Mirroring : .None, horizontal: transformer.reflection.horizontal)
    }

    
    func  left(sender:NSButton) {
        asyncChanges { () -> Void in
            self.transformer.rotate(sender.state == 1 ? IMPMatrixModel.left : IMPMatrixModel.flat)
        }
    }

    func disable(sender:NSButton){
        if filter?.enabled == true {
            filter?.enabled = false
        }
        else {
            filter?.enabled = true
        }
        filter.dirty = true
    }
    
    var containerWidthConstraint:Constraint?
    var currentHeigh : CGFloat {
        get{
            return allHeights < view.bounds.height ? view.bounds.height: allHeights + 20
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        containerWidthConstraint?.updateOffset(currentHeigh)
    }
}

