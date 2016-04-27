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
public enum IMPHistogramAnalizerHardware {
    case GPU
    case DSP
}

///
/// Common protocol defines histogram class API.
///
public protocol IMPHistogramAnalyzerProtocol:NSObjectProtocol,IMPFilterProtocol {
    
    var hardware:IMPHistogramAnalizerHardware {get}
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


extension IMPContext {
    func hasFastAtomic() -> Bool {
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
    
    ///
    /// Defines wich hardware uses to compute final histogram.
    /// DSP is faster but needs memory twice, GPU is slower but doesn't additanal memory.
    ///
    public var hardware:IMPHistogramAnalizerHardware {
        return _hardware
    }
    var _hardware:IMPHistogramAnalizerHardware!
    
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
    public init(context: IMPContext, function: String, hardware:IMPHistogramAnalizerHardware = .GPU) {
        super.init(context: context)

        _hardware = hardware

        // инициализируем счетчик
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
    
    convenience public init(context: IMPContext, hardware:IMPHistogramAnalizerHardware) {
        if hardware == .GPU {
            if context.hasFastAtomic() {
                self.init(context:context, function: "kernel_impHistogramAtomic", hardware: hardware)
            }
            else {
                self.init(context:context, function: "kernel_impHistogramPartial", hardware: hardware)
            }
        }
        else {
            self.init(context:context, function: "kernel_impHistogramVImage", hardware: hardware)
        }
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
            let blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.fillBuffer(buffer, range: NSMakeRange(0, buffer.length), value: 0)
            blitEncoder.endEncoding()
        #else
            memset(buffer.contents(), 0, buffer.length)
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
                    texture.pixelFormat,
                    width: width,
                    height:height, mipmapped: false)
                self.analizeTexture = self.context.device.newTextureWithDescriptor(textureDescription)
            }
            
            let commandEncoder = commandBuffer.computeCommandEncoder()
            
            commandEncoder.setComputePipelineState(self.kernel.pipeline!);
            commandEncoder.setTexture(texture, atIndex:0)
            commandEncoder.setTexture(self.analizeTexture, atIndex:1)
            commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, atIndex:0)
            commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, atIndex:1)
            
            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts);
            commandEncoder.endEncoding()
            
            let imageBufferSize = width*height*4
            if self.imageBuffer?.length != imageBufferSize {
                self.imageBuffer = self.context.device.newBufferWithLength( imageBufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
            }
            
            let blitEncoder = commandBuffer.blitCommandEncoder()
            
            blitEncoder.copyFromTexture(self.analizeTexture!,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: self.analizeTexture!.width, height: self.analizeTexture!.height, depth: 1),
                toBuffer: self.imageBuffer!,
                destinationOffset: 0,
                destinationBytesPerRow: width*4,
                destinationBytesPerImage: 0)
            blitEncoder.endEncoding()
        }
        
        var vImage = vImage_Buffer(
            data: (imageBuffer?.contents())!,
            height: vImagePixelCount(analizeTexture!.height),
            width: vImagePixelCount(analizeTexture!.width),
            rowBytes: analizeTexture!.width*4)
        
        let red   = [vImagePixelCount](count: Int(kIMP_HistogramSize), repeatedValue: 0)
        let green = [vImagePixelCount](count: Int(kIMP_HistogramSize), repeatedValue: 0)
        let blue  = [vImagePixelCount](count: Int(kIMP_HistogramSize), repeatedValue: 0)
        let alpha = [vImagePixelCount](count: Int(kIMP_HistogramSize), repeatedValue: 0)
        
        let redPtr   = UnsafeMutablePointer<vImagePixelCount>(red)
        let greenPtr = UnsafeMutablePointer<vImagePixelCount>(green)
        let bluePtr  = UnsafeMutablePointer<vImagePixelCount> (blue)
        let alphaPtr = UnsafeMutablePointer<vImagePixelCount>(alpha)
        
        let rgba = [redPtr, greenPtr, bluePtr, alphaPtr]
        
        let hist = UnsafeMutablePointer<UnsafeMutablePointer<vImagePixelCount>>(rgba)
        vImageHistogramCalculation_ARGB8888(&vImage, hist, 0)
        
        histogram.update(red: red, green: green, blue: blue, alpha: alpha)
    }
    
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