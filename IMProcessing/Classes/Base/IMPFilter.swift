//
//  IMPFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal

public protocol IMPFilterProtocol:IMPContextProvider {
    var source:IMPImageProvider? {get set}
    var destination:IMPImageProvider? {get}
    var dirty:Bool {get set}
    func apply() -> IMPImageProvider
}

public class IMPFilter: NSObject,IMPFilterProtocol {
    
    public typealias SourceHandler = ((source:IMPImageProvider) -> Void)
    public typealias DestinationHandler = ((destination:IMPImageProvider) -> Void)
    public typealias DirtyHandler = (() -> Void)
    
    public var context:IMPContext!
    
    public var enabled = true {
        didSet{
            if enabled == false && oldValue != enabled {
                executeDestinationObservers(source)
            }
            dirty = true
        }
    }
    
    public var source:IMPImageProvider?{
        didSet{
            source?.filter=self
            dirty = true
            executeNewSourceObservers(source)
        }
    }
    
    public var destination:IMPImageProvider?{
        get{
            if enabled {
                return self.apply()
            }
            else{
                return source
            }
        }
    }
    
    private lazy var _destination:IMPImageProvider = {
        return IMPImageProvider(context: self.context)
    }()
    
    public var destinationSize:MTLSize?{
        didSet{
            if let ov = oldValue{
                if ov != destinationSize! {
                    dirty = true
                }
            }
            else{
                dirty = true
            }
        }
    }
    
    public var dirty:Bool{
        set(newDirty){
            context.dirty = newDirty
            for f in filterList{
                f.dirty = newDirty
            }
            if newDirty == true /*&& context.dirty != true*/ {
                for o in dirtyHandlers{
                    o()
                }
            }
        }
        get{
            return  context.dirty
        }
    }
    
    required public init(context: IMPContext) {
        self.context = context
    }
    
    deinit {
        _destination.texture = nil
        source = nil
    }
    
    private var functionList:[IMPFunction] = [IMPFunction]()
    private var filterList:[IMPFilter] = [IMPFilter]()
    private var newSourceObservers:[SourceHandler] = [SourceHandler]()
    private var sourceObservers:[SourceHandler] = [SourceHandler]()
    private var destinationObservers:[DestinationHandler] = [DestinationHandler]()
    private var dirtyHandlers:[DirtyHandler] = [DirtyHandler]()
    
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
    
