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
    public typealias IMPDragOperationHandler = ((files:[String]) -> Bool)
    
#endif
import Metal
import GLKit.GLKMath
import QuartzCore

/// Image Metal View presentation
public class IMPView: IMPViewBase, IMPContextProvider {
    
    static private let viewVertexData:[Float] = [
        -1.0,  -1.0,  0.0,  1.0,
        1.0,  -1.0,  1.0,  1.0,
        -1.0,   1.0,  0.0,  0.0,
        1.0,   1.0,  1.0,  0.0,
        ]

    /// Current Metal device context
    public var context:IMPContext!
    
    public var ignoreDeviceOrientation:Bool = false
    
    #if os(iOS)
    public var animationDuration:CFTimeInterval  = UIApplication.sharedApplication().statusBarOrientationAnimationDuration
    #else
    public var animationDuration:CFTimeInterval  = 0
    #endif
    
    /// Current image filter
    public var filter:IMPFilter?{
        didSet{
            
            filter?.addNewSourceObserver(source: { (source) in
                if self.isPaused {
                    self.refresh()
                }
            })
            
            filter?.addDirtyObserver({ () -> Void in
                self.layerNeedUpdate = true
            })
            
            #if os(iOS)
            filter?.addDestinationObserver(destination: { (destination) in
                if !self.ignoreDeviceOrientation {
                    self.setOrientation(UIDevice.currentDevice().orientation, animate: false)
                }
            })
            #endif
        }
    }
    
    public var isPaused:Bool = false {
        didSet{
            self.timer?.paused = isPaused
        }
    }
    
    
    public init(context contextIn:IMPContext, frame: NSRect=CGRect(x: 0, y: 0, width: 100, height: 100)) {
        super.init(frame: frame)
        context = contextIn
        defer{
            self.configure()
        }
    }
    
    public convenience override init(frame frameRect: NSRect)  {
        self.init(context: IMPContext(), frame:frameRect)
    }
    
    public convenience init(filter:IMPFilter, frame:NSRect=CGRect(x: 0, y: 0, width: 100, height: 100)){
        self.init(context:filter.context,frame:frame)
        defer{
            self.filter = filter
        }
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
    #else
    override public var backgroundColor:UIColor? {
        didSet{
            super.backgroundColor = backgroundColor
            if let c = backgroundColor?.CGColor{
                metalLayer.backgroundColor = c
            }
        }
    }
    #endif
    
    internal lazy var originalBounds:CGRect = self.bounds
    private var pipeline:MTLComputePipelineState?
    private func configure(){
        
        #if os(iOS)
            metalLayer = CAMetalLayer()
            layer.addSublayer(metalLayer)
        #else
            wantsLayer = true
            metalLayer = CAMetalLayer()
            metalLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB)!
            layerContentsRedrawPolicy = .DuringViewResize
            layer?.addSublayer(metalLayer)
            
            registerForDraggedTypes([NSFilenamesPboardType])
            
        #endif
        
        let library:MTLLibrary!  = self.context.device.newDefaultLibrary()
        
        let function:MTLFunction! = library.newFunctionWithName(IMPSTD_VIEW_KERNEL)
        
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
            metalLayer.pixelFormat = .BGRA8Unorm
            
            originalBounds = self.bounds
            metalLayer.bounds = originalBounds
            
            #if os(iOS)
                metalLayer.backgroundColor = self.backgroundColor?.CGColor
            #else
                metalLayer.backgroundColor = self.backgroundColor.CGColor
            #endif
            
            #if os(iOS)
                if self.timer != nil {
                    self.timer.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
                }
                self.timer = CADisplayLink(target: self, selector: #selector(self.refresh))
            #else
                self.timer = IMPDisplayLink.sharedInstance
                self.timer?.addView(self)
            #endif
            self.timer?.paused = self.isPaused
            
            #if os(iOS)
                self.timer.addToRunLoop(NSRunLoop.currentRunLoop(), forMode:NSRunLoopCommonModes)
            #endif

            layerNeedUpdate = true
        }
    }
    
    deinit{
        #if os(OSX)
            timer?.removeView(self)
        #endif
    }
    
