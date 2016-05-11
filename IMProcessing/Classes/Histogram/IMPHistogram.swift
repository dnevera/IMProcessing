//
//  IMPHistogram.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 30.11.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Accelerate
import simd

///
/// Представление гистограммы для произвольного цветового пространства
/// с максимальным количеством каналов от одного до 4х.
///
public class IMPHistogram {
    
    public enum ChannelsType:Int{
        case PLANAR = 1
        case XY     = 2
        case XYZ    = 3
        case XYZW   = 4
    };
    
    public enum ChannelNo:Int{
        case X  = 0
        case Y  = 1
        case Z  = 2
        case W  = 3
    };
    
    public enum DistributionType:Int{
        case SOURCE = 0
        case CDF = 1
    }
    
    ///
    /// Histogram width
    ///
    public let size:Int
    
    /// Channels type: .PLANAR - one channel, XYZ - 3 channels, XYZW - 4 channels per histogram
    public let type:ChannelsType
    
    
    private var _distributionType:DistributionType = .SOURCE
    public var distributionType:DistributionType {
        return  _distributionType
    }
    
    
    ///
    /// Поканальная таблица счетов. Используем представление в числах с плавающей точкой.
    /// Нужно это для упрощения выполнения дополнительных акселерированных вычислений на DSP,
    /// поскольку все операции на DSP выполняются либо во float либо в double.
    ///
    public var channels:[[Float]]
    
    public subscript(channel:ChannelNo)->[Float]{
        get{
            return channels[channel.rawValue]
        }
    }
    
    private var binCounts:[Float]
    public func binCount(channel:ChannelNo)->Float{
        return binCounts[channel.rawValue]
    }
    
