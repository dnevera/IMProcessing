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
    var observersEnabled:Bool {get set}
    var dirty:Bool {get set}
    func apply() -> IMPImageProvider
}

public class IMPFilter: NSObject,IMPFilterProtocol {
    
    public typealias SourceHandler = ((source:IMPImageProvider) -> Void)
    public typealias DestinationHandler = ((destination:IMPImageProvider) -> Void)
    public typealias DirtyHandler = (() -> Void)
    
    public var observersEnabled = true {
        didSet {
            for f in filterList {
                f.observersEnabled = observersEnabled
            }
        }
    }
    
    public var context:IMPContext!
    
    public var enabled = true {
        didSet{
            
            for filter in filterList {
                filter.enabled = enabled
            }
            
            dirty = true
            
            if enabled == false && oldValue != enabled {
                executeDestinationObservers(source)
            }
        }
    }
    
    public var source:IMPImageProvider?{
        didSet{
            if let s = source{
                s.filter=self
                _destination.orientation =  s.orientation
            }
            executeNewSourceObservers(source)
            dirty = true
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
    
    var _root:IMPFilter? = nil
    public var root:IMPFilter? {
        return _root
    }
    
    func updateNewFilterHandlers(filter:IMPFilter)  {
        filter._root = self
        for o in dirtyHandlers{
            filter.addDirtyObserver(o)
        }
        dirty = true
    }
    
    func removeFilterHandlers(filter:IMPFilter) {
        filter._root = nil
        filter.dirtyHandlers.removeAll()
        dirty = true
    }
    
    public final func addFilter(filter:IMPFilter){
        if filterList.contains(filter) == false {
            filterList.append(filter)
            updateNewFilterHandlers(filter)
        }
    }
    
    public final func removeFilter(filter:IMPFilter){
        if let index = filterList.indexOf(filter) {
            removeFilterHandlers(filterList.removeAtIndex(index) as IMPFilter)
        }
    }
    
    public final func removeFromStack() {
        if _root != nil {
            _root?.removeFilter(self)
        }
    }
    
    public final func insertFilter(filter:IMPFilter, index:Int){
        if filterList.contains(filter) == false {
            var i = index
            if i >= filterList.count {
                i = filterList.count
            }
            filterList.insert(filter, atIndex: i)
            updateNewFilterHandlers(filter)
        }
    }
    
    public final func insertFilter(filter:IMPFilter, before:IMPFilter){
        if filterList.contains(filter) == false {
            if let index = filterList.indexOf(before) {
                filterList.insert(filter, atIndex: index)
                updateNewFilterHandlers(filter)
            }
        }
    }
    
    public final func insertFilter(filter:IMPFilter, after:IMPFilter){
        if filterList.contains(filter) == false {
            if let index = filterList.indexOf(after) {
                filterList.insert(filter, atIndex: index+1)
                updateNewFilterHandlers(filter)
            }
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
        if observersEnabled {
            if let s = source{
                for o in sourceObservers {
                    o(source: s)
                }
            }
        }
    }
    
    internal func executeDestinationObservers(destination:IMPImageProvider?){
        if observersEnabled {
            if let d = destination {
                for o in destinationObservers {
                    o(destination: d)
                }
            }
        }
    }
    
    var passThroughKernel:IMPFunction?
    
    public func apply() -> IMPImageProvider {
        return doApply()
    }
    
    func newDestinationtexture(destination provider:IMPImageProvider, source input: MTLTexture) -> (MTLTexture, Int, Int) {

        var width  = input.width
        var height = input.height
        
        if let s = self.destinationSize {
            width = s.width
            height = s.height
        }

        if provider.texture?.width != width || provider.texture?.height != height
            ||
        provider === source
        {
            let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                input.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            if provider.texture != nil {
                provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
            }
            
            return (context.device.newTextureWithDescriptor(descriptor), width, height)
        }
        else {

            return (provider.texture!, provider.texture!.width, provider.texture!.height)
        }
    }
    
    public func main(source source: IMPImageProvider , destination provider:IMPImageProvider) -> IMPImageProvider? {
        return nil
    }
    
    func internal_main(source source: IMPImageProvider , destination provider:IMPImageProvider) -> IMPImageProvider {
        
        var currentFilter = self
        
        var currrentProvider:IMPImageProvider = source

        if var input = source.texture {
            
            if functionList.count > 0 {
                
                var width:Int
                var height:Int
                let texture:MTLTexture
                
                (texture, width, height) = self.newDestinationtexture(destination: provider, source: input)
                
                provider.texture = texture
                
                if let output = provider.texture {
                    
                    //
                    // Functions
                    //
                    
                    for function in self.functionList {
                        
                        self.context.execute { (commandBuffer) -> Void in
                            
                            let threadgroupCounts = MTLSizeMake(function.groupSize.width, function.groupSize.height, 1);
                            let threadgroups = MTLSizeMake(
                                (width  + threadgroupCounts.width ) / threadgroupCounts.width ,
                                (height + threadgroupCounts.height) / threadgroupCounts.height,
                                1);
                            
                            let commandEncoder = commandBuffer.computeCommandEncoder()
                            
                            commandEncoder.setComputePipelineState(function.pipeline!)
                            
                            commandEncoder.setTexture(input, atIndex:0)
                            commandEncoder.setTexture(output, atIndex:1)
                            
                            self.configure(function, command: commandEncoder)
                            
                            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
                            commandEncoder.endEncoding()
                            
                        }
                        
                            input = output
                    }
                    
                    currrentProvider = provider
                }
            }
            
            
            if let p = main(source: currrentProvider, destination: provider) {
                currrentProvider = p
            }
            
            //
            // Filter chains...
            //
            for filter in filterList {
                filter.source = currrentProvider
                currentFilter = filter
                currrentProvider = currentFilter.destination!
            }
        }
        
        return  currrentProvider
    }
    
    private lazy var _destination:IMPImageProvider = {
        return IMPImageProvider(context: self.context)
    }()

    func doApply() -> IMPImageProvider {
        
        if let s = self.source{
            if dirty {
                
                if functionList.count == 0 && filterList.count == 0 {
                    
                    //
                    // copy source to destination
                    //
                    
                    //passThroughKernel = passThroughKernel ?? IMPFunction(context: self.context, name: IMPSTD_PASS_KERNEL)
                    //addFunction(passThroughKernel!)
                }
                
                executeSourceObservers(source)
                
                _destination = internal_main(source:  s, destination: _destination)
                
                executeDestinationObservers(_destination)
            }
        }
        
        dirty = false
        
        return _destination
    }

    deinit {
        _destination.texture = nil
        source = nil
    }
}
