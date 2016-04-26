//
//  ViewController.swift
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Cocoa
import IMProcessing
import SnapKit

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

class ViewController: NSViewController {
    
    var context = IMPContext()
    var imageView:IMPImageView!
    
    //
    // Основной фильтр
    //
    var filter:IMPFilter!
    var tranformer: IMPPhotoPlate!
    
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
        
        tranformer = IMPPhotoPlate(context: context)
        
        filter.addFilter(tranformer)
        
        imageView = IMPImageView(context: context, frame: view.bounds)
        imageView.filter = filter
        imageView.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        
        filter.addDestinationObserver { (destination) -> Void in
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
 
      
        let reset = NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        reset.title = "Reset"
        reset.target = self
        reset.action = #selector(ViewController.reset(_:))
        sview.addSubview(reset)
        
        reset.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveYSlider.snp_bottom).offset(20)
            make.width.equalTo(120)
            make.left.equalTo(sview).offset(5)
        }
        allHeights += 20
        
        let disable =  NSButton(frame: NSRect(x: 230, y: 0, width: 50, height: view.bounds.height))
        
        let attrTitle = NSMutableAttributedString(string: "Enable")
        attrTitle.addAttribute(NSForegroundColorAttributeName, value: IMPColor.whiteColor(), range: NSMakeRange(0, attrTitle.length))
        
        disable.attributedTitle = attrTitle
        disable.setButtonType(.SwitchButton)
        disable.target = self
        disable.action = #selector(ViewController.disable(_:))
        disable.state = 1
        sview.addSubview(disable)
        
        disable.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(reset.snp_bottom).offset(10)
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
    
    func rotate(sender:NSSlider){
        asyncChanges { () -> Void in
            let anglex = (self.rotationXSlider.floatValue-50)/100 * M_PI.float / 4
            let angley = (self.rotationYSlider.floatValue-50)/100 * M_PI.float / 4
            let anglez = (self.rotationZSlider.floatValue-50)/100 * M_PI.float * 2
            let a = float3(anglex,angley,anglez)
            self.tranformer.rotate(a)
            self.tranformer.dirty = true
        }
    }
    
    func scale(sender:NSSlider){
        asyncChanges { () -> Void in
            let scale = (sender.floatValue*2)/100
            NSLog(" ### scale = \(scale)")
            self.tranformer.scale(float3(scale))
            self.tranformer.dirty = true
        }
    }
    
    func move(sender:NSSlider){
        asyncChanges { () -> Void in
            let transition = float2(x:(self.moveXSlider.floatValue-50)/100*4,y:(self.moveYSlider.floatValue-50)/100*4)
            self.tranformer.move(transition)
            self.tranformer.dirty = true
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

