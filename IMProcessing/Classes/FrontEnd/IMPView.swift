//
//  IMPView.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
    import QuartzCore
    public typealias IMPViewBase = UIView
#else
    import AppKit
    public typealias IMPViewBase = NSView
#endif
import Metal
import GLKit.GLKMath
import QuartzCore


public class IMPView: IMPViewBase, IMPContextProvider {
    
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
                
                self.threadGroups = MTLSizeMake(
                    (texture.width+threadGroupCount.width)/threadGroupCount.width,
                    (texture.height+threadGroupCount.height)/threadGroupCount.height, 1)
                
                #if os(iOS)
                    orientation = currentDeviceOrientation
                    updateLayer()
                #endif

                if let f = self.filter{
                    f.source = source
                }
                else{
                    layerNeedUpdate = true
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
    
    #if os(iOS)
    
    func correctImageOrientation(inTransform:CATransform3D) -> CATransform3D {
        
        var angle:CGFloat = 0
        
        if let orientation = source?.orientation{

            switch orientation {
                
            case .Left, .LeftMirrored:
                angle = Float(90.0).radians.cgloat

            case .Right, .RightMirrored:
                angle = Float(-90.0).radians.cgloat

            case .Down, .DownMirrored:
                angle = Float(180.0).radians.cgloat
                
            default: break
            
            }
        }
        
        return CATransform3DRotate(inTransform, angle, 0.0, 0.0, -1.0)
    }
    
    private var currentDeviceOrientation = UIDeviceOrientation.Portrait
    public var orientation:UIDeviceOrientation{
        get{
            return currentDeviceOrientation
        }
        set{
            setOrientation(orientation, animate: false)
        }
    }
    public func setOrientation(orientation:UIDeviceOrientation, animate:Bool){
        currentDeviceOrientation = orientation
        let duration = UIApplication.sharedApplication().statusBarOrientationAnimationDuration

        UIView.animateWithDuration(
            duration,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: .CurveEaseIn,
            animations: { () -> Void in
                
                if let layer = self.metalLayer {
                    
                    var transform = CATransform3DIdentity
                    
                    transform = CATransform3DScale(transform, 1.0, 1.0, 1.0)
                    
                    var angle:CGFloat = 0
                    
                    switch (orientation) {
                        
                    case .LandscapeLeft:
                        angle = Float(-90.0).radians.cgloat
                        
                    case .LandscapeRight:
                        angle = Float(90.0).radians.cgloat
                        
                    case .PortraitUpsideDown:
                        angle = Float(180.0).radians.cgloat
                        
                    default:
                        break
                    }
                    
                    transform = CATransform3DRotate(transform, angle, 0.0, 0.0, -1.0)
                    
                    layer.transform = self.correctImageOrientation(transform);

                    self.layerNeedUpdate = true
                }
                
            },
            completion:  nil
        )
    }
    #endif
    
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
    
    #if os(OSX)
    public var backgroundColor:IMPColor = IMPColor.clearColor(){
        didSet{
            metalLayer.backgroundColor = backgroundColor.CGColor
        }
    }
    #endif
    
    private var originalBounds:CGRect?
    private var pipeline:MTLComputePipelineState?
    private func configure(){
        
        #if os(iOS)
            metalLayer = CAMetalLayer()
            layer.addSublayer(metalLayer)
        #else
            self.wantsLayer = true
            metalLayer = CAMetalLayer()
            self.layer = metalLayer
        #endif
        
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
    
    #if os(iOS)
    private var timer:CADisplayLink!
    #else
    private var timer:IMPDisplayLink!
    #endif
    
    internal var metalLayer:CAMetalLayer!{
        didSet{
            metalLayer.device = self.context.device
            metalLayer.framebufferOnly = false
            metalLayer.pixelFormat = MTLPixelFormat.BGRA8Unorm
            
            originalBounds = self.bounds
            metalLayer.bounds = originalBounds!
            
            #if os(iOS)
                metalLayer.backgroundColor = self.backgroundColor?.CGColor
            #else
                metalLayer.backgroundColor = self.backgroundColor.CGColor
            #endif
            
            #if os(iOS)
                if timer != nil {
                    timer.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
                }
                timer = CADisplayLink(target: self, selector: "refresh")
            #else
                timer = IMPDisplayLink(selector: refresh)
            #endif
            timer?.paused = self.isPaused
            
            #if os(iOS)
                timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode:NSDefaultRunLoopMode)
            #endif
            
            layerNeedUpdate = true
        }
    }
    
    private let threadGroupCount = MTLSizeMake(8, 8, 1)
    private var threadGroups : MTLSize!
    private let inflightSemaphore = dispatch_semaphore_create(3)
    
    
    #if os(iOS)
    public var screenSize:CGSize{
        get {
            let screen = self.window?.screen ?? UIScreen.mainScreen()
            return screen.bounds.size
        }
    }
    #endif
    
    public var scaleFactor:Float{
        get {
            #if os(iOS)
                return  Float(UIScreen.mainScreen().scale) //Float(self.contentScaleFactor)
            #else
                let screen = self.window?.screen ?? NSScreen.mainScreen()
                let scaleFactor = screen?.backingScaleFactor ?? 1.0
                return Float(scaleFactor)
            #endif
        }
    }
    
    internal func refresh() {
        
        if layerNeedUpdate {
            
            layerNeedUpdate = false
            
            autoreleasepool({ () -> () in
                
                if let actualImageTexture = self.texture {
                                        
                    self.context.execute { (commandBuffer) -> Void in
                        
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
    
    #if os(iOS)
    public func display() {
        self.refresh()
    }
    #else
    override public func display() {
        self.refresh()
    }
    #endif
    
    internal var layerNeedUpdate:Bool = true
    
    #if os(iOS)
    
    func updateLayer(){
        if let l = metalLayer {
            var adjustedSize = bounds.size

            if let t = texture{
                
                l.drawableSize = t.size
                
                var size:CGFloat!
                if UIDeviceOrientationIsLandscape(self.orientation)  {
                    size = t.width < t.height ? originalBounds?.width : originalBounds?.height
                    adjustedSize = IMPContext.sizeAdjustTo(size: t.size.swap(), maxSize: (size?.float)!)
                }
                else{
                    size = t.width > t.height ? originalBounds?.width : originalBounds?.height
                    adjustedSize = IMPContext.sizeAdjustTo(size: t.size, maxSize: (size?.float)!)
                }
            }
            
            var origin = CGPointZero
            if adjustedSize.height < bounds.height {
                origin.y = ( bounds.height - adjustedSize.height ) / 2
            }
            if adjustedSize.width < bounds.width {
                origin.x = ( bounds.width - adjustedSize.width ) / 2
            }
            
            l.frame = CGRect(origin: origin, size: adjustedSize)
            
            print(" ---> bounds = \(l.bounds) frame -> \(l.frame) \(scaleFactor)  adjustedSize = \(adjustedSize)")
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateLayer()
        layerNeedUpdate = true
    }
    
    #else
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
    #endif
}

#if os(OSX)
    
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
#endif
