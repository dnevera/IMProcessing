//
//  IMPHistogram.swift
//  ImageMetalling-05
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
    
    ///
    /// Фиксированная размерность гистограмы. Всегда будем подразумевать 256.
    ///
    public let size = Int(kIMP_HistogramSize)
    
    ///
    /// Поканальная таблица счетов. Используем представление в числах с плавающей точкой.
    /// Нужно это для упрощения выполнения дополнительных акселерированных вычислений на DSP,
    /// поскольку все операции на DSP выполняются либо во float либо в double.
    ///
    public var channels:[[Float]];
    
    ///
    /// Конструктор пустой гистограммы.
    ///
    public init(){
        channels = [[Float]](count: Int(kIMP_HistogramMaxChannels), repeatedValue: [Float](count: Int(kIMP_HistogramSize), repeatedValue: 0))
    }
    
    public init(channels number:UInt){
        if number > UInt(kIMP_HistogramMaxChannels){
            fatalError("IMPHistogram could not be created with channels number great then \(kIMP_HistogramMaxChannels)")
        }
        channels = [[Float]](count: Int(number), repeatedValue: [Float](count: Int(kIMP_HistogramSize), repeatedValue: 0))
    }
    
    ///
    /// Конструктор копии каналов.
    ///
    ///  - parameter channels: каналы с данными исходной гистограммы
    ///
    public init(channels:[[Float]]){
        self.channels = channels
    }
    
    ///
    /// Метод обновления данных котейнера гистограммы.
    ///
    /// - parameter dataIn: обновить значение интенсивностей по сырым данным. Сырые данные должны быть преставлены в формате IMPHistogramBuffer.
    ///
    public func updateWithData(dataIn: UnsafePointer<Void>){
        clearHistogram()
        let address = UnsafePointer<UInt32>(dataIn)
        for c in 0..<channels.count{
            updateChannel(&channels[c], address: address, index: c)
        }
    }
    
    ///  Метод обновления сборки данных гистограммы из частичных гистограмм.
    ///
    ///  - parameter dataIn:    <#dataIn description#>
    ///  - parameter dataCount: <#dataCount description#>
    public func updateWithData(dataIn: UnsafePointer<Void>, dataCount: Int){
        self.clearHistogram()
        for i in 0..<dataCount{
            let dataIn = UnsafePointer<IMPHistogramBuffer>(dataIn)+i
            let address = UnsafePointer<UInt32>(dataIn)
            for c in 0..<channels.count{
                var data:[Float] = [Float](count: Int(self.size), repeatedValue: 0)
                self.updateChannel(&data, address: address, index: c)
                self.addFromData(&data, toChannel: &channels[c])
            }
        }
    }
    
    
    ///
    /// Текущий CDF (комулятивная функция распределения) гистограммы.
    ///
    /// - parameter scale: масштабирование значений, по умолчанию CDF приводится к 1
    ///
    /// - returns: контейнер значений гистограммы с комулятивным распределением значений интенсивностей
    ///
    public func cdf(scale:Float = 1, power pow:Float=1) ->IMPHistogram{
        let _cdf = IMPHistogram(channels:channels);
        for c in 0..<_cdf.channels.count{
            power(pow: pow, A: _cdf.channels[c], B: &_cdf.channels[c])
            integrate(A: &_cdf.channels[c], B: &_cdf.channels[c], size: _cdf.channels[c].count, scale:scale)
        }
        return _cdf;
    }

    ///  Текущий PDF (распределенией плотностей) гистограммы.
    ///
    ///  - parameter scale: <#scale description#>
    ///
    ///  - returns: <#return value description#>
    ///
    public func pdf(scale:Float = 1) -> IMPHistogram{
        let _pdf = IMPHistogram(channels:channels);
        for c in 0..<_pdf.channels.count{
            self.scale(A: &_pdf.channels[c], size: _pdf.channels[c].count, scale:scale)
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
    public func mean(channel index:Int) -> Float{
        let m = mean(A: &channels[index], size: channels[index].count)
        let denom = sum(A: &channels[index], size: channels[index].count)
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
    public func low(channel index:Int, clipping:Float) -> Float{
        let size = channels[index].count
        var low:vDSP_Length = search_clipping(channel: index, size: size, clipping: clipping)
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
    public func high(channel index:Int, clipping:Float) -> Float{
        let size = channels[index].count
        var high:vDSP_Length = search_clipping(channel: index, size: size, clipping: 1.0-clipping)
        high = high<vDSP_Length(size) ? high+1 : vDSP_Length(size)
        return Float(high)/Float(size)
    }
    
    
    //
    // Утилиты работы с векторными данными на DSP
    //
    // ..........................................
    
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
    private func search_clipping(channel index:Int, size:Int, clipping:Float) -> vDSP_Length {
        
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
        
        return position;
        
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
