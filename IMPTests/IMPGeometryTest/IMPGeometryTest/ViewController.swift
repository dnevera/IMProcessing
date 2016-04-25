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
        horizontLabel.stringValue = "Horizont"
        horizontLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(sview).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40

        horizontSlider = NSSlider(frame: view.bounds)
        horizontSlider.minValue = 0
        horizontSlider.maxValue = 100
        horizontSlider.integerValue = 50
        horizontSlider.action = #selector(ViewController.changeHorizont(_:))
        horizontSlider.continuous = true
        sview.addSubview(horizontSlider)
        horizontSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(horizontLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40

        let verticalLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(verticalLabel)
        verticalLabel.stringValue = "Vertical"
        verticalLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(horizontSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        verticalSlider = NSSlider(frame: view.bounds)
        verticalSlider.minValue = 0
        verticalSlider.maxValue = 100
        verticalSlider.integerValue = 50
        verticalSlider.action = #selector(ViewController.changeVertical(_:))
        verticalSlider.continuous = true
        sview.addSubview(verticalSlider)
        verticalSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(verticalLabel.snp_bottom).offset(5)
            make.right.equalTo(sview).offset(5)
            make.left.equalTo(sview).offset(5)
        }
        allHeights+=40

        let aspectRatioLabel  = IMPLabel(frame: view.bounds)
        sview.addSubview(aspectRatioLabel)
        aspectRatioLabel.stringValue = "Aspect Ratio"
        aspectRatioLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(verticalSlider.snp_bottom).offset(20)
            make.right.equalTo(sview).offset(-20)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        allHeights+=40
        
        aspectRatioSlider = NSSlider(frame: view.bounds)
        aspectRatioSlider.minValue = 0
        aspectRatioSlider.maxValue = 100
        aspectRatioSlider.integerValue = 50
        aspectRatioSlider.action = #selector(ViewController.changeVertical(_:))
        aspectRatioSlider.continuous = true
        sview.addSubview(aspectRatioSlider)
        aspectRatioSlider.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(aspectRatioLabel.snp_bottom).offset(5)
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
            make.top.equalTo(aspectRatioSlider.snp_bottom).offset(20)
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
    
    var horizontSlider:NSSlider!
    var verticalSlider:NSSlider!
    var aspectRatioSlider:NSSlider!
    
    func changeHorizont(sender:NSSlider){
        asyncChanges { () -> Void in
            self.tranformer.transform.rotation(radians: (sender.floatValue-50)/100 * M_PI.float * 2)
            self.tranformer.dirty = true
        }
    }
    
    func changeVertical(sender:NSSlider){
        asyncChanges { () -> Void in
        }
    }
    
    func changeAspectRatio(sender:NSSlider){
        asyncChanges { () -> Void in
        }
    }
    
    func reset(sender:NSButton?){
        horizontSlider.intValue = 50
        verticalSlider.intValue = 50
        aspectRatioSlider.integerValue = 50
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

