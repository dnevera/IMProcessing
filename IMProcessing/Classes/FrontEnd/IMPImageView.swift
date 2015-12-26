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
        
        #if os(iOS)
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
        
        #endif
        
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
        
        private var imageContainer:UIView!
        private var imageView:IMPView!
        private var scrollView:IMPScrollView!
    }
#endif
