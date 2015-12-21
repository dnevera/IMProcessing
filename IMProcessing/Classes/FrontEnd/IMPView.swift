//
//  IMPView.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import AppKit
import Metal
import GLKit.GLKMath
import QuartzCore


public class IMPView: NSView, IMPContextProvider {
    
    public var context:IMPContext!
    
    public var filter:IMPFilter?{
        didSet{
            if let s = self.source{
                self.filter?.source = s
            }
            filter?.addDirtyObserver({ () -> Void in
                self.layerNeedUpdate = true
            })
        }
    }
    
    public var source:IMPImageProvider?{
        didSet{
            if let texture = source?.texture{
                
                layerNeedUpdate = true
                
                self.threadGroups = MTLSizeMake(
                    (texture.width+threadGroupCount.width)/threadGroupCount.width,
                    (texture.height+threadGroupCount.height)/threadGroupCount.height, 1)
                
                if let f = self.filter{
                    f.source = source
                }
                
            }
        }
    }
    
    private var texture:MTLTexture?{
        get{
            if let t = self.filter?.destination?.texture{
                return t
            }
            else {
                return self.source?.texture
            }
        }
    }
    
    public var isPaused:Bool = false {
        didSet{
            self.timer?.paused = isPaused
        }
    }
    
    public init(context contextIn:IMPContext, frame: NSRect){
        super.init(frame: frame)
        context = contextIn
        defer{
            self.configure()
        }
    }
    
    public convenience override init(frame frameRect: NSRect) {
        self.init(context: IMPContext(), frame:frameRect)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        context = IMPContext()
        defer{
            self.configure()
        }
    }
    
    public var backgroundColor:IMPColor = IMPColor.clearColor(){
        didSet{
            metalLayer.backgroundColor = backgroundColor.CGColor
        }
    }
    
    private var pipeline:MTLComputePipelineState?
    private func configure(){
        
        self.wantsLayer = true
        metalLayer = CAMetalLayer()
        self.layer = metalLayer
        
        let library:MTLLibrary!  = self.context.device.newDefaultLibrary()
        
        //
        // Функция которую мы будем использовать в качестве функции фильтра из библиотеки шейдеров.
        //
        let function:MTLFunction! = library.newFunctionWithName(IMPSTD_PASS_KERNEL)
        
        //
        // Теперь создаем основной объект который будет ссылаться на исполняемый код нашего фильтра.
        //
        pipeline = try! self.context.device.newComputePipelineStateWithFunction(function)                
    }
    
    //
    // TODO: iOS version
    //
    //    class func layerClass() -> AnyClass {
    //        return CAMetalLayer.self;
    //    }
    
    private var timer:IMPDisplayLink!
    
    private var metalLayer:CAMetalLayer!{
        didSet{
            metalLayer.device = self.context.device
            metalLayer.framebufferOnly = false
            metalLayer.pixelFormat = MTLPixelFormat.BGRA8Unorm
            metalLayer.backgroundColor = self.backgroundColor.CGColor
            timer = IMPDisplayLink(selector: refresh)
            timer?.paused = self.isPaused
            layerNeedUpdate = true
        }
    }
    
    private let threadGroupCount = MTLSizeMake(8, 8, 1)
    private var threadGroups : MTLSize!
    private let inflightSemaphore = dispatch_semaphore_create(3)
    
    var scaleFactor:Float{
        get {
            let screen = self.window?.screen ?? NSScreen.mainScreen()
            let scaleFactor = screen?.backingScaleFactor ?? 1.0
            return Float(scaleFactor)
        }
    }
    
    private func refresh() {
                
        if layerNeedUpdate {
            
            layerNeedUpdate = false
            
            autoreleasepool({ () -> () in
                
                var drawableSize = self.bounds.size
                
                drawableSize.width *= CGFloat(self.scaleFactor)
                drawableSize.height *= CGFloat(self.scaleFactor)
                
                metalLayer.drawableSize = drawableSize
                
                self.context.execute { (commandBuffer) -> Void in
                                        
                    if let actualImageTexture = self.texture {
                
                        dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER);

                        commandBuffer.addCompletedHandler({ (commandBuffer) -> Void in
                            dispatch_semaphore_signal(self.inflightSemaphore);
                        })
                        
                        if let drawable = self.metalLayer.nextDrawable(){
                            
                            let encoder = commandBuffer.computeCommandEncoder()
                            
                            encoder.setComputePipelineState(self.pipeline!)
                            
                            encoder.setTexture(actualImageTexture, atIndex: 0)
                            
                            encoder.setTexture(drawable.texture, atIndex: 1)
                            
                            encoder.dispatchThreadgroups(self.threadGroups, threadsPerThreadgroup: self.threadGroupCount)
                            
                            encoder.endEncoding()
                            commandBuffer.presentDrawable(drawable)
                        }
                        else{
                            dispatch_semaphore_signal(self.inflightSemaphore);
                        }
                    }
                }  
            })
        }
    }
    
    override public func display() {
        self.refresh()
    }
    
    internal var layerNeedUpdate:Bool = true
    
    override public func setFrameSize(newSize: NSSize) {
        super.setFrameSize(CGSize(width: newSize.width/CGFloat(self.scaleFactor), height: newSize.height/CGFloat(self.scaleFactor)))
        layerNeedUpdate = true
    }
    
    override public func setBoundsSize(newSize: NSSize) {
        super.setBoundsSize(newSize)
        layerNeedUpdate = true
    }
    override public func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layerNeedUpdate = true
    }
}


private class IMPDisplayLink {
    
    private typealias DisplayLinkCallback = @convention(block) ( CVDisplayLink!, UnsafePointer<CVTimeStamp>, UnsafePointer<CVTimeStamp>, CVOptionFlags, UnsafeMutablePointer<CVOptionFlags>, UnsafeMutablePointer<Void>)->Void
    
    private func displayLinkSetOutputCallback( displayLink:CVDisplayLink, callback:DisplayLinkCallback )
    {
        let block:DisplayLinkCallback = callback
        let myImp = imp_implementationWithBlock( unsafeBitCast( block, AnyObject.self ) )
        let callback = unsafeBitCast( myImp, CVDisplayLinkOutputCallback.self )
        
        CVDisplayLinkSetOutputCallback( displayLink, callback, UnsafeMutablePointer<Void>() )
    }
    
    
    private var displayLink:CVDisplayLink
    
    var paused:Bool = false {
        didSet(oldValue){
            if  paused {
                if CVDisplayLinkIsRunning(displayLink) {
                    CVDisplayLinkStop( displayLink)
                }
            }
            else{
                if !CVDisplayLinkIsRunning(displayLink) {
                    CVDisplayLinkStart( displayLink )
                }
            }
        }
    }
    
    
    required init(selector: ()->Void ){
        
        displayLink = {
            var linkRef:CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays( &linkRef )
            
            return linkRef!
            
            }()
        
        let callback = { (
            _:CVDisplayLink!,
            _:UnsafePointer<CVTimeStamp>,
            _:UnsafePointer<CVTimeStamp>,
            _:CVOptionFlags,
            _:UnsafeMutablePointer<CVOptionFlags>,
            _:UnsafeMutablePointer<Void>)->Void in
            
            selector()
        }
        
        displayLinkSetOutputCallback( displayLink, callback: callback )
    }
    
    deinit{
        self.paused = true
    }
    
}
