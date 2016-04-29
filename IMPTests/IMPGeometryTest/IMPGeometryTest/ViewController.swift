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
    var transformer: IMPPhotoPlateFilter!
    var photoCutter: IMPPhotoPlateFilter!
    var cutter: IMPCropFilter!
    
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
        
        filter.addFilter(transformer)
        filter.addFilter(photoCutter)
        filter.addFilter(cutter)
        
        imageView = IMPImageView(context: context, frame: view.bounds)
        imageView.filter = filter
        imageView.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        
        
        transformer.addMatrixModelObserver { (destination, model, a) in
            let t = model.transformMatrix.toFloat4x4()
            let p = model.projectionMatrix.toFloat4x4()
            let m = model.transitionMatrix.toFloat4x4()
            
            let izometric = float4x4(rows:
                [
                    float4(1,0,0,0),
                    float4(0,1,0,0),
                    float4(0,0,0,0),
                    float4(0,0,1/a,1),
                ]
            )
            
            let result =  izometric * (p * t * float4(-a,-1,1,1) )
            //let result =  (p * t * float4(-a,-1,1,1) ) * izometric
            //let result =  izometric * ( (float4(-1,-1,1,1) * p) * t )
            let w      = 1+result.w
            let xy     = float4(result.x/w,result.y/w,0,1)
            
            print(" result = \(result)\n  left-bottom = \(xy)")
        }
        
//        transformer.addMatrixModelObserver { (destination, model, aa) in
//            let t = model.transformMatrix.toIMPMatrix()
//            let p = model.projectionMatrix.toIMPMatrix()
//            let m = model.transitionMatrix.toIMPMatrix()
//            
//            let a:Float = 1
//            
////            let grid:[Float] = [
////                0,0,0,1,
////                0,0,1,1,
////                0,1,0,1,
////                0,1,1,1,
////                a,0,0,1,
////                a,0,1,1,
////                a,1,0,1,
////                a,1,1,1,
////            ]
//            
////            let grid:[Float] = [
////                -a, -1,  0, 1,
////                -a, -1,  0, 1,
////                -a,  1,  0, 1,
////                -a,  1,  0, 1,
////                 a, -1,  0, 1,
////                 a, -1,  0, 1,
////                 a,  1,  0, 1,
////                 a,  1,  0, 1,
////            ]
//            
//            let grid:[Float] = [
//                -a, 1, 0, 1,
//                -a,-1, 0, 1,
//                 a,-1, 0, 1,
//                 a, 1, 0, 1,
//                -a, 1, 0, 1,
//                 a, 1, 0, 1,
//                 a,-1, 0, 1,
//                -a,-1, 0, 1,
//            ]
//
//            let cube  = (IMPMatrix(rows: 8, columns: 4, grid: grid) * t) * m
//            
//            let Pz = IMPMatrix(rows: 4, columns: 4, grid: [Float]([
//                1, 0, 0, 0,
//                0, 1, 0, 0,
//                0, 0, 0, 0,
//                0, 0, 1, 1
//                ]))
//            
//            let xyz = IMPMatrix(rows: 4, columns: 1, grid: [Float]([cube[0,0],cube[0,1],cube[0,2],1]))
//            
//            let f =  Pz * xyz
//            let pp = 1/(1+f[3,0]) * 2
//            let pr = IMPMatrix(rows: 1, columns: 4, grid: [Float]([f[0,0]*pp,f[1,0]*pp,0,1]))
//
//            NSLog(" pr = \n\(cube) ->\n xy=\(xyz)\n p=\(pp)\n xy=\(pr) ")
//        }
//
//            let gridPz:[Float] = [
//                1, 0, 0, 0,
//                0, 1, 0, 0,
//                0, 0, 0, 0,
//                0, 0, 1, 1
//            ]
//            
//            let grid:[Float] = [
//                -a, 1, 0, 1,
//                -a,-1, 0, 1,
//                a,-1, 0, 1,
//                a, 1, 0, 1,
//                -a, 1, 0, 1,
//                a, 1, 0, 1,
//                a,-1, 0, 1,
//                -a,-1, 0, 1,
//            ]
//            
//            
//            let cube  = (IMPMatrix(rows: 8, columns: 4, grid: grid) * m * t)
//            
//            let xyzp =  (cube * p)
//            
//            let Pz = IMPMatrix(rows: 4, columns: 4, grid: gridPz)
//            let xyz = IMPMatrix(rows: 4, columns: 1, grid: [Float]([xyzp[0,0],xyzp[0,1],xyzp[0,2],1]))
//            
//            let f = Pz * xyz
//            let pp = f[3,0]
//            let pr = IMPMatrix(rows: 1, columns: 4, grid: [Float]([f[0,0]/pp,f[1,0]/pp,0,1]))
//            
//            NSLog(" pr = \n\(xyzp) \(xyz) \(f) -> \(pr)")
//        }
//        
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

