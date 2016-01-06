//
//  IMPScrollView.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 25.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
    import QuartzCore
#else
    import AppKit
#endif


#if os(iOS)
    
    
    class IMPScrollView: UIScrollView {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            let doubleTap = UITapGestureRecognizer(target: self, action: "zoom:")
            doubleTap.numberOfTapsRequired = 2
            self.addGestureRecognizer(doubleTap)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func zoomRectForScale(scale:CGFloat, center:CGPoint) -> CGRect {
            
            var zoomRect = frame
            
            zoomRect.size.height = frame.size.height / scale
            zoomRect.size.width  = frame.size.width  / scale
            
            // choose an origin so as to get the right center.
            zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0)
            zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0)
            
            return zoomRect;
        }
        
        var originalPoint:CGPoint?
        
        func zoom(gestureRecognizer:UIGestureRecognizer) {
            let duration = UIApplication.sharedApplication().statusBarOrientationAnimationDuration
            if zoomScale <= minimumZoomScale {
                if subviews.count > 0 {
                    let view = subviews[0]
                    originalPoint = view.layer.frame.origin
                    let zoomRect = zoomRectForScale(maximumZoomScale, center:gestureRecognizer.locationInView(view))
                    UIView.animateWithDuration(duration, animations: { () -> Void in
                        view.layer.frame.origin = CGPointZero
                        self.zoomToRect(zoomRect, animated:false)
                    })
                }
            }
            else{
                UIView.animateWithDuration(duration, animations: { () -> Void in
                    if self.subviews.count > 0  && self.originalPoint != nil {
                        let view = self.subviews[0]
                        view.layer.frame.origin = self.originalPoint!
                    }
                    self.setZoomScale(self.minimumZoomScale, animated: false)
                })
            }
        }
    }
    
    public class IMPImageView: IMPViewBase, IMPContextProvider, UIScrollViewDelegate  {
        
        public var context:IMPContext!
        
        public var filter:IMPFilter?{
            didSet{
                imageView?.filter = filter
            }
        }
        
        public var source:IMPImageProvider?{
            get{
                return imageView.source
            }
            set{
                imageView?.source = newValue
                scrollView.zoomScale = 1
            }
        }
        
        public var orientation:UIDeviceOrientation {
            get{
                return imageView.orientation
            }
            set {
                imageView.orientation = newValue
            }
        }
        
        public func setOrientation(orientation:UIDeviceOrientation, animate:Bool){
            imageView.setOrientation(orientation, animate: animate)
        }
        
        private func configure(){
            
            scrollView = IMPScrollView(frame: bounds)
            
            scrollView?.backgroundColor = IMPColor.clearColor()
            scrollView?.showsVerticalScrollIndicator   = false
            scrollView?.showsHorizontalScrollIndicator = false
            scrollView?.scrollEnabled=true
            scrollView?.userInteractionEnabled=true
            scrollView?.maximumZoomScale = 4.0
            scrollView?.minimumZoomScale = 1
            scrollView?.zoomScale = 1
            scrollView?.delegate = self
            self.addSubview(scrollView)
            
            imageView = IMPView(context: self.context, frame: self.bounds)
            imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            imageView.backgroundColor = IMPColor.clearColor()
            
            scrollView.addSubview(imageView)
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
        
        required public init?(coder: NSCoder) {
            super.init(coder: coder)
            self.context = IMPContext()
            defer{
                self.configure()
            }
        }
        
        
        public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        private var minimumScale:Float{
            get {
                let scrollViewSize = self.bounds.size
                let zoomViewSize = scrollView.contentSize
                
                var scaleToFit = fminf(scrollViewSize.width.float / zoomViewSize.width.float, scrollViewSize.height.float / zoomViewSize.height.float);
                if scaleToFit > 1.0 {
                    scaleToFit = 1.0
                }
                return scaleToFit
            }
        }
        
        private var imageView:IMPView!
        private var scrollView:IMPScrollView!
    }
#else
    
    /// Image preview window
    public class IMPImageView: IMPViewBase, IMPContextProvider{
        
        /// GPU device context
        public var context:IMPContext!
        
        /// View backgound
        public var backgroundColor:IMPColor{
            set{
                imageView.backgroundColor = newValue
                scrollView.backgroundColor = newValue
            }
            get{
                return imageView.backgroundColor
            }
        }
        
        /// View filter
        public var filter:IMPFilter?{
            didSet{
                imageView?.filter = filter
            }
        }
        
        /// Image source
        public var source:IMPImageProvider?{
            get{
                return imageView.source
            }
            set{
                imageView?.source = newValue
                if let texture = newValue?.texture{
                    imageView.frame = CGRect(x: 0, y: 0,
                        width:  Int(texture.width.float/imageView.scaleFactor),
                        height: Int(texture.height.float/imageView.scaleFactor))
                }
            }
        }
        
        ///  Magnify image to fit rectangle
        ///
        ///  - parameter rect: rectangle which is used to magnify the image to fit size an position
        public func magnifyToFitRect(rect:CGRect){
            isSizeFit = false
            scrollView.magnifyToFitRect(rect)
        }
        
        private var isSizeFit = true
        
        ///  Fite image to current view size
        public func sizeFit(){
            isSizeFit = true
            scrollView.magnifyToFitRect(imageView.bounds)
        }
        
        ///  Present image in oroginal size
        public func sizeOriginal(){
            isSizeFit = false
            scrollView.magnifyToFitRect(bounds)
        }
        
        @objc func magnifyChanged(event:NSNotification){
            isSizeFit = false
        }
        
        ///  Create image view object with th context within properly frame
        ///
        ///  - parameter contextIn: GPU device context
        ///  - parameter frame:     view frame rectangle
        ///
        public init(context contextIn:IMPContext, frame: NSRect = CGRect(x: 0, y: 0, width: 100, height: 100)){
            super.init(frame: frame)
            context = contextIn
            defer{
                self.configure()
            }
        }
        
        ///  Create image with default context.
        ///
        ///  - parameter frameRect: view frame rectangle
        ///
        public convenience override init(frame frameRect: NSRect) {
            self.init(context: IMPContext(), frame:frameRect)
        }
        
        ///  Create image with a filter
        ///
        ///  - parameter filter: image filter
        ///  - parameter frame:  view frame rectangle
        ///
        public convenience init(filter:IMPFilter, frame:NSRect = CGRect(x: 0, y: 0, width: 100, height: 100)){
            self.init(context:filter.context,frame:frame)
            defer{
                self.filter = filter
            }
        }
        
        required public init?(coder: NSCoder) {
            super.init(coder: coder)
            self.context = IMPContext()
            defer{
                self.configure()
            }
        }
        
        override public func setFrameSize(newSize: NSSize) {
            super.setFrameSize(newSize)
            if isSizeFit {
                sizeFit()
            }
        }
        
        private var imageView:IMPView!
        private var scrollView:IMPScrollView!
        
        private func configure(){
            
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: "magnifyChanged:",
                name: NSScrollViewWillStartLiveMagnifyNotification,
                object: nil)
            
            scrollView = IMPScrollView(frame: bounds)
            
            scrollView.drawsBackground = false
            scrollView.wantsLayer = true
            
            scrollView.allowsMagnification = true
            scrollView.acceptsTouchEvents = true
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            
            scrollView.autoresizingMask = [.ViewHeightSizable, .ViewWidthSizable]
            
            imageView = IMPView(context: self.context, frame: self.bounds)
            imageView.backgroundColor = IMPColor.clearColor()
            
            scrollView.documentView = imageView
            
            addSubview(scrollView)
        }
    }
    
    class IMPScrollView:NSScrollView {
        
        private var cv:IMPClipView!
        
        private func configure(){
            cv = IMPClipView(frame: self.bounds)
            contentView = cv
            verticalScroller = IMPScroller()
            verticalScroller?.controlSize = NSControlSize(rawValue: 5)!
            horizontalScroller = IMPScroller()
            horizontalScroller?.controlSize = NSControlSize(rawValue: 5)!
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.configure()
        }
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.configure()
        }
        
        override func magnifyToFitRect(rect: NSRect) {
            super.magnifyToFitRect(rect)
            self.cv.moveToCenter(true)
        }
        
        override func drawRect(dirtyRect: NSRect) {
            backgroundColor.set()
            NSRectFill(dirtyRect)
        }
    }
    
    class IMPScroller: NSScroller {
        
        var backgroundColor = IMPColor.clearColor()
        
        
        //        func drawBackground(rect:NSRect){
        //            let path = NSBezierPath(roundedRect: rect, xRadius: 0, yRadius: 0)
        //            IMPColor.clearColor().set()
        //            path.fill()
        //        }
        //
        //        static var width = 5
        //
        //        override func drawKnob() {
        //            for i in 0...6{
        //                drawBackground(rectForPart(NSScrollerPart(rawValue: UInt(i))!))
        //            }
        //
        //            let knobRect = rectForPart(.Knob)
        //            let newRect = NSMakeRect((knobRect.size.width -  IMPScroller.width.cgloat) / 2, knobRect.origin.y, IMPScroller.width.cgloat, knobRect.size.height)
        //            let path = NSBezierPath(roundedRect: newRect, xRadius:5, yRadius:5)
        //            IMPColor.lightGrayColor().set()
        //            path.fill()
        //        }
        
        override func drawRect(dirtyRect: NSRect) {
            backgroundColor.set()
            NSRectFill(dirtyRect)
            drawKnob()
        }
        
        override func drawKnobSlotInRect(slotRect: NSRect, highlight flag: Bool) {
            super.drawKnobSlotInRect(slotRect, highlight: true)
        }
        
        override func mouseExited(theEvent:NSEvent){
            super.mouseExited(theEvent)
            self.fadeOut()
        }
        
        override func mouseEntered(theEvent:NSEvent) {
            super.mouseEntered(theEvent)
            NSAnimationContext.runAnimationGroup({ (context) -> Void in
                context.duration = 0.1
                self.animator().alphaValue = 1.0
                
                }, completionHandler: nil)
            NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: "fadeOut", object: nil)
        }
        
        override func mouseMoved(theEvent:NSEvent){
            super.mouseMoved(theEvent)
            self.alphaValue = 1.0
        }
        
        func fadeOut() {
            NSAnimationContext.runAnimationGroup({ (context) -> Void in
                context.duration = 0.3
                self.animator().alphaValue = 1.0
                
                }, completionHandler: nil)
        }
        
    }
    
    class IMPClipView:NSClipView {
        
        private var viewPoint = NSPoint()
        
        override func constrainBoundsRect(proposedBounds: NSRect) -> NSRect {
            if let documentView = self.documentView{
                
                let documentFrame:NSRect = documentView.frame
                var clipFrame     = self.bounds
                
                let x = documentFrame.size.width - clipFrame.size.width
                let y = documentFrame.size.height - clipFrame.size.height
                
                clipFrame.origin = proposedBounds.origin
                
                if clipFrame.size.width>documentFrame.size.width{
                    clipFrame.origin.x = CGFloat(roundf(Float(x) / 2.0))
                }
                else{
                    let m = Float(max(0, min(clipFrame.origin.x, x)))
                    clipFrame.origin.x = CGFloat(roundf(m))
                }
                
                if clipFrame.size.height>documentFrame.size.height{
                    clipFrame.origin.y = CGFloat(roundf(Float(y) / 2.0))
                }
                else{
                    let m = Float(max(0, min(clipFrame.origin.y, y)))
                    clipFrame.origin.y = CGFloat(roundf(m))
                }
                
                viewPoint.x = NSMidX(clipFrame) / documentFrame.size.width;
                viewPoint.y = NSMidY(clipFrame) / documentFrame.size.height;
                
                return clipFrame
                
            }
            else{
                return super.constrainBoundsRect(proposedBounds)
            }
        }
        
        func moveToCenter(always:Bool = false){
            if let documentView = self.documentView{
                
                let documentFrame:NSRect = documentView.frame
                var clipFrame     = self.bounds
                
                if documentFrame.size.width < clipFrame.size.width || always {
                    clipFrame.origin.x = CGFloat(roundf(Float(documentFrame.size.width - clipFrame.size.width) / 2.0));
                } else {
                    clipFrame.origin.x = CGFloat(roundf(Float(viewPoint.x * documentFrame.size.width - (clipFrame.size.width) / 2.0)));
                }
                
                if documentFrame.size.height < clipFrame.size.height || always {
                    clipFrame.origin.y = CGFloat(roundf(Float(documentFrame.size.height - clipFrame.size.height) / 2.0));
                } else {
                    clipFrame.origin.y = CGFloat(roundf(Float(viewPoint.x * documentFrame.size.height - (clipFrame.size.height) / 2.0)));
                }
                
                let scrollView = self.superview
                
                self.scrollToPoint(self.constrainBoundsRect(clipFrame).origin)
                scrollView?.reflectScrolledClipView(self)
            }
        }
        
        override func viewFrameChanged(notification: NSNotification) {
            super.viewBoundsChanged(notification)
            self.moveToCenter()
        }
        
        override var documentView:AnyObject?{
            didSet{
                self.moveToCenter()
            }
        }
    }
#endif