    private let inflightSemaphore = dispatch_semaphore_create(4)
    
    
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
                return  Float(UIScreen.mainScreen().scale)
            #else
                let screen = self.window?.screen ?? NSScreen.mainScreen()
                let scaleFactor = screen?.backingScaleFactor ?? 1.0
                return Float(scaleFactor)
            #endif
        }
    }
    
    public var viewReadyHandler:(()->Void)?
    private var isFirstFrame = true
    
    lazy var vertexBuffer:MTLBuffer = {
        let v = self.context.device.newBufferWithBytes(viewVertexData, length:sizeof(Float)*viewVertexData.count, options:.CPUCacheModeDefaultCache)
        v.label = "Vertices"
        return v
    }()

    lazy var renderPipeline:MTLRenderPipelineState? = {
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            
            descriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
            descriptor.vertexFunction = self.context.defaultLibrary.newFunctionWithName("vertex_passview")
            descriptor.fragmentFunction = self.context.defaultLibrary.newFunctionWithName("fragment_passview")
            
            return try self.context.device.newRenderPipelineStateWithDescriptor(descriptor)
        }
        catch let error as NSError {
            NSLog("IMPView error: \(error)")
            return nil
        }
    }()
    
    #if os(iOS)

    func correctImageOrientation(inTransform:CATransform3D) -> CATransform3D {
        
        var angle:CGFloat = 0
        
        if let orientation = filter?.source?.orientation{
            
            switch orientation {
                
            case .Left, .LeftMirrored:
                angle = Float(90.0).radians.cgfloat
                
            case .Right, .RightMirrored:
                angle = Float(-90.0).radians.cgfloat
                
            case .Down, .DownMirrored:
                angle = Float(180.0).radians.cgfloat
                
            default: break
                
            }
        }
        
        return CATransform3DRotate(inTransform, angle, 0.0, 0.0, -1.0)
    }

    private var currentDeviceOrientation = UIDeviceOrientation.Unknown
    
    public var orientation:UIDeviceOrientation{
        get{
            return currentDeviceOrientation
        }
        set{
            setOrientation(orientation, animate: false)
        }
    }
    
    func delay(delay:NSTimeInterval, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
    
    
    public func setOrientation(orientation:UIDeviceOrientation, animate:Bool){
        
        let duration = animate ? animationDuration : 0
        
        var transform = CATransform3DIdentity
        
        func doTransform() {
            if let layer = self.metalLayer {
                
                transform = CATransform3DScale(transform, 1.0, 1.0, 1.0)
                
                var angle:CGFloat = 0
                
                switch (orientation) {
                    
                case .LandscapeLeft:
                    angle = Float(-90.0).radians.cgfloat
                    self.currentDeviceOrientation = orientation
                    
                case .LandscapeRight:
                    angle = Float(90.0).radians.cgfloat
                    self.currentDeviceOrientation = orientation
                    
                case .PortraitUpsideDown:
                    angle = Float(180.0).radians.cgfloat
                    self.currentDeviceOrientation = orientation
                    
                case .Portrait:
                    self.currentDeviceOrientation = orientation
                    
                default:
                    break
                }
                
                transform = CATransform3DRotate(transform, angle, 0.0, 0.0, -1.0)
    
                delay(duration, closure: {
                    self.updateLayer(duration)
                    self.animateLayer(duration, closure: { (duration) in
                        layer.transform = self.correctImageOrientation(transform);
                    })
                })
            }
        }
        
        if animate {
            
            UIView.animateWithDuration(
                duration,
                delay: 0,
                usingSpringWithDamping: 1.0,
                initialSpringVelocity: 0,
                options: .CurveEaseIn,
                animations: { () -> Void in
                    doTransform()
                },
                completion:  nil
            )
            
        }
        else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            doTransform()
            CATransaction.commit()
        }
    }
    
    #endif
    
    lazy var renderPassDescriptor:MTLRenderPassDescriptor = MTLRenderPassDescriptor()

    var clearColor:MTLClearColor {
        get {
            #if os(OSX)
                let rgba = backgroundColor.rgba
                return MTLClearColor(red: rgba.r.double,
                                     green: rgba.g.double,
                                     blue: rgba.b.double,
                                     alpha: rgba.a.double)
            #else
            if let rgba = backgroundColor?.rgba {
            return MTLClearColor(red: rgba.r.double,
                                 green: rgba.g.double,
                                 blue: rgba.b.double,
                                 alpha: rgba.a.double)
            }
            else {
                return MTLClearColorMake(0, 0, 0, 0)
            }
            #endif
        }
    }
    
    var currentDestination:IMPImageProvider? = nil
    
    
    internal func refresh() {
        
        dispatch_async(dispatch_get_main_queue()) {
            
            
            if self.layerNeedUpdate {
                
                self.layerNeedUpdate = false
                
                autoreleasepool({ () -> () in
                    
                    self.currentDestination = self.filter?.destination
                    
                    if let actualImageTexture = self.currentDestination?.texture {
                        
                        if !CGSizeEqualToSize(self.metalLayer.drawableSize, actualImageTexture.size){ self.metalLayer.drawableSize = actualImageTexture.size }

                        if let drawable = self.metalLayer.nextDrawable(){
                                                        
                            self.renderPassDescriptor.colorAttachments[0].texture     = drawable.texture
                            self.renderPassDescriptor.colorAttachments[0].loadAction  = .Clear
                            self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                            self.renderPassDescriptor.colorAttachments[0].clearColor =  self.clearColor
                            
                            self.context.execute { (commandBuffer) -> Void in
                                
                                self.context.wait()
                                
                                commandBuffer.addCompletedHandler({ (commandBuffer) -> Void in
                                    self.context.resume()
                                })
                                
                                let encoder = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)
                                
                                //
                                // render current texture
                                //
                                
                                if let pipeline = self.renderPipeline {
                                    
                                    encoder.setRenderPipelineState(pipeline)
                                    
                                    encoder.setVertexBuffer(self.vertexBuffer, offset:0, atIndex:0)
                                    encoder.setFragmentTexture(actualImageTexture, atIndex:0)
                                    
                                    encoder.drawPrimitives(.TriangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
                                    encoder.endEncoding()
                                }
                                
                                commandBuffer.presentDrawable(drawable)
                                
                                if self.isFirstFrame && self.viewReadyHandler !=  nil {
                                    self.isFirstFrame = false
                                    self.viewReadyHandler!()
                                }
                            }
                        }
                        else{
                            self.context.resume()
                        }
                    }
                })
            }
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
    
    internal var layerNeedUpdate:Bool = true  {
        didSet {
            dispatch_async(dispatch_get_main_queue()) { 
                if self.layerNeedUpdate {
                    #if os(iOS)
                        self.updateLayer(self.isFirstFrame ? 0 : self.animationDuration)
                    #else
                        self.updateLayer()
                    #endif
                }
            }
        }
    }
    
    func animateLayer(duration:NSTimeInterval, closure:((duration:NSTimeInterval)->Void)) {
        
        CATransaction.begin()
        CATransaction.setDisableActions(duration <= 0 ? true : false)
        if duration > 0 {
            CATransaction.setAnimationDuration(duration)
        }
        
        closure(duration: duration)
        
        CATransaction.commit()
    }
    
    
    func getNewBounds(texture:MTLTexture) -> CGRect {
        var adjustedSize = bounds.size
        
        if !ignoreDeviceOrientation{
            
            adjustedSize = originalBounds.size
            
            var ratio  = texture.width.cgfloat/texture.height.cgfloat
            let aspect = originalBounds.size.width/originalBounds.size.height
            
            #if os(iOS)
            if UIDeviceOrientationIsLandscape(self.orientation)  {
                ratio  = 1/ratio
            }
            #endif
            
            let newRatio = aspect/ratio
            
            if newRatio < 1 {
                adjustedSize.height *= newRatio
            }
            else {
                adjustedSize.width /= newRatio
            }
        }
        
        var origin = CGPointZero
        
        if adjustedSize.height < bounds.height {
            origin.y = ( bounds.height - adjustedSize.height ) / 2
        }
        if adjustedSize.width < bounds.width {
            origin.x = ( bounds.width - adjustedSize.width ) / 2
        }
        
        return  CGRect(origin: origin, size: adjustedSize)
    }

    #if os(iOS)

    func changeBounds(texure:MTLTexture, bounds:CGRect, duration:NSTimeInterval) {
        
        guard let l = metalLayer else { return }
        if !CGRectEqualToRect(l.frame, bounds) {

            animateLayer(duration, closure: { (duration) in
              l.frame = bounds
            })
        }
    }
    
    internal func updateLayer(duration:NSTimeInterval){
        currentDestination = currentDestination ?? filter?.destination
        guard let t = currentDestination?.texture else { return }
        changeBounds(t, bounds:  getNewBounds(t), duration: duration)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        layerNeedUpdate = true
    }
    
    #else
    
    func changeBounds(texure:MTLTexture, bounds:CGRect, duration:NSTimeInterval) {
    
        guard let l = metalLayer else { return }
    
        if !CGRectEqualToRect(l.frame, bounds) {
            animateLayer(duration, closure: { (duration) in
                l.frame = bounds
            })
        }
    }

    override public func updateLayer(){
        currentDestination = currentDestination ?? filter?.destination
        guard let t = currentDestination?.texture else { return }
        
        if let l = metalLayer {
            l.drawableSize = t.size
            animateLayer(animationDuration, closure: { (duration) in
                l.frame = CGRect(origin: CGPointZero, size:  self.bounds.size)
            })
        }
    }
    
    public override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        
        let sourceDragMask = sender.draggingSourceOperationMask()
        let pboard = sender.draggingPasteboard()
        
        if pboard.availableTypeFromArray([NSFilenamesPboardType]) == NSFilenamesPboardType {
            if sourceDragMask.rawValue & NSDragOperation.Generic.rawValue != 0 {
                return NSDragOperation.Generic
            }
        }
        
        return NSDragOperation.None
    }
    
    public var dragOperation:IMPDragOperationHandler?
    
    public override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if let files  = sender.draggingPasteboard().propertyListForType(NSFilenamesPboardType) {
            if let o = dragOperation {
                return o(files: files as! [String])
            }
        }
        return false
    }
    
    lazy var trackingArea:NSTrackingArea? = nil

    override public func updateTrackingAreas() {
        if mouseEventEnabled {
            super.updateTrackingAreas()
            if let t = trackingArea{
                removeTrackingArea(t)
            }
            trackingArea = NSTrackingArea(rect: frame,
                                          options: [.ActiveInKeyWindow,.MouseMoved,.MouseEnteredAndExited],
                                          owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
    }
   
    override public func mouseEntered(event:NSEvent) {
        lounchMouseObservers(event)
    }
    
    override public func mouseExited(event:NSEvent) {
        lounchMouseObservers(event)
    }
    
    override public func mouseMoved(event:NSEvent) {
        lounchMouseObservers(event)
    }
   
    override public func mouseDown(event:NSEvent) {
        lounchMouseObservers(event)
    }
    
    override public func mouseUp(event:NSEvent) {
        lounchMouseObservers(event)
    }
    
    public typealias MouseEventHandler = ((event:NSEvent)->Void)
    
    var mouseEventHandlers = [MouseEventHandler]()
    
    var mouseEventEnabled = false
    public func addMouseEventObserver(observer:MouseEventHandler){
        mouseEventHandlers.append(observer)
        mouseEventEnabled = true
    }
    
    public func removeMouseEventObservers(){
        mouseEventEnabled = false
        if let t = trackingArea{
            removeTrackingArea(t)
        }
        mouseEventHandlers.removeAll()
    }
    
    func lounchMouseObservers(event:NSEvent){
        for o in mouseEventHandlers {
            o(event: event)
        }
    }
    
    #endif
}

#if os(OSX)
    
    private class IMPDisplayLink {
        
        static let sharedInstance = IMPDisplayLink()
        
        private typealias DisplayLinkCallback = @convention(block) ( CVDisplayLink!, UnsafePointer<CVTimeStamp>, UnsafePointer<CVTimeStamp>, CVOptionFlags, UnsafeMutablePointer<CVOptionFlags>, UnsafeMutablePointer<Void>)->Void
        
        private func displayLinkSetOutputCallback( displayLink:CVDisplayLink, callback:DisplayLinkCallback )
        {
            let block:DisplayLinkCallback = callback
            let myImp = imp_implementationWithBlock( unsafeBitCast( block, AnyObject.self ) )
            let callback = unsafeBitCast( myImp, CVDisplayLinkOutputCallback.self )
            
            CVDisplayLinkSetOutputCallback( displayLink, callback, nil)
        }
        
        
        private var displayLink:CVDisplayLink!
        
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
        
        private var viewList = [IMPView]()
        
        func addView(view:IMPView){
            if viewList.contains(view) == false {
                viewList.append(view)
            }
        }
        
        func removeView(view:IMPView){
            if let index = viewList.indexOf(view) {
                viewList.removeAtIndex(index)
            }
        }
        
        required init(){
            
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
                
                for v in self.viewList {
                    v.refresh()
                }
                
            }
            
            displayLinkSetOutputCallback( displayLink, callback: callback )
        }
        
        deinit{
            self.paused = true
        }
        
    }
#endif