    public final func removeAllFunctions(){
        functionList.removeAll()
        self.dirty = true
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
    
    public final func addNewSourceObserver(source observer:SourceHandler){
        newSourceObservers.append(observer)
    }
    
    public final func addSourceObserver(source observer:SourceHandler){
        sourceObservers.append(observer)
    }
    
    public final func addDestinationObserver(destination observer:DestinationHandler){
        destinationObservers.append(observer)
    }
    
    public final func addDirtyObserver(observer:DirtyHandler){
        dirtyHandlers.append(observer)
        for f in filterList{
            f.addDirtyObserver(observer)
        }
    }
    
    public func configure(function:IMPFunction, command:MTLComputeCommandEncoder){}
    
    internal func executeNewSourceObservers(source:IMPImageProvider?){
        if let s = source{
            for o in newSourceObservers {
                o(source: s)
            }
        }
    }
    
    internal func executeSourceObservers(source:IMPImageProvider?){
        if let s = source{
            for o in sourceObservers {
                o(source: s)
            }
        }
    }
    
    internal func executeDestinationObservers(destination:IMPImageProvider?){
        if let d = destination {
            for o in destinationObservers {
                o(destination: d)
            }
        }
    }
    
    var passThroughKernel:IMPFunction?
    
    public func apply() -> IMPImageProvider {
        return doApply()
    }
    
    var weakCopy:Bool {
        return self.context.isLazy
    }
    
    public func main(source source: IMPImageProvider , destination provider:IMPImageProvider) -> IMPImageProvider {
        
        if functionList.count > 0 {
            
            self.context.execute { (commandBuffer) -> Void in
                
                autoreleasepool({ () -> () in
                    
                    var inputTexture:MTLTexture! = source.texture
                    
                    var reverseIndex = self.functionList.count
                    
                    for function in self.functionList {
                        
                        reverseIndex -= 1
                        
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
                        
                        self.updateDestination(provider: provider, width: width, height: height, inputTexture: inputTexture)
                        
                        if let texture = provider.texture {
                            
                            let commandEncoder = commandBuffer.computeCommandEncoder()
                            
                            commandEncoder.setComputePipelineState(function.pipeline!)
                            
                            commandEncoder.setTexture(inputTexture, atIndex:0)
                            commandEncoder.setTexture(texture, atIndex:1)
                            
                            self.configure(function, command: commandEncoder)
                            
                            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
                            commandEncoder.endEncoding()
                            
                            if reverseIndex>0 {
                                
                                if texture.width != inputTexture.width || texture.height != inputTexture.height
                                    ||
                                    inputTexture === source.texture
                                {
                                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                                        (self.source?.texture!.pixelFormat)!,
                                        width: texture.width,
                                        height: texture.height,
                                        mipmapped: false)
                                    inputTexture = self.context.device.newTextureWithDescriptor(descriptor)
                                }
                                
                                if self.weakCopy {
                                    provider.texture = texture
                                }else {
                                    let blit = commandBuffer.blitCommandEncoder()
                                    blit.copyFromTexture(
                                        texture,
                                        sourceSlice: 0,
                                        sourceLevel: 0,
                                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                        sourceSize: MTLSizeMake(texture.width, texture.height, provider.texture!.depth),
                                        toTexture: inputTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                                    blit.endEncoding()
                                }
                            }
                        }
                    }
                    
                    inputTexture = nil
                })
            }
        }
        else {
            self.context.execute { (commandBuffer) -> Void in
                autoreleasepool({ () -> () in
                    let inputTexture:MTLTexture! = source.texture
                    let width  = inputTexture.width
                    let height = inputTexture.height
                    
                    self.updateDestination(provider: provider, width: width, height: height, inputTexture: inputTexture)
                    
                    if self.weakCopy {
                        provider.texture = inputTexture
                    }else {
                        
                        let blit = commandBuffer.blitCommandEncoder()
                        blit.copyFromTexture(
                            inputTexture,
                            sourceSlice: 0,
                            sourceLevel: 0,
                            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                            sourceSize: MTLSizeMake(width, height, provider.texture!.depth),
                            toTexture: provider.texture!, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                        blit.endEncoding()
                    }
               })
            }
        }
        
        if filterList.count > 0 {
            
            var newSource = provider
            
            for filter in filterList {
                
                filter.source = newSource
                
                if filter.destination == nil {
                    return provider
                }
                
                newSource  = filter.destination!
            }
            
            guard let newTexture = newSource.texture else {
                fatalError("IMPFilter error: processing stoped at the last chain filter: \(self, filterList.last)")
            }
            
            self.updateDestination(provider: provider, width: newTexture.width, height: newTexture.height, inputTexture: newTexture)
            
            self.context.execute{ (commandBuffer) -> Void in
                autoreleasepool({ () -> () in
                    if self.weakCopy {
                        provider.texture = newTexture
                    }
                    else {
                        
                        let blit = commandBuffer.blitCommandEncoder()
                        blit.copyFromTexture(
                            newTexture,
                            sourceSlice: 0,
                            sourceLevel: 0,
                            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                            sourceSize: MTLSizeMake(newTexture.width, newTexture.height, newTexture.depth),
                            toTexture: provider.texture!, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                        blit.endEncoding()
                    }
                })
            }
            
        }
        
        return provider
    }
    
    func updateDestination(provider provider: IMPImageProvider, width:Int, height:Int, inputTexture:MTLTexture) {
        if provider.texture?.width != width || provider.texture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                inputTexture.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            if provider.texture != nil {
                provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
            }
            provider.texture = context.device.newTextureWithDescriptor(descriptor)
        }
    }
    
    func doApply() -> IMPImageProvider {
        
        if let source = self.source{
            if dirty {
                
                if functionList.count == 0 && filterList.count == 0 {
                    //
                    // copy source to destination
                    //
                    passThroughKernel = passThroughKernel ?? IMPFunction(context: self.context, name: IMPSTD_PASS_KERNEL)
                    
                    addFunction(passThroughKernel!)
                }
                
                executeSourceObservers(source)
                
                executeDestinationObservers(main(source:  source, destination: _destination))
            }
        }
        dirty = false
        return _destination
    }
}
