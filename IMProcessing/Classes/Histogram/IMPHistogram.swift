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
    
    
    ///
    /// Фиксированная размерность гистограмы.
    ///
    public let size:Int
    
    /// Channels type: .PLANAR - one channel, XYZ - 3 channels, XYZW - 4 channels per histogram
    public let type:ChannelsType
    
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
    public init(){
        size = Int(kIMP_HistogramSize)
        type = .XYZW
        channels = [[Float]](count: Int(type.rawValue), repeatedValue: [Float](count: size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
    }
    
    ///  Create normal distributed histogram
    ///
    ///  - parameter fi:    fi
    ///  - parameter mu:    points of mu's
    ///  - parameter sigma: points of sigma's, must be the same number that is in mu's
    ///  - parameter size:  histogram size, by default is kIMP_HistogramSize
    ///  - parameter type:  channels type
    ///
    public init(gauss fi:Float, mu:[Float], sigma:[Float], size:Int = Int(kIMP_HistogramSize), type: ChannelsType){
        self.size = size
        self.type = type
        channels = [[Float]](count: Int(type.rawValue), repeatedValue: [Float](count: self.size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)

        let m = Float(size-1)
        
        for var c=0; c<channels.count; c++ {
            for var i=0; i<size; i++ {
                let v = Float(i)/m
                for var p=0; p<mu.count; p++ {
                    channels[c][i] += v.gaussianPoint(fi: fi, mu: mu[p], sigma: sigma[p])
                }
            }
            updateBinCountForChannel(c)
        }
    }
    

    public init(ramp:Range<Int>, size:Int = Int(kIMP_HistogramSize), type: ChannelsType = .XYZW){
        self.size = size
        self.type = type
        channels = [[Float]](count: Int(type.rawValue), repeatedValue: [Float](count: self.size, repeatedValue: 0))
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        for var c=0; c<channels.count; c++ {
            self.ramp(&channels[c], ramp: ramp)
            updateBinCountForChannel(c)
        }
    }
    
    ///
    /// Конструктор копии каналов.
    ///
    ///  - parameter channels: каналы с данными исходной гистограммы
    ///
    public init(channels:[[Float]]){
        self.size = channels[0].count
        switch channels.count {
        case 1:
            type = .PLANAR
        case 2:
            type = .XY
        case 3:
            type = .XYZ
        case 4:
            type = .XYZW
        default:
            fatalError("Number of channels is great then it posible: \(channels.count)")
        }
        self.channels = channels
        binCounts = [Float](count: Int(type.rawValue), repeatedValue: 0)
        for var c=0; c<channels.count; c++ {
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
                self.addFromData(&data, toChannel: &channels[c])
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
    
    
    ///
    /// Текущий CDF (комулятивная функция распределения) гистограммы.
    ///
    /// - parameter scale: масштабирование значений, по умолчанию CDF приводится к 1
    ///
    /// - returns: контейнер значений гистограммы с комулятивным распределением значений интенсивностей
    ///
    public func cdf(scale:Float = 1, power pow:Float=1) -> IMPHistogram {
        let _cdf = IMPHistogram(channels:channels);
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
    
    
    ///  Convolve histogram channel with filter presented another histogram distribution with phase-lead and scale.
    ///
    ///  - parameter channel: histogram which should be convolved
    ///  - parameter filter:  filter distribution
    ///  - parameter lead:    phase-lead in ticks of the histogram
    ///  - parameter scale:   scale
    public func convolve(channel c:ChannelNo, filter:IMPHistogram, lead:Int, scale:Float=1){
        
        if filter.size == 0 {
            return
        }
        
        let halfs = vDSP_Length(filter.size)
        var asize = size+filter.size*2
        var addata = [Float](count: asize, repeatedValue: 0)
        
        //
        // we need to supplement source distribution to apply filter right
        //
        vDSP_vclr(&addata, 1, vDSP_Length(asize))
        
        var zero = channels[c.rawValue][0]
        vDSP_vsadd(&addata, 1, &zero, &addata, 1, vDSP_Length(filter.size))
        
        var one  =  channels[c.rawValue][self.size-1]
        let rest = UnsafeMutablePointer<Float>(addata)+size+Int(halfs)
        vDSP_vsadd(rest, 1, &one, rest, 1, halfs-1)
        
        var addr = UnsafeMutablePointer<Float>(addata)+Int(halfs)
        let os = UnsafeMutablePointer<Float>(channels[c.rawValue])
        vDSP_vadd(os, 1, addr, 1, addr, 1, vDSP_Length(size))
        
        //
        // apply filter
        //
        asize = size+filter.size-1
        vDSP_conv(addata, 1, filter.channels[c.rawValue], 1, &addata, 1, vDSP_Length(asize), vDSP_Length(filter.size))
        
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
    
    public func random(scale scale:Float = 1) -> IMPHistogram {
        let h = IMPHistogram(ramp: 0..<size, size:size, type: type)
        for var c=0; c<h.channels.count; c++ {
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
    
    public func add(histogram:IMPHistogram){
        for var c=0; c<histogram.channels.count; c++ {
            addFromData(&histogram.channels[c], toChannel: &channels[c])
        }
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
        //
        // ковертим из единственно возможного в текущем MSL (atomic_)[uint] во [float]
        //
        vDSP_vfltu32(p, dim, &channel, 1, vDSP_Length(self.size));
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
    
    private func addFromData(inout data:[Float], inout toChannel:[Float]){
        vDSP_vadd(&toChannel, 1, &data, 1, &toChannel, 1, vDSP_Length(self.size))
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
