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
    var tranformer: IMPRender!
    
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
        
        tranformer = IMPRender(context: context)
        
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
        
        pannelScrollView.snp_makeConstraints { (make) -> Void in
            make.width.equalTo(280)
            make.top.equalTo(pannelScrollView.superview!).offset(10)
            make.bottom.equalTo(pannelScrollView.superview!).offset(10)
            make.right.equalTo(pannelScrollView.superview!).offset(-10)
        }
        
        sview.snp_makeConstraints { (make) -> Void in
            make.edges.equalTo(pannelScrollView).inset(NSEdgeInsetsMake(10, 10, 10, 10))
        }
        
        configureControls()
    }
    
    private func configureControls() -> NSView {
        
        let horizontLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(horizontLabel)
        horizontLabel.stringValue = "Rotate"
        horizontLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(sview).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40

        rotationSlider = NSSlider(frame: view.bounds)
        rotationSlider.minValue = 0
        rotationSlider.maxValue = 100
        rotationSlider.integerValue = 50
        rotationSlider.action = #selector(ViewController.rotate(_:))
        rotationSlider.continuous = true
        sview.addSubview(rotationSlider)
        rotationSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(horizontLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40

        let verticalLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(verticalLabel)
        verticalLabel.stringValue = "Scale"
        verticalLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(rotationSlider.snp_bottom).offset(20)
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
        moveXSlider.action = #selector(ViewController.movex(_:))
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
        moveYSlider.action = #selector(ViewController.movey(_:))
        moveYSlider.continuous = true
        sview.addSubview(moveYSlider)
        moveYSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveYLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40
 
        //
        // Projection X
        //
        let projectionXLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(projectionXLabel)
        projectionXLabel.stringValue = "Projection X"
        projectionXLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(moveYSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        projectionXSlider = NSSlider(frame: view.bounds)
        projectionXSlider.minValue = 0
        projectionXSlider.maxValue = 100
        projectionXSlider.integerValue = 50
        projectionXSlider.action = #selector(ViewController.projectionx(_:))
        projectionXSlider.continuous = true
        sview.addSubview(projectionXSlider)
        projectionXSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(projectionXLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40

        //
        // Projection Y
        //
        let projectionYLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(projectionYLabel)
        projectionYLabel.stringValue = "Projection Y"
        projectionYLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(projectionXSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        projectionYSlider = NSSlider(frame: view.bounds)
        projectionYSlider.minValue = 0
        projectionYSlider.maxValue = 100
        projectionYSlider.integerValue = 50
        projectionYSlider.action = #selector(ViewController.projectiony(_:))
        projectionYSlider.continuous = true
        sview.addSubview(projectionYSlider)
        projectionYSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(projectionYLabel.snp_bottom).offset(5)
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
            make.top.equalTo(projectionYSlider.snp_bottom).offset(20)
            make.center.equalTo(sview).offset(0)
            make.width.equalTo(120)
            make.height.equalTo(20)
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
    
    var rotationSlider:NSSlider!
    var scaleSlider:NSSlider!
    var moveXSlider:NSSlider!
    var moveYSlider:NSSlider!
    var projectionXSlider:NSSlider!
    var projectionYSlider:NSSlider!
    
    func rotate(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.rotation(radians: (sender.floatValue-50)/100 * M_PI.float * 2)
            self.tranformer.dirty = true
        }
    }
    
    func scale(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.scale((sender.floatValue*2)/100)
            self.tranformer.dirty = true
        }
    }
    
    func movex(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.move(x:(sender.floatValue-50)/100,y:(self.moveYSlider.floatValue-50)/100)
            self.tranformer.dirty = true
        }
    }
    
    func movey(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.move(x:(self.moveXSlider.floatValue-50)/100,y:(sender.floatValue-50)/100)
            self.tranformer.dirty = true
        }
    }
   
    func projectionx(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.perspective(x: (sender.floatValue-50)/100 , y: (self.projectionYSlider.floatValue-50)/100)
            self.tranformer.dirty = true
        }
    }

    func projectiony(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.perspective(x: (self.projectionXSlider.floatValue-50)/100 , y: (sender.floatValue-50)/100 )
            self.tranformer.dirty = true
        }
    }

    func reset(sender:NSButton?){
        
        rotationSlider.intValue = 50
        rotate(rotationSlider)
        
        scaleSlider.intValue = 50
        scale(scaleSlider)
        
        moveXSlider.integerValue = 50
        movex(moveXSlider)

        moveYSlider.integerValue = 50
        movey(moveYSlider)
        
        projectionXSlider.integerValue = 50
        projectionx(projectionXSlider)

        projectionYSlider.integerValue = 50
        projectiony(projectionYSlider)
    }
    
    func disable(sender:NSButton){
        if filter?.enabled == true {
            filter?.enabled = false
        }
        else {
            filter?.enabled = true
        }
        filter.apply() 
    }
    
    override func viewDidLayout() {
        let h = view.bounds.height < allHeights ? allHeights : view.bounds.height
        sview.snp_remakeConstraints { (make) -> Void in
            make.top.equalTo(pannelScrollView).offset(0)
            make.left.equalTo(pannelScrollView).offset(0)
            make.right.equalTo(pannelScrollView).offset(0)
            make.height.equalTo(h)
        }
    }
}

