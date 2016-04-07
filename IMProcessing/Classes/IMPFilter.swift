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

public typealias IMPFilterSourceHandler = ((source:IMPImageProvider) -> Void)
public typealias IMPFilterDestinationHandler = ((destination:IMPImageProvider) -> Void)
public typealias IMPFilterDirtyHandler = (() -> Void)

public protocol IMPFilterProtocol:IMPContextProvider {
    var source:IMPImageProvider? {get set}
    var destination:IMPImageProvider? {get}
    var dirty:Bool {get set}    
    func apply() -> IMPImageProvider
}

public class IMPFilter: NSObject,IMPFilterProtocol {
    
    public var context:IMPContext!
    
    public var enabled = true {
        didSet{
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
    private var newSourceObservers:[IMPFilterSourceHandler] = [IMPFilterSourceHandler]()
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

    public final func addNewSourceObserver(source observer:IMPFilterSourceHandler){
        newSourceObservers.append(observer)
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
       return apply(counts:nil, groups:nil)
    }
    
    func updateDestination(width:Int, height:Int, inputTexture:MTLTexture) {
        if _destination.texture?.width != width || _destination.texture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                inputTexture.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            if _destination.texture != nil {
                _destination.texture?.setPurgeableState(MTLPurgeableState.Empty)
            }
            _destination.texture = context.device.newTextureWithDescriptor(descriptor)
        }
    }
    
    public func apply(counts counts:MTLSize?, groups:MTLSize?) -> IMPImageProvider {
        if self.source?.texture == nil {
            dirty = false
            return _destination
        }
        
        //autoreleasepool { () -> () in
            if dirty {
                
                if functionList.count == 0 && filterList.count == 0 {
                    //
                    // copy source to destination
                    //
                    passThroughKernel = passThroughKernel ?? IMPFunction(context: self.context, name: IMPSTD_PASS_KERNEL)
                    
                    addFunction(passThroughKernel!)
                }
                
                
                executeSourceObservers(source)
                
                if functionList.count > 0 {
                    
                    self.context.execute() { (commandBuffer) -> Void in
                        
                        autoreleasepool({ () -> () in
                            
                            var inputTexture:MTLTexture! = self.source!.texture
                            
                            var reverseIndex = self.functionList.count
                            
                            for function in self.functionList {
                                
                                reverseIndex -= 1
                                
                                var width  = inputTexture.width
                                var height = inputTexture.height
                                
                                if let s = self.destinationSize {
                                    width = s.width
                                    height = s.height
                                }
                                
                                let threadgroupCounts = counts ?? MTLSizeMake(function.groupSize.width, function.groupSize.height, 1);
                                let threadgroups = groups ?? MTLSizeMake(
                                    (width  + threadgroupCounts.width ) / threadgroupCounts.width ,
                                    (height + threadgroupCounts.height) / threadgroupCounts.height,
                                    1);

                                self.updateDestination(width, height: height, inputTexture: inputTexture)
                                
                                if let texture = self._destination.texture {
                                
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
                                            inputTexture === self.source?.texture
                                        {
                                            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                                                (self.source?.texture!.pixelFormat)!,
                                                width: texture.width,
                                                height: texture.height,
                                                mipmapped: false)
                                            inputTexture = self.context.device.newTextureWithDescriptor(descriptor)
                                        }
                                        
                                        let blit = commandBuffer.blitCommandEncoder()
                                        blit.copyFromTexture(
                                            texture,
                                            sourceSlice: 0,
                                            sourceLevel: 0,
                                            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                            sourceSize: MTLSizeMake(texture.width, texture.height, self._destination.texture!.depth),
                                            toTexture: inputTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                                        blit.endEncoding()
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
                            let inputTexture:MTLTexture! = self.source!.texture
                            let width  = inputTexture.width
                            let height = inputTexture.height

                            self.updateDestination(width, height: height, inputTexture: inputTexture)
                            
                            let blit = commandBuffer.blitCommandEncoder()
                            blit.copyFromTexture(
                                inputTexture,
                                sourceSlice: 0,
                                sourceLevel: 0,
                                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                sourceSize: MTLSizeMake(width, height, self._destination.texture!.depth),
                                toTexture: self._destination.texture!, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                            blit.endEncoding()
                        })
                    }
                }
                
                if filterList.count > 0 {
                    
                    guard var newSource = self._destination ?? source else {
                        return _destination
                    }
                    
                    for filter in filterList {
                        
                        filter.source = newSource
                        
                        if filter.destination == nil {
                            return _destination
                        }
                        
                        newSource  = filter.destination!
                    }
                    
                    guard let newTexture = newSource.texture else {
                        fatalError("IMPFilter error: processing stoped at the last chain filter: \(self, filterList.last)")
                    }

                    self.updateDestination(newTexture.width, height: newTexture.height, inputTexture: newTexture)
                    
                    self.context.execute{ (commandBuffer) -> Void in
                        autoreleasepool({ () -> () in
                            let blit = commandBuffer.blitCommandEncoder()
                            blit.copyFromTexture(
                                newTexture,
                                sourceSlice: 0,
                                sourceLevel: 0,
                                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                sourceSize: MTLSizeMake(newTexture.width, newTexture.height, newTexture.depth),
                                toTexture: self._destination.texture!, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                            blit.endEncoding()
                        })
                    }
                    
                    executeDestinationObservers(_destination)
                }
                else if functionList.count > 0 {
                    executeDestinationObservers(_destination)
                }
                dirty = false
            //}
        }
        return _destination
    }
}
