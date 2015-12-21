//
//  IMPContext.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import Metal
import OpenGL.GL

///
///  @brief Context provider protocol. 
///  All filter classes should conform to the protocol to get access current filter context.
///
public protocol IMPContextProvider{
    var context:IMPContext! {get}
}

/// Context execution closure
public typealias IMPContextExecution = ((commandBuffer:MTLCommandBuffer) -> Void)

/// 
/// The IMProcessing framework supports GPU-accelerated advanced data-parallel computation workloads. 
/// IMPContext instance is created to connect curren GPU device and resources are allocated in order to 
/// do computation.
///
/// IMPContext is a container bring together GPU-device, current command queue and default kernel functions library
/// which export functions to the context.
///
public class IMPContext {
    
    private struct sharedContainerType {
        
        var currentMaximumTextureSize:Int?
        func deviceMaximumTextureSize()->Int{
            dispatch_once(&sharedContainerType.pred) {
                var pixelAttributes:[NSOpenGLPixelFormatAttribute] = [UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated), 0]
                let pixelFormat = NSOpenGLPixelFormat(attributes: &pixelAttributes)
                let context = NSOpenGLContext(format: pixelFormat!, shareContext: nil)
                
                context?.makeCurrentContext()
                
                glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &sharedContainerType.maxTextureSize)
            }
            return Int(sharedContainerType.maxTextureSize)
        }
        
        private static var pred:dispatch_once_t = 0;
        private static var maxTextureSize:GLint = 0;
    }
    
    private static var sharedContainer = sharedContainerType()
    
    /// Current device is used in the current context
    public let device:MTLDevice! = MTLCreateSystemDefaultDevice()
    
    /// Current command queue uses the current device
    public let commandQueue:MTLCommandQueue?
    
    /// Default library associated with current context
    public let defaultLibrary:MTLLibrary?
    
    /// How context execution is processed
    public let isLasy:Bool
    
    ///  Initialize current context
    ///
    ///  - parameter lazy: true if you need to process without waiting finishing computation in the context.
    ///
    ///  - returns: context instanc
    ///
    required public init(lazy:Bool = false)  {
        isLasy = lazy
        if let device = self.device{
            commandQueue = device.newCommandQueue()
            if let library = device.newDefaultLibrary(){
                defaultLibrary = library
            }
            else{
                fatalError(" *** IMPContext: could not find default library...")
            }
            
        }
        else{
            fatalError(" *** IMPContext: could not get GPU device...")
        }
    }
    
    ///  The main idea context execution: all filters should put commands in context queue within the one execution.
    ///
    ///  - parameter closure: execution context
    ///
    public final func execute(closure: IMPContextExecution) {
        if let commandBuffer = commandQueue?.commandBuffer(){
            
            closure(commandBuffer: commandBuffer)
            commandBuffer.commit()
            
            if isLasy == false {
                commandBuffer.waitUntilCompleted()
            }
        }
    }
    
    /// Get the maximum supported devices texture size.
    public static var maximumTextureSize:Int{
        
        set(newMaximumTextureSize){
            IMPContext.sharedContainer.currentMaximumTextureSize = 0
            var size = IMPContext.sharedContainer.deviceMaximumTextureSize()
            if newMaximumTextureSize <= size {
                size = newMaximumTextureSize
            }
            IMPContext.sharedContainer.currentMaximumTextureSize = size
        }
        
        get {
            if let size = IMPContext.sharedContainer.currentMaximumTextureSize{
                return size
            }
            else{
                return IMPContext.sharedContainer.deviceMaximumTextureSize()
            }
        }
        
    }
    
    ///  Get texture size alligned to maximum size which is suported by the current device
    ///
    ///  - parameter inputSize: real size of texture
    ///  - parameter maxSize:   size of a texture which can be placed to the context
    ///
    ///  - returns: maximum size
    ///
    public static func sizeAdjustTo(size inputSize:CGSize, maxSize:Float = Float(IMPContext.maximumTextureSize)) -> CGSize
    {
        if (inputSize.width < CGFloat(maxSize)) && (inputSize.height < CGFloat(maxSize))  {
            return inputSize
        }
        
        var adjustedSize = inputSize
        
        if inputSize.width > inputSize.height {
            adjustedSize = CGSize(width: CGFloat(maxSize), height: ( CGFloat(maxSize) / inputSize.width) * inputSize.height)
        }
        else{
            adjustedSize = CGSize(width: ( CGFloat(maxSize) / inputSize.height) * inputSize.width, height:CGFloat(maxSize))
        }
        
        return adjustedSize;
    }
    
    ///
    /// Dirty-trigger should be set when inherits object change stat of theirs processing
    ///
    public var dirty:Bool = true
    
}