    ///
    /// Конструктор пустой гистограммы.
    ///
    public init(size:Int = Int(kIMP_HistogramSize), type:ChannelsType = .XYZW, distributionType:DistributionType = .SOURCE){
        self.size = size
        self.type = type
        channels = [[Float]](count: Int(type.rawValue), repeatedValue: [Float](count: size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        _distributionType = distributionType
    }
    
    ///  Create normal distributed histogram
    ///
    ///  - parameter fi:    fi
    ///  - parameter mu:    points of mu's
    ///  - parameter sigma: points of sigma's, must be the same number that is in mu's
    ///  - parameter size:  histogram size, by default is kIMP_HistogramSize
    ///  - parameter type:  channels type
    ///
    public init(gauss fi:Float, mu:[Float], sigma:[Float], size:Int = Int(kIMP_HistogramSize), type: ChannelsType = .XYZW){
        self.size = size
        self.type = type
        channels = [[Float]](count: Int(type.rawValue), repeatedValue: [Float](count: self.size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)

        let m = Float(size-1)
        
        for c in 0 ..< channels.count {
            for i in 0 ..< size {
                let v = Float(i)/m
                for p in 0 ..< mu.count {
                    channels[c][i] += v.gaussianPoint(fi: fi, mu: mu[p], sigma: sigma[p])
                }
            }
            updateBinCountForChannel(c)
        }
    }
    

    public init(ramp:Range<Int>, size:Int = Int(kIMP_HistogramSize), type: ChannelsType = .XYZW){
        self.size = size
        self.type = type
        channels = [[Float]](
            count: Int(type.rawValue), repeatedValue: [Float](count: self.size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        for c in 0 ..< channels.count {
            self.ramp(&channels[c], ramp: ramp)
            updateBinCountForChannel(c)
        }
    }
    
    ///
    /// Конструктор копии каналов.
    ///
    ///  - parameter channels: каналы с данными исходной гистограммы
    ///
    public init(channels ch:[[Float]]){
        self.size = ch[0].count
        switch ch.count {
        case 1:
            type = .PLANAR
        case 2:
            type = .XY
        case 3:
            type = .XYZ
        case 4:
            type = .XYZW
        default:
            fatalError("Number of channels is great then it posible: \(ch.count)")
        }
        channels = [[Float]](count: type.rawValue, repeatedValue: [Float](count: size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        for c in 0 ..< channels.count {
            for i in 0..<ch[c].count {
                channels[c][i] = ch[c][i]
            }
            updateBinCountForChannel(c)
        }
    }
    
    public init(histogram:IMPHistogram){
        size = histogram.size
        type = histogram.type
        channels = [[Float]](count: type.rawValue, repeatedValue: [Float](count: size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        for c in 0 ..< channels.count {
            for i in 0..<histogram.channels[c].count {
                channels[c][i] = histogram.channels[c][i]
            }
            updateBinCountForChannel(c)
        }
    }
    
    ///
    /// Метод обновления данных котейнера гистограммы.
    ///
    /// - parameter dataIn: обновить значение интенсивностей по сырым данным. Сырые данные должны быть преставлены в формате IMPHistogramBuffer.
    ///
    public func update(data dataIn: UnsafePointer<Void>){
        clearHistogram()
        let address = UnsafePointer<UInt32>(dataIn)
        for c in 0..<channels.count{
            updateChannel(&channels[c], address: address, index: c)
            updateBinCountForChannel(c)
        }
    }
    
    ///  Метод обновления сборки данных гистограммы из частичных гистограмм.
    ///
    ///  - parameter dataIn:
    ///  - parameter dataCount:
    public func update(data dataIn: UnsafePointer<Void>, dataCount: Int){
        self.clearHistogram()
        for i in 0..<dataCount{
            let dataIn = UnsafePointer<IMPHistogramBuffer>(dataIn)+i
            let address = UnsafePointer<UInt32>(dataIn)
            for c in 0..<channels.count{
                var data:[Float] = [Float](count: Int(self.size), repeatedValue: 0)
                self.updateChannel(&data, address: address, index: c)
                self.addFromData(data, toChannel: &channels[c])
                updateBinCountForChannel(c)
            }
        }
    }
    
    public func update(channel:ChannelNo, fromHistogram:IMPHistogram, fromChannel:ChannelNo) {
        if fromHistogram.size != size {
            fatalError("Histogram sizes are not equal: \(size) != \(fromHistogram.size)")
        }
        
        let address = UnsafeMutablePointer<Float>(channels[channel.rawValue])
        let from_address = UnsafeMutablePointer<Float>(fromHistogram.channels[fromChannel.rawValue])
        vDSP_vclr(address, 1, vDSP_Length(size))
        vDSP_vadd(address, 1, from_address, 1, address, 1, vDSP_Length(size));
        updateBinCountForChannel(channel.rawValue)
    }
    
    
    public func updateWithConinuesData(dataIn: UnsafeMutablePointer<UInt32>){
        self.clearHistogram()
        let address = UnsafePointer<UInt32>(dataIn)
        for c in 0..<channels.count{
            self.updateContinuesData(&channels[c], address: address, index: c)
        }
    }

    public func update(red red:[vImagePixelCount], green:[vImagePixelCount], blue:[vImagePixelCount], alpha:[vImagePixelCount]){
        self.clearHistogram()
        self.updateChannel(&channels[0], address: red,   index: 0)
        self.updateChannel(&channels[1], address: green, index: 0)
        self.updateChannel(&channels[2], address: blue,  index: 0)
        self.updateChannel(&channels[3], address: alpha, index: 0)
        for c in 0..<channels.count{
            updateBinCountForChannel(c)
        }
    }
    
    ///
    /// Текущий CDF (комулятивная функция распределения) гистограммы.
    ///
    /// - parameter scale: масштабирование значений, по умолчанию CDF приводится к 1
    ///
    /// - returns: контейнер значений гистограммы с комулятивным распределением значений интенсивностей
    ///
    public func cdf(scale:Float = 1, power pow:Float=1) -> IMPHistogram {
        let _cdf = IMPHistogram(channels:channels);
        _cdf._distributionType = .CDF
        for c in 0..<_cdf.channels.count{
            power(pow: pow, A: _cdf.channels[c], B: &_cdf.channels[c])
            integrate(A: &_cdf.channels[c], B: &_cdf.channels[c], size: _cdf.channels[c].count, scale:scale)
            _cdf.updateBinCountForChannel(c)
        }
        return _cdf;
    }
    
    ///  Текущий PDF (распределенией плотностей) гистограммы.
    ///
    ///  - parameter scale: scale
    ///
    ///  - returns: return value histogram
    ///
    public func pdf(scale:Float = 1) -> IMPHistogram {
        let _pdf = IMPHistogram(channels:channels);
        for c in 0..<_pdf.channels.count{
            self.scale(A: &_pdf.channels[c], size: _pdf.channels[c].count, scale:scale)
            _pdf.updateBinCountForChannel(c)
        }
        return _pdf;
    }
    
    ///
    /// Среднее значение интенсивностей канала с заданным индексом.
    /// Возвращается значение нормализованное к 1.
    ///
    /// - parameter index: индекс канала начиная от 0
    ///
    /// - returns: нормализованное значние средней интенсивности канала
    ///
    public func mean(channel index:ChannelNo) -> Float{
        let m = mean(A: &channels[index.rawValue], size: channels[index.rawValue].count)
        let denom = sum(A: &channels[index.rawValue], size: channels[index.rawValue].count)
        return m/denom
    }
    
    ///
    /// Минимальное значение интенсивности в канале с заданным клипингом.
    ///
    /// - parameter index:    индекс канала
    /// - parameter clipping: значение клиппинга интенсивностей в тенях
    ///
    /// - returns: Возвращается значение нормализованное к 1.
    ///
    public func low(channel index:ChannelNo, clipping:Float) -> Float{
        let size = channels[index.rawValue].count
        var (low,p) = search_clipping(channel: index.rawValue, size: size, clipping: clipping)
        if p == 0 { low = 0 }
        low = low>0 ? low-1 : 0
        return Float(low)/Float(size)
    }
    
    
    ///
    /// Максимальное значение интенсивности в канале с заданным клипингом.
    ///
    /// - parameter index:    индекс канала
    /// - parameter clipping: значение клиппинга интенсивностей в светах
    ///
    /// - returns: Возвращается значение нормализованное к 1.
    ///
    public func high(channel index:ChannelNo, clipping:Float) -> Float{
        let size = channels[index.rawValue].count
        var (high,p) = search_clipping(channel: index.rawValue, size: size, clipping: 1.0-clipping)
        if p == 0 { high = vDSP_Length(size) }
        high = high<vDSP_Length(size) ? high+1 : vDSP_Length(size)
        return Float(high)/Float(size)
    }
        
    /// 
    /// Look up interpolated values by indeces in the histogram
    ///
    ///
    public func lookup(values:[Float], channel index:ChannelNo) -> [Float] {
        var lookup = self[index]
        var b = values
        return interpolate(&lookup, b: &b)
    }
    
    func interpolate(inout a: [Float], inout b: [Float]) -> [Float] {
        var c = [Float](count: b.count, repeatedValue: 0)
        vDSP_vlint(&a, &b, 1, &c, 1, UInt(b.count), UInt(a.count))
        return c
    }

    ///  Convolve histogram channel with filter presented another histogram distribution with phase-lead and scale.
    ///
    ///  - parameter filter:  filter distribution histogram
    ///  - parameter lead:    phase-lead in ticks of the histogram
    ///  - parameter scale:   scale
    public func convolve(filter:IMPHistogram, lead:Int, scale:Float=1){
        for c in 0 ..< channels.count {
            convolve(filter.channels[c], channel: ChannelNo(rawValue: c)!, lead: lead, scale: scale)
        }
    }
    
    ///  Convolve histogram channel with filter distribution with phase-lead and scale.
    ///
    ///  - parameter filter:  filter distribution
    ///  - parameter channel: histogram which should be convolved
    ///  - parameter lead:    phase-lead in ticks of the histogram
    ///  - parameter scale:   scale
    public func convolve(filter:[Float], channel c:ChannelNo, lead:Int, scale:Float=1){
        
        if filter.count == 0 {
            return
        }
        
        let halfs = vDSP_Length(filter.count)
        var asize = size+filter.count*2
        var addata = [Float](count: asize, repeatedValue: 0)
        
        //
        // we need to supplement source distribution to apply filter right
        //
        vDSP_vclr(&addata, 1, vDSP_Length(asize))
        
        var zero = channels[c.rawValue][0]
        vDSP_vsadd(&addata, 1, &zero, &addata, 1, vDSP_Length(filter.count))
        
        var one  =  channels[c.rawValue][self.size-1]
        let rest = UnsafeMutablePointer<Float>(addata)+size+Int(halfs)
        vDSP_vsadd(rest, 1, &one, rest, 1, halfs-1)
        
        var addr = UnsafeMutablePointer<Float>(addata)+Int(halfs)
        let os = UnsafeMutablePointer<Float>(channels[c.rawValue])
        vDSP_vadd(os, 1, addr, 1, addr, 1, vDSP_Length(size))
        
        //
        // apply filter
        //
        asize = size+filter.count-1
        vDSP_conv(addata, 1, filter, 1, &addata, 1, vDSP_Length(asize), vDSP_Length(filter.count))
        
        //
        // normalize coordinates
        //
        addr = UnsafeMutablePointer<Float>(addata)+lead
        memcpy(os, addr, size*sizeof(Float))
        
        var left = -channels[c.rawValue][0]
        vDSP_vsadd(os, 1, &left, os, 1, vDSP_Length(size))
        
        //
        // normalize
        //
        var denom:Float = 0
        
        if (scale>0) {
            vDSP_maxv (os, 1, &denom, vDSP_Length(size))
            denom /= scale
            vDSP_vsdiv(os, 1, &denom, os, 1, vDSP_Length(size))
        }
        
        updateBinCountForChannel(c.rawValue)
    }
    
    ///  Generate random distributed values and creat from it a histogram instance
    ///
    ///  - parameter scale: scale value
    ///
    ///  - returns: a random distributed histogram
    public func random(scale scale:Float = 1) -> IMPHistogram {
        let h = IMPHistogram(ramp: 0..<size, size:size, type: type)
        for c in 0 ..< h.channels.count {
            var data  = [UInt8](count: h.size, repeatedValue: 0)
            SecRandomCopyBytes(kSecRandomDefault, data.count, &data)
            h.channels[c] = [Float](count: h.size, repeatedValue: 0)
            
            let addr = UnsafeMutablePointer<Float>(h.channels[c])
            let sz   = vDSP_Length(h.channels[c].count)
            vDSP_vfltu8(data, 1,  addr, 1, sz);
            
            if scale > 0 {
                var denom:Float = 0;
                vDSP_maxv (addr, 1, &denom, sz);
                
                denom /= scale
                
                vDSP_vsdiv(addr, 1, &denom, addr, 1, sz);
            }
            
        }
        return h
    }
    
    ///  Add a histogram to the self
    ///
    ///  - parameter histogram: another histogram
    public func add(histogram:IMPHistogram){
        for c in 0 ..< histogram.channels.count {
            addFromData(histogram.channels[c], toChannel: &channels[c])
        }
    }

    ///  Add values to the histogram channel
    ///
    ///  - parameter values:  array of values, should have the equal size of the histogrram
    ///  - parameter channel: channel number
    public func add(values:[Float], channel:ChannelNo){
        if values.count != size {
            fatalError("IMPHistogram: source and values vector must have equal size")
        }
        addFromData(values, toChannel: &channels[channel.rawValue])
    }
    
    ///  Multiply two histograms
    ///
    ///  - parameter histogram: another histogram
    public func mul(histogram:IMPHistogram){
        for c in 0 ..< histogram.channels.count {
            mulFromData(histogram.channels[c], toChannel: &channels[c])
        }
    }
    
    ///  Multyply a histogram channel by vector of values
    ///
    ///  - parameter values: array of values
    ///  - parameter channel: histogram channel number
    public func mul(values:[Float], channel:ChannelNo){
        if values.count != size {
            fatalError("IMPHistogram: source and values vector must have equal size")
        }
        mulFromData(values, toChannel: &channels[channel.rawValue])
    }
    

    //
    // Утилиты работы с векторными данными на DSP
    //
    // ..........................................
    
    private func updateBinCountForChannel(channel:Int){
        var denom:Float = 0
        let c = channels[channel]
        vDSP_sve(c, 1, &denom, vDSP_Length(c.count))
        binCounts[channel] = denom
    }
    
    //
    // Реальная размерность беззнакового целого. Может отличаться в зависимости от среды исполнения.
    //
    private let dim = sizeof(UInt32)/sizeof(simd.uint);
    
    //
    // Обновить данные контейнера гистограммы и сконвертировать из UInt во Float
    //
    private func updateChannel(inout channel:[Float], address:UnsafePointer<UInt32>, index:Int){
        let p = address+Int(self.size)*Int(index)
        let dim = self.dim<1 ? 1 : self.dim;
        vDSP_vfltu32(p, dim, &channel, 1, vDSP_Length(size))
    }
    
    private func updateChannel(inout channel:[Float], address:UnsafePointer<vImagePixelCount>, index:Int){
        let p = UnsafePointer<UInt32>(address+Int(self.size)*Int(index))
        let dim = sizeof(vImagePixelCount)/sizeof(UInt32);
        vDSP_vfltu32(p, dim, &channel, 1, vDSP_Length(size));
    }
    
    
    private func updateContinuesData(inout channel:[Float], address:UnsafePointer<UInt32>, index:Int){
        let p = address+Int(size)*index
        vDSP_vfltu32(p, 1, &channel, 1, vDSP_Length(size))
    }
    
    //
    // Поиск индекса отсечки клипинга
    //
    private func search_clipping(channel index:Int, size:Int, clipping:Float) -> (vDSP_Length,vDSP_Length) {
        
        if tempBuffer.count != size {
            tempBuffer = [Float](count: size, repeatedValue: 0)
        }
        
        //
        // интегрируем сумму
        //
        integrate(A: &channels[index], B: &tempBuffer, size: size, scale:1)
        
        var cp  = clipping
        var one = Float(1)
        
        //
        // Отсекаем точку перехода из минимума в остальное
        //
        vDSP_vthrsc(&tempBuffer, 1, &cp, &one, &tempBuffer, 1, vDSP_Length(size))
        
        var position:vDSP_Length = 0
        var all:vDSP_Length = 0
        
        //
        // Ищем точку пересечения с осью
        //
        vDSP_nzcros(tempBuffer, 1, 1, &position, &all, vDSP_Length(size))
        
        return (position,all);
        
    }
    
    //
    // Временные буфер под всякие конвреторы
    //
    private var tempBuffer:[Float] = [Float]()
    
    //
    // Распределение абсолютных значений интенсивностей гистограммы в зависимости от индекса
    //
    private var intensityDistribution:(Int,[Float])!
    //
    // Сборка распределения интенсивностей
    //
    private func createIntensityDistribution(size:Int) -> (Int,[Float]){
        let m:Float    = Float(size-1)
        var h:[Float]  = [Float](count: size, repeatedValue: 0)
        var zero:Float = 0
        var v:Float    = 1.0/m
        
        // Создает вектор с монотонно возрастающими или убывающими значениями
        vDSP_vramp(&zero, &v, &h, 1, vDSP_Length(size))
        return (size,h);
    }
    
    private func ramp(inout C:[Float], ramp:Range<Int>){
        let m:Float    = Float(C.count-1)
        var zero:Float = Float(ramp.startIndex)/m
        var v:Float    = Float(ramp.endIndex-ramp.startIndex)/m
        vDSP_vramp(&zero, &v, &C, 1, vDSP_Length(C.count))
    }
    //
    // Вычисление среднего занчения распределния вектора
    //
    private func mean(inout A A:[Float], size:Int) -> Float {
        intensityDistribution = intensityDistribution ?? self.createIntensityDistribution(size)
        if intensityDistribution.0 != size {
            intensityDistribution = self.createIntensityDistribution(size)
        }
        if tempBuffer.count != size {
            tempBuffer = [Float](count: size, repeatedValue: 0)
        }
        //
        // Перемножаем два вектора вектор
        //
        vDSP_vmul(&A, 1, &intensityDistribution.1, 1, &tempBuffer, 1, vDSP_Length(size))
        return sum(A: &tempBuffer, size: size)
    }
    
    //
    // Вычисление скалярной суммы вектора
    //
    private func sum(inout A A:[Float], size:Int) -> Float {
        var sum:Float = 0
        vDSP_sve(&A, 1, &sum, vDSP_Length(self.size));
        return sum
    }
    
    private func power(pow pow:Float, A:[Float], inout B:[Float]){
        var y = pow;
        var sz:Int32 = Int32(size);
        // Set z[i] to pow(x[i],y) for i=0,..,n-1
        // void vvpowsf (float * /* z */, const float * /* y */, const float * /* x */, const int * /* n */)
        var a = A
        vvpowsf(&B, &y, &a, &sz);
    }
    
    
    //
    // Вычисление интегральной суммы вектора приведенной к определенной размерности задаваймой
    // параметом scale
    //
    private func integrate(inout A A:[Float], inout B:[Float], size:Int, scale:Float){
        var one:Float = 1
        let rsize = vDSP_Length(size)
        
        vDSP_vrsum(&A, 1, &one, &B, 1, rsize)
        
        if scale > 0 {
            var denom:Float = 0;
            vDSP_maxv (&B, 1, &denom, rsize);
            
            denom /= scale
            
            vDSP_vsdiv(&B, 1, &denom, &B, 1, rsize);
        }
    }
    
    private func scale(inout A A:[Float], size:Int, scale:Float){
        let rsize = vDSP_Length(size)
        if scale > 0 {
            var denom:Float = 0;
            vDSP_maxv (&A, 1, &denom, rsize);
            
            denom /= scale
            
            vDSP_vsdiv(&A, 1, &denom, &A, 1, rsize);
        }
    }
    
    private func addFromData(data:[Float], inout toChannel:[Float]){
        vDSP_vadd(&toChannel, 1, data, 1, &toChannel, 1, vDSP_Length(self.size))
    }
    
    private func mulFromData(data:[Float], inout toChannel:[Float]){
        vDSP_vmul(&toChannel, 1, data, 1, &toChannel, 1, vDSP_Length(self.size))
    }
    
    private func clearChannel(inout channel:[Float]){
        vDSP_vclr(&channel, 1, vDSP_Length(self.size))
    }
    
    private func clearHistogram(){
        for c in 0..<channels.count{
            clearChannel(&channels[c]);
        }
    }
    
}

// MARK: - Statistical measurements
public extension IMPHistogram {
    public func entropy(channel index:ChannelNo) -> Float{
        var e:Float = 0
        let sum     = binCount(index)
        for i in 0 ..< size {
            let Hc = self[index][i]
            if Hc > 0 {
                e += -(Hc/sum) * log2(Hc/sum);
            }
        }
        return e
    }
}

// MARK: - Peaks and valleys
public extension IMPHistogram{
    
    public struct Extremum {
        public let i:Int
        public let y:Float
        public init(i:Int,y:Float){
            self.i = i
            self.y = y
        }
    }
    
    convenience init(ƒ:Float, µ:Float, ß:Float){
        self.init(gauss: ƒ, mu: [µ], sigma: [ß], size: ß.int*2, type: .PLANAR)
    }
    
    ///  Find local suffisient peeks of the histogram channel
    ///
    ///  - parameter channel: channel no
    ///  - parameter window:  window size
    ///
    ///  - returns: array of extremums
    ///
    ///  Source: http://stackoverflow.com/questions/22169492/number-of-peaks-in-histogram
    ///
    public func peaks(channel channel:ChannelNo, window:Int = 5, threshold:Float = 0 )  -> [Extremum] {
        
        let N        = window
        let xt:Float = N.float
        let yt:Float = threshold > 0 ? threshold : 1/size.float
        
        // Result indices
        var indices = [Extremum]()
        
        let avrg    = IMPHistogram(channels: [[Float](count: N, repeatedValue: 1/N.float)])
        
        // Copy self histogram to avoid smothing effect for itself
        let src     = IMPHistogram(channels: [self[channel]])
        
        // Convolve gaussian filter with filter 3ß
        src.convolve(avrg[.X], channel: .X, lead: N/2+N%2)
        
        // Analyzed histogram channel
        let y       = src[.X]
        
        // Find all local maximas
        var imax = 0
        var  max = y[0]
        
        var inc = true
        var dec = false
        
        for i in 1 ..< y.count {
            
            // Changed from decline to increase, reset maximum
            if (dec && y[i - 1] < y[i]) {
                max = 0
                dec = false
                inc = true
            }
            
            // Changed from increase to decline, save index of maximum
            if (inc && y[i - 1] > y[i]) {
                indices.append(Extremum(i: imax, y: max));
                dec = true
                inc = false
            }
            
            // Update maximum
            if (y[i] > max) {
                max = y[i]
                imax = i
            }
        }
        
        // If peak size is too small, ignore it
        var i = 0
        while (indices.count >= 1 && i < indices.count) {
            if (y[indices[i].i] < yt) {
                indices.removeAtIndex(i)
            } else {
                i += 1
            }
        }
        
        // If two peaks are near to each other, take nly the largest one
        i = 1;
        while (indices.count >= 2 && i < indices.count) {
            let index1 = indices[i - 1].i
            let index2 = indices[i].i
            if (abs(index1 - index2).float < xt) {
                indices.removeAtIndex(y[index1] < y[index2] ? i-1 : i)
            } else {
                i += 1
            }
        }
        return indices;
    }
    
    ///  Get histogram channel multipeak mean
    ///
    ///  - parameter channel: channel no
    ///  - parameter window:  window size
    ///
    ///  - returns: mean value
    public func peaksMean(channel channel:ChannelNo, window:Int = 5, threshold:Float = 0 ) -> Float {
        
        let p         = peaks(channel: channel, window: window, threshold: threshold)
        var sum:Float = 0
        for i in p {
            sum += i.y * i.i.float
        }
        
        return sum/p.count.float/size.float
    }
}


// MARK: - Histogram matching
public extension IMPHistogram{
    
    ///  Match histogram by vector values
    ///
    ///  - parameter values:  vector values
    ///  - parameter channel: channel number
    ///
    ///  - returns: matched histogram instance has .PLANAR type and .CDF distribution type
    public func match(inout values:[Float], channel:ChannelNo) -> IMPHistogram {
        if values.count != size {
            fatalError("IMPHistogram: source and values vector histograms must have equal size")
        }
        
        var outcdf = IMPHistogram(size: size, type: .PLANAR, distributionType:.CDF)
        if distributionType == .CDF {
            matchData(&values, target: &channels[channel.rawValue], outcdf: &outcdf, c:0)
        }
        else {
            matchData(&values, target: &cdf().channels[channel.rawValue], outcdf: &outcdf, c:0)
        }
        return outcdf
    }
    
    ///  Match two histogram
    ///
    ///  - parameter histogram: source specification histogram
    ///
    ///  - returns: matched histogram instance has .CDF distribution type
    public func match(histogram:IMPHistogram) -> IMPHistogram {
        if histogram.size != size {
            fatalError("IMPHistogram: source and target histograms must have equal size")
        }
        
        if histogram.channels.count != channels.count {
            fatalError("IMPHistogram: source and target histograms must have equal channels count")
        }
        
        var outcdf = IMPHistogram(size: size, type: type, distributionType:.CDF)
        
        var source:IMPHistogram!
        
        if histogram.distributionType == .CDF {
            source = self
        }
        else{
            source = cdf()
        }
        
        var target:IMPHistogram!
        if distributionType == .CDF {
            target = histogram
        }
        else{
            target = histogram.cdf()
        }
        
        for c in 0 ..< channels.count {
            
            matchData(&source.channels[c], target: &target.channels[c], outcdf: &outcdf, c: c)
            
            ////                j=size-1
            ////                repeat {
            ////                    outcdf.channels[c][i] = j.float/(outcdf.size.float-1); j--
            ////                } while (j>=0 && source[i] <= target[j] );
        }
        
        return outcdf
    }

    private func matchData(inout source:[Float], inout target:[Float], inout outcdf:IMPHistogram, c:Int) {
        
        var j=0
        let denom = (outcdf.size.float-1)
        
        for i in 0 ..< source.count {
            if j >= target.count {
                continue
            }
            if source[i] <= target[j] {
                outcdf.channels[c][i] = j.float/denom
            }
            else {
                while source[i] > target[j] {
                    j += 1;
                    if j >= target.count {
                        break
                    }
                    if (target[j] - source[i]) > (source[i] - target[j-1] )  {
                        outcdf.channels[c][i] = j.float/denom
                    }
                    else{
                        outcdf.channels[c][i] = (j.float - 1)/denom
                    }
                }
            }
        }
    }
}


public extension CollectionType where Generator.Element == IMPHistogram.Extremum {
    ///
    /// Get mean of IMPHistogram peaks
    ///
    public func mean() -> Float {
        var sum:Float = 0
        for i in self {
            sum += i.y * i.i.float
        }
        return sum/(self.count as! Int).float
    }
}

