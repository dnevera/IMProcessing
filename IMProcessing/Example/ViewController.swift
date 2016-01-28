//
//  ViewController.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 14.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import simd

enum IMPPrefs{
    struct colors {
        static let background = float4(x:0.1,y:0.1,z:0.1,w:1.0)
    }
}

class ViewController: NSViewController {
    
    @IBOutlet weak var dominantColorLabel: NSTextField!
    @IBOutlet weak var minRangeLabel: NSTextField!
    @IBOutlet weak var maxRangeLabel: NSTextField!
    @IBOutlet weak var valueSlider1: NSSlider!
    @IBOutlet weak var textValueLabel: NSTextField!
    @IBOutlet weak var histogramCDFContainerView: NSView!
    @IBOutlet weak var histogramContainerView: NSView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    let context = IMPContext()
    
    var mainFilter:IMPTestFilter!
    var lutFilter:IMPLutFilter?
    
    var imageView: IMPView!
    var histogramView: IMPHistogramView!
    var histogramCDFView: IMPHistogramView!
    
    var q = dispatch_queue_create("ViewController", DISPATCH_QUEUE_CONCURRENT)
    
    private func asyncChanges(block:()->Void) {
        dispatch_async(q, { () -> Void in
            //
            // немного того, но... :)
            //
            //dispatch_after(0, dispatch_get_main_queue()) { () -> Void in
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                block()
            }
        })
    }
    
    @IBAction func changeValue1(sender: NSSlider) {
        let value = sender.floatValue/100
        asyncChanges { () -> Void in
            //self.histogramCDFView.histogram.solver.histogramType = (type:.CDF,power:value)
            self.textValueLabel.stringValue = String(format: "%2.5f", value);
            self.mainFilter.hsvFilter?.overlap = value*4
        }
    }
    
    
    @IBAction func changeValue2(sender: NSSlider) {
        asyncChanges { () -> Void in
            self.mainFilter.contrastFilter.adjustment.blending.opacity = sender.floatValue/100
        }
    }
    
    @IBAction func changeValue3(sender: NSSlider) {
        asyncChanges { () -> Void in
            self.mainFilter.awbFilter.adjustment.blending.opacity = sender.floatValue/100
        }
    }
    
    @IBAction func changeValue4(sender: NSSlider) {
        asyncChanges { () -> Void in
            self.lutFilter?.adjustment.blending.opacity = sender.floatValue/100
        }
    }

    @IBAction func changeValue5(sender: NSSlider) {
        asyncChanges { () -> Void in
            
            if sender.floatValue < 2 {
                //self.mainFilter.blur.radius = 0
            }
            else {
                //self.mainFilter.blur.radius = (512*sender.floatValue/100).int
            }
            
            self.mainFilter.dither.adjustment.blending.opacity = sender.floatValue/100
            
//            self.mainFilter.hsvFilter?.adjustment.yellows.hue = (sender.floatValue/100 - 0.5) * 2
//            self.mainFilter.curveFilter.adjustment.blending.opacity = sender.floatValue/100
//            self.mainFilter.curveFilter.splines.compositeControls = [
//                float2(0,0),
//                float2(50,18),
//                float2(128,128*sender.floatValue/100),
//                float2(238,245),
//                float2(255,255)
//            ]
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        histogramContainerView.wantsLayer = true
        histogramContainerView.layer?.backgroundColor = IMPColor.redColor().CGColor
        
        histogramView = IMPHistogramView(context: context, frame: histogramContainerView.bounds)
        histogramView.histogramLayer.solver.layer.backgroundColor = IMPPrefs.colors.background
        
        histogramCDFView = IMPHistogramView(context: context, frame: histogramContainerView.bounds)
        histogramCDFView.histogramLayer.solver.layer.backgroundColor = IMPPrefs.colors.background
        histogramCDFView.histogramLayer.solver.histogramType = (type:.CDF,power:self.valueSlider1.floatValue/100)
        
        histogramContainerView.addSubview(histogramView)
        histogramCDFContainerView.addSubview(histogramCDFView)
        
        imageView = IMPView(frame: scrollView.bounds)
        
        mainFilter = IMPTestFilter(context: context, histogramView: histogramView, histogramCDFView: histogramCDFView)
        imageView.filter = mainFilter
        
        mainFilter.sourceAnalayzer.addUpdateObserver { (histogram) -> Void in
            self.asyncChanges({ () -> Void in
                self.minRangeLabel.stringValue = String(format: "%2.3f", self.mainFilter.rangeSolver.minimum.z)
                self.maxRangeLabel.stringValue = String(format: "%2.3f", self.mainFilter.rangeSolver.maximum.z)
            })
        }
        
        mainFilter.addDestinationObserver { (destination) -> Void in
            self.asyncChanges({ () -> Void in
                if var c = self.mainFilter.awbFilter.dominantColor {
                    c *= 255
                    self.dominantColorLabel.stringValue = String(format: "%3.0f,%3.0f,%3.0f:%3.0f", c.x, c.y, c.z, c.w)
                }
            })
        }
        
        scrollView.drawsBackground = false
        scrollView.documentView = imageView
        scrollView.allowsMagnification = true
        scrollView.acceptsTouchEvents = true
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "magnifyChanged:",
            name: NSScrollViewWillStartLiveMagnifyNotification,
            object: nil)
        
        IMPDocument.sharedInstance.addDocumentObserver { (file, type) -> Void in
            if type == .Image {
                do{
                    self.imageView.source = try IMPImageProvider(context: self.imageView.context, file: file)
                    self.asyncChanges({ () -> Void in
                        self.zoomOne()
                    })
                }
                catch let error as NSError {
                    self.asyncChanges({ () -> Void in
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    })
                }
            }
            else if type == .LUT {
                do {
                    var description = IMPImageProvider.LutDescription()
                    let lutProvider = try IMPImageProvider(context: self.mainFilter.context, cubeFile: file, description: &description)
                    
                    if let lut = self.lutFilter{
                        lut.update(lutProvider, description:description)
                    }
                    else{
                        self.lutFilter = IMPLutFilter(context: self.mainFilter.context, lut: lutProvider, description: description)
                    }
                    self.mainFilter.addFilter(self.lutFilter!)
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
                case .zoomOne:
                    self.zoomOne()
                case .zoom100:
                    self.zoom100()
                case .resetLut:
                    if let l = self.lutFilter {
                        self.mainFilter.removeFilter(l)
                    }
                    break
                }
            }
        }
    }
    
    @objc func magnifyChanged(event:NSNotification){
        is100 = false
    }
    
    var is100 = false
    
    private func zoomOne(){
        is100 = false
        asyncChanges { () -> Void in
            self.scrollView.magnifyToFitRect(self.scrollView.bounds)
        }
    }
    
    private func zoom100(){
        is100 = true
        asyncChanges { () -> Void in
            self.scrollView.magnifyToFitRect(self.imageView.bounds)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.zoom100()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if is100 {
            self.zoom100()
        }
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

