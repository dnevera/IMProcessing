//
//  IMPHistogramAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 07.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import Accelerate

///
/// Histogram updates handler.
///
public typealias IMPAnalyzerUpdateHandler =  ((histogram:IMPHistogram) -> Void)

///
/// Hardware uses to compute histogram.
///
public enum IMPHistogramAnalyzerHardware {
    case GPU
    case DSP
}

///
/// Common protocol defines histogram class API.
///
public protocol IMPHistogramAnalyzerProtocol:NSObjectProtocol,IMPFilterProtocol {
    
    var hardware:IMPHistogramAnalyzerHardware {get}
    var histogram:IMPHistogram {get set}
    var downScaleFactor:Float! {get set}
    var region:IMPRegion!  {get set}
    
    func addSolver(solver:IMPHistogramSolver)
    func addUpdateObserver(observer:IMPAnalyzerUpdateHandler)
    
}

///
/// Histogram solvers protocol. Solvers define certain computations to calculate measurements metrics such as:
/// 1. histogram range (dynamic range)
/// 2. get peaks and valyes
/// 3. ... etc
///
public protocol IMPHistogramSolver {
    func analizerDidUpdate(analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize);
}


public extension IMPHistogramAnalyzerProtocol {
    public func setCenterRegionInPercent(value:Float){
        let half = value/2.0
        region = IMPRegion(
            left:   0.5 - half,
            right:  1.0 - (0.5+half),
            top:    0.5 - half,
            bottom: 1.0 - (0.5+half)
        )
    }
}


public extension IMPContext {
    public func hasFastAtomic() -> Bool {
        #if os(iOS)
            return self.device.supportsFeatureSet(.iOS_GPUFamily2_v1)
        #else
            return false
        #endif
    }
}

///
/// Histogram analizer uses to create IMPHistogram object from IMPImageProvider source.
///
public class IMPHistogramAnalyzer: IMPFilter,IMPHistogramAnalyzerProtocol {

    public typealias Hardware = IMPHistogramAnalyzerHardware

    ///
    /// Defines wich hardware uses to compute final histogram.
    /// DSP is faster but needs memory twice, GPU is slower but doesn't additanal memory.
    ///
    public var hardware:IMPHistogramAnalyzer.Hardware {
        return _hardware
    }
    var _hardware:IMPHistogramAnalyzer.Hardware!
    
    ///
    /// Histogram
    ///
    public var histogram = IMPHistogram(){
        didSet{
            channelsToCompute = UInt(histogram.channels.count)
        }
    }
    
