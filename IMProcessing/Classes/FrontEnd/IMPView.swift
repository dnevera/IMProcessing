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


typealias __IMPViewLayerUpdate = (()->Void)

let viewVertexData:[Float] = [
    -1.0,  -1.0,  0.0,  1.0,
     1.0,  -1.0,  1.0,  1.0,
    -1.0,   1.0,  0.0,  0.0,
     1.0,   1.0,  1.0,  0.0,
]



/// Image Metal View presentation
public class IMPView: IMPViewBase, IMPContextProvider {
    
    /// Current Metal device context
    public var context:IMPContext!
    
    /// Current image filter
    public var filter:IMPFilter?{
        didSet{
            
            filter?.addNewSourceObserver(source: { (source) in                
                if let texture = self.filter?.source?.texture{
                    if self.isPaused {
                        self.refresh()
                    }
                }
            })
            
            filter?.addDirtyObserver({ () -> Void in
                self.layerNeedUpdate = true
            })
        }
    }
    
    lazy internal var updateLayerHandler:__IMPViewLayerUpdate = {
        return self.updateLayer
    }()
    
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
    #endif
    
    internal var originalBounds:CGRect?
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
            metalLayer.bounds = originalBounds!
            
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
    
    lazy var renderPassDescriptor:MTLRenderPassDescriptor = MTLRenderPassDescriptor()

    internal func refresh() {
        
        if layerNeedUpdate {
                
            layerNeedUpdate = false
            
            autoreleasepool({ () -> () in
                
                if let actualImageTexture = filter?.destination?.texture {
                    
                    if let drawable = self.metalLayer.nextDrawable(){

                        renderPassDescriptor.colorAttachments[0].texture     = drawable.texture;
                        renderPassDescriptor.colorAttachments[0].loadAction  = .Clear;
                        renderPassDescriptor.colorAttachments[0].storeAction = .Store;
                        renderPassDescriptor.colorAttachments[0].clearColor =  MTLClearColorMake(0, 0, 0, 0);
                        
                        
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
    
    internal func updateLayer(){
        if let l = metalLayer {
            let adjustedSize = bounds.size
            
            if let t = filter?.destination?.texture{
                l.drawableSize = t.size
            }
            
            var origin = CGPointZero
            if adjustedSize.height < bounds.height {
                origin.y = ( bounds.height - adjustedSize.height ) / 2
            }
            if adjustedSize.width < bounds.width {
                origin.x = ( bounds.width - adjustedSize.width ) / 2
            }
            
            l.frame = CGRect(origin: origin, size: adjustedSize)
            layerNeedUpdate = true
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateLayerHandler()
    }
    
    #else
    
    override public func updateLayer(){
        if let l = metalLayer {
            if let t = filter?.destination?.texture{
                l.drawableSize = t.size
            }
            l.frame = CGRect(origin: CGPointZero, size:  bounds.size)
        }
        layerNeedUpdate = true
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
