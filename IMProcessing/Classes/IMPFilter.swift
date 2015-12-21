//
//  IMPFilter.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa
import Metal

public typealias IMPFilterSourceHandler = ((source:IMPImageProvider) -> Void)
public typealias IMPFilterDestinationHandler = ((destination:IMPImageProvider) -> Void)
public typealias IMPFilterDirtyHandler = (() -> Void)

public class IMPFilter: NSObject,IMPContextProvider {
    
    public var context:IMPContext!
    
    public var source:IMPImageProvider?{
        didSet{
            dirty = true
        }
    }
    
    public var destination:IMPImageProvider?{
        get{
            self.apply()
            return getDestination()
        }
    }
    
    public var destinationSize:MTLSize?{
        didSet{
            if let ov = destinationSize{
                if ov != destinationSize! {
                    dirty = true
                }
            }
        }
    }

    
    public var dirty:Bool{
        set(newDirty){
            self.context.dirty = newDirty
            for f in filterList{
                f.dirty = newDirty
            }
            if newDirty == true {
                for o in dirtyHandlers{
                    o()
                }
            }
        }
        get{
            return  self.context.dirty
        }
    }
    
    required public init(context: IMPContext) {
        self.context = context
    }
    
    private var functionList:[IMPFunction] = [IMPFunction]()
    private var filterList:[IMPFilter] = [IMPFilter]()
    private var sourceObservers:[IMPFilterSourceHandler] = [IMPFilterSourceHandler]()
    private var destinationObservers:[IMPFilterDestinationHandler] = [IMPFilterDestinationHandler]()
    private var dirtyHandlers:[IMPFilterDirtyHandler] = [IMPFilterDirtyHandler]()
    
    public final func addFunction(function:IMPFunction){
        if functionList.contains(function) == false {
            functionList.append(function)
            self.dirty = true
        }
    }
    
    public final func removeFunction(function:IMPFunction){
        if let index = functionList.indexOf(function) {
            functionList.removeAtIndex(index)
            self.dirty = true
        }
    }
    
    public final func addFilter(filter:IMPFilter){
        if filterList.contains(filter) == false {
            filterList.append(filter)
            for o in dirtyHandlers{
                filter.addDirtyObserver(o)
            }
            self.dirty = true
        }
    }
    
    public final func removeFilter(filter:IMPFilter){
        if let index = filterList.indexOf(filter) {
            filterList.removeAtIndex(index)
            self.dirty = true
        }
    }

    public final func addSourceObserver(source observer:IMPFilterSourceHandler){
        sourceObservers.append(observer)
    }
    
    public final func addDestinationObserver(destination observer:IMPFilterDestinationHandler){
        destinationObservers.append(observer)
    }

    public final func addDirtyObserver(observer:IMPFilterDirtyHandler){
        dirtyHandlers.append(observer)
        for f in filterList{
            f.addDirtyObserver(observer)
        }
    }
    
    private var texture:MTLTexture?
    private var destinationContainer:IMPImageProvider?
    
    internal func getDestination() -> IMPImageProvider? {
        if let t = self.texture{
            if let d = destinationContainer{
                d.texture=t
            }
            else{
                destinationContainer = IMPImageProvider(context: self.context, texture: t)
            }
        }
        return destinationContainer
    }
    
    public func configure(function:IMPFunction, command:MTLComputeCommandEncoder){}
    
    private func executeSourceObservers(source:IMPImageProvider?){
        if let s = source{
            for o in sourceObservers {
                o(source: s)
            }
        }
    }
    
    private func executeDestinationObservers(destination:IMPImageProvider?){
        if let d = destination {
            for o in destinationObservers {
                o(destination: d)
            }
        }
    }
    
    public func apply(){
        
        if dirty {

            if self.source?.texture == nil {
                dirty = false
                return
            }

            if  functionList.count > 0 {

                executeSourceObservers(source)
                
                self.context.execute({ (commandBuffer) -> Void in
                    
                    var inputTexture:MTLTexture! = self.source?.texture

                    for function in self.functionList {
                        
                        var width  = inputTexture.width
                        var height = inputTexture.height
                        
                        if let s = self.destinationSize {
                            width = s.width
                            height = s.height
                        }
                        
                        let threadgroupCounts = MTLSizeMake(function.groupSize.width, function.groupSize.height, 1);
                        let threadgroups = MTLSizeMake(
                            (width  + threadgroupCounts.width ) / threadgroupCounts.width ,
                            (height + threadgroupCounts.height) / threadgroupCounts.height,
                            1);
                        
                        if self.texture?.width != width || self.texture?.height != height {
                            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(inputTexture.pixelFormat, width: width, height: height, mipmapped: false)
                            self.texture = self.context.device.newTextureWithDescriptor(descriptor)
                        }
                        
                        let commandEncoder = commandBuffer.computeCommandEncoder()
                        
                        commandEncoder.setComputePipelineState(function.pipeline!)
                        
                        commandEncoder.setTexture(inputTexture, atIndex:0)
                        commandEncoder.setTexture(self.texture, atIndex:1)
                        
                        self.configure(function, command: commandEncoder)
                        
                        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
                        commandEncoder.endEncoding()
                        
                        inputTexture = self.texture
                    }
                })
            }
            else if filterList.count > 0 {
                executeSourceObservers(source)
            }
            
            if self.texture == nil{
                self.texture = self.source?.texture
            }
            
            if filterList.count > 0 {
                
                for filter in self.filterList {

                    filter.source = self.getDestination()
                    self.texture  = filter.destination?.texture
                    
                    if self.texture == nil {
                        fatalError("IMPFilter \(filter) did not return valid texture...")
                    }
                }
                
                executeDestinationObservers(getDestination())
                
            }
            else if functionList.count > 0 {
                executeDestinationObservers(getDestination())
            }
            
            dirty = false
        }
    }
}