    ///
    /// На сколько уменьшаем картинку перед вычисления гистограммы.
    ///
    public var downScaleFactor:Float!{
        didSet{
            scaleUniformBuffer = scaleUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(Float), options: .CPUCacheModeDefaultCache)
            memcpy(scaleUniformBuffer.contents(), &downScaleFactor, sizeof(Float))
            dirty = true
        }
    }
    private var scaleUniformBuffer:MTLBuffer!
    
    private var channelsToCompute:UInt?{
        didSet{
            channelsToComputeBuffer = channelsToComputeBuffer ?? self.context.device.newBufferWithLength(sizeof(UInt), options: .CPUCacheModeDefaultCache)
            memcpy(channelsToComputeBuffer.contents(), &channelsToCompute, sizeof(UInt))
        }
    }
    private var channelsToComputeBuffer:MTLBuffer!
    
    private var solvers:[IMPHistogramSolver] = [IMPHistogramSolver]()
    
    ///
    /// Солверы анализирующие гистограмму в текущем инстансе
    ///
    public func addSolver(solver:IMPHistogramSolver){
        solvers.append(solver)
    }
    
    ///
    /// Регион внутри которого вычисляем гистограмму.
    ///
    public var region:IMPRegion!{
        didSet{
            regionUniformBuffer = regionUniformBuffer ?? self.context.device.newBufferWithLength(sizeof(IMPRegion), options: .CPUCacheModeDefaultCache)
            memcpy(regionUniformBuffer.contents(), &region, sizeof(IMPRegion))
        }
    }
    internal var regionUniformBuffer:MTLBuffer!
    
    ///
    /// Кernel-функция счета
    ///
    public var kernel:IMPFunction {
        return _kernel
    }
    private var _kernel:IMPFunction!
    
    //
    // Буфер обмена контейнера счета с GPU
    //
    private var histogramUniformBuffer:MTLBuffer!
    
    //
    // Количество групп обсчета. Кратно <максимальное количество ядер>/размерность гистограммы.
    // Предполагаем, что количество ядер >= 256 - минимальной размерности гистограммы.
    // Расчет гистограммы просиходит в 3 фазы:
    // 1. GPU:kernel:расчет частичных гистограмм в локальной памяти, количество одновременных ядер == размерноси гистограммы
    // 2. GPU:kernel:сборка частичных гистограмм в глобальную блочную память группы
    // 3. CPU/DSP:сборка групп гистограм в финальную из частичных блочных
    //
    private var threadgroups = MTLSizeMake(8,8,1)
    
    ///
    /// Конструктор анализатора с произвольным счетчиком, который
    /// задаем kernel-функцией. Главное условие совместимость с типом IMPHistogramBuffer
    /// как контейнером данных гистограммы.
    ///
    ///
    public init(context: IMPContext, function: String, hardware:IMPHistogramAnalyzer.Hardware = .GPU) {
        super.init(context: context)
        
        _hardware = hardware

        _kernel = IMPFunction(context: self.context, name:function)
        
        if context.hasFastAtomic() || hardware == .DSP
        {
            histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramBuffer), options: MTLResourceOptions.CPUCacheModeDefaultCache)
        }
        else {
            let groups = kernel.pipeline!.maxTotalThreadsPerThreadgroup/histogram.size
            threadgroups = MTLSizeMake(groups,groups,1)
            histogramUniformBuffer = self.context.device.newBufferWithLength(sizeof(IMPHistogramBuffer) * Int(threadgroups.width*threadgroups.height), options: .CPUCacheModeDefaultCache)
        }
        
        defer{
            region = IMPRegion(left: 0, right: 0, top: 0, bottom: 0)
            downScaleFactor = 1.0
            channelsToCompute = UInt(histogram.channels.count)
        }
    }
    
    convenience public init(context: IMPContext, hardware:IMPHistogramAnalyzer.Hardware) {
        
        var function = "kernel_impHistogramPartial"
        
        if hardware == .GPU {
            if context.hasFastAtomic() {
                function = "kernel_impHistogramAtomic"
            }
        }
        else {
            function = "kernel_impHistogramVImage"
        }
        
        self.init(context:context, function: function, hardware: hardware)
    }
    
    convenience required public init(context: IMPContext) {
        self.init(context:context, hardware: .GPU)
    }
    
    ///
    /// Замыкание выполняющаеся после завершения расчета значений солвера.
    /// Замыкание можно определить для обновления значений пользовательской цепочки фильтров.
    ///
    public func addUpdateObserver(observer:IMPAnalyzerUpdateHandler){
        analizerUpdateHandlers.append(observer)
    }
    
    private var analizerUpdateHandlers:[IMPAnalyzerUpdateHandler] = [IMPAnalyzerUpdateHandler]()
    
    ///
    /// Перегружаем свойство источника: при каждом обновлении нам нужно выполнить подсчет новой статистики.
    ///
    public override var source:IMPImageProvider?{
        didSet{
            super.source = source
            if source?.texture != nil {
                // выполняем фильтр
                self.apply()
            }
        }
    }
    
    public override var destination:IMPImageProvider?{
        get{
            return source
        }
    }
    
    func applyKernel(texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer, commandBuffer:MTLCommandBuffer) {
        #if os(iOS)
            var blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.fillBuffer(buffer, range: NSMakeRange(0, buffer.length), value: 0)
            blitEncoder.endEncoding()
        #else
            var blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.synchronizeResource(texture)
            blitEncoder.fillBuffer(buffer, range: NSMakeRange(0, buffer.length), value: 0)
            blitEncoder.endEncoding()
//            memset(buffer.contents(), 0, buffer.length)
        #endif
        
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        //
        // Создаем вычислительный пайп
        //
        commandEncoder.setComputePipelineState(self.kernel.pipeline!);
        commandEncoder.setTexture(texture, atIndex:0)
        commandEncoder.setBuffer(buffer, offset:0, atIndex:0)
        commandEncoder.setBuffer(self.channelsToComputeBuffer,offset:0, atIndex:1)
        commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, atIndex:2)
        commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, atIndex:3)
        
        self.configure(self.kernel, command: commandEncoder)
        
        //
        // Запускаем вычисления
        //
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts);
        commandEncoder.endEncoding()
        
        #if os(OSX)
            blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.synchronizeResource(buffer)
            blitEncoder.endEncoding()
        #endif
    }
    
    func applyPartialKernel(texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        self.context.execute(complete: true) { (commandBuffer) -> Void in
            self.applyKernel(texture,
                threadgroups: threadgroups,
                threadgroupCounts: threadgroupCounts,
                buffer: buffer,
                commandBuffer: commandBuffer)
        }
        histogram.update(data:histogramUniformBuffer.contents(), dataCount: threadgroups.width*threadgroups.height)
    }
    
    func applyAtomicKernel(texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        context.execute(complete: true) { (commandBuffer) in
            self.applyKernel(texture,
                threadgroups: threadgroups,
                threadgroupCounts: threadgroupCounts,
                buffer: buffer,
                commandBuffer: commandBuffer)
        }
        histogram.update(data: buffer.contents())
    }
    
    private var analizeTexture:MTLTexture?
    private var imageBuffer:MTLBuffer?
    
    func applyVImageKernel(texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        
        context.execute(complete: true) { (commandBuffer) in
            
            let width  = Int(floor(Float(texture.width) * self.downScaleFactor))
            let height = Int(floor(Float(texture.height) * self.downScaleFactor))
            
            if self.analizeTexture?.width != width || self.analizeTexture?.height != height {
                let textureDescription = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                    .RGBA8Unorm,
                    width: width,
                    height:height, mipmapped: false)
                self.analizeTexture = self.context.device.newTextureWithDescriptor(textureDescription)
            }
            
            if let actual = self.analizeTexture {
                
                let commandEncoder = commandBuffer.computeCommandEncoder()
                
                commandEncoder.setComputePipelineState(self.kernel.pipeline!);
                commandEncoder.setTexture(texture, atIndex:0)
                commandEncoder.setTexture(self.analizeTexture, atIndex:1)
                commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, atIndex:0)
                commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, atIndex:1)
                
                self.configure(self.kernel, command: commandEncoder)

                commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts);
                commandEncoder.endEncoding()
                
                let imageBufferSize = width*height*4
                
                if self.imageBuffer?.length != imageBufferSize {
                    self.imageBuffer = self.context.device.newBufferWithLength( imageBufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
                }
                
                if let data = self.imageBuffer {
                    
                    let blitEncoder = commandBuffer.blitCommandEncoder()
                    
                    #if os(OSX)
                    blitEncoder.synchronizeResource(actual)    
                    #endif
                    
                    blitEncoder.copyFromTexture(actual,
                                                sourceSlice: 0,
                                                sourceLevel: 0,
                                                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                                sourceSize: MTLSize(width: width, height: height, depth: actual.depth),
                                                toBuffer: data,
                                                destinationOffset: 0,
                                                destinationBytesPerRow: width*4,
                                                destinationBytesPerImage: 0)
                    
                    #if os(OSX)
                        blitEncoder.synchronizeResource(actual)    
                    #endif

                    blitEncoder.endEncoding()
                    
                    var vImage = vImage_Buffer(
                        data: data.contents(),
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width*4)
                    
                    vImageHistogramCalculation_ARGB8888(&vImage, self._vImage_hist, 0)
                    
                    self.histogram.update(red: self._vImage_red, green: self._vImage_green, blue: self._vImage_blue, alpha: self._vImage_alpha)
                }
            }
        }
    }

    static func _vImage_createChannel256() -> [vImagePixelCount] {
        return [vImagePixelCount](count: Int(kIMP_HistogramSize), repeatedValue: 0)
    }
    
    typealias _vImagePointer = UnsafeMutablePointer<vImagePixelCount>
    
    let _vImage_red   = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_green = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_blue  = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_alpha = IMPHistogramAnalyzer._vImage_createChannel256()

    lazy var _vImage_rgba:[_vImagePointer] = [
        _vImagePointer(self._vImage_red),
        _vImagePointer(self._vImage_green),
        _vImagePointer(self._vImage_blue),
        _vImagePointer(self._vImage_alpha)]
    
    lazy var _vImage_hist:UnsafeMutablePointer<_vImagePointer> = UnsafeMutablePointer<_vImagePointer>(self._vImage_rgba)
    
    public func executeSolverObservers(texture:MTLTexture) {
        for s in solvers {
            let size = CGSizeMake(CGFloat(texture.width), CGFloat(texture.height))
            s.analizerDidUpdate(self, histogram: self.histogram, imageSize: size)
        }
        
        for o in analizerUpdateHandlers{
            o(histogram: histogram)
        }
    }
    
    func computeOptions(texture:MTLTexture) -> (MTLSize,MTLSize) {
        let width  = Int(floor(Float(texture.width) * self.downScaleFactor))
        let height = Int(floor(Float(texture.height) * self.downScaleFactor))
        
        let threadgroupCounts = MTLSizeMake(Int(self.kernel.groupSize.width), Int(self.kernel.groupSize.height), 1)
        
        let threadgroups = MTLSizeMake(
            (width  +  threadgroupCounts.width ) / threadgroupCounts.width ,
            (height + threadgroupCounts.height) / threadgroupCounts.height,
            1)
        
        return (threadgroups,threadgroupCounts)
    }
    
    public override func apply() -> IMPImageProvider {
        
        if let texture = source?.texture{
            
            if hardware == .GPU {
                
                if context.hasFastAtomic() {
                    let (threadgroups,threadgroupCounts) = computeOptions(texture)
                    applyAtomicKernel(texture,
                                      threadgroups: threadgroups,
                                      threadgroupCounts: threadgroupCounts,
                                      buffer: histogramUniformBuffer)
                }
                else {
                    applyPartialKernel(
                        texture,
                        threadgroups: threadgroups,
                        threadgroupCounts: MTLSizeMake(histogram.size, 1, 1),
                        buffer: histogramUniformBuffer)
                }
            }
                
            else if hardware == .DSP {
                let (threadgroups,threadgroupCounts) = computeOptions(texture)
                applyVImageKernel(texture,
                                  threadgroups: threadgroups,
                                  threadgroupCounts: threadgroupCounts,
                                  buffer: histogramUniformBuffer)
            }
            
            executeSolverObservers(texture)
        }
        
        return source!
    }
}