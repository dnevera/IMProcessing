//
//  IMPHistogramCube.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 28.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Accelerate
import simd

extension Array where Element: Comparable {
    var median: Element {
        return self.sort(<)[self.count/2]
    }
}

//extension IMPHistogramCube.Cube:Comparable{}
//extension IMPHistogramCube.Cell:Comparable{}

// func == (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
//    return lhs.value == rhs.value
//}
//
// func <= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
//    return lhs.value <= rhs.value
//}
//
// func > (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
//    return lhs.value > rhs.value
//}
//
// func < (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
//    return lhs.value < rhs.value
//}
//
// func >= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool{
//    return lhs.value >= rhs.value
//}

extension SequenceType where Generator.Element == IMPHistogramCube.LocalMaximum {
    var colors:[float3]{
        get{
            var v = [float3]()
            for lm in self{
                v.append(lm.color/255)
            }
            return v
        }
    }
}

public class IMPHistogramCube{
    
    internal struct Cell{
        var index:Int
        var value:Float
    }
    
    internal struct LocalMaximum{
        var count:Int
        var index:Int
        var color:float3
        var brightnes:Float
    }
    
    public struct Cube {
        
        public var cells:[IMPHistogramCubeCellFloat]
        public let dimensions:[Int]
        
        public init(){
            dimensions = [Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution)]
            let size = Int(dimensions[0]*dimensions[1]*dimensions[2])
            cells = [IMPHistogramCubeCellFloat](
                count: size,
                repeatedValue: IMPHistogramCubeCellFloat()
            )
        }
        
        public init(dimensions:[Int]){
            self.dimensions = dimensions
            let size = Int(dimensions[0]*dimensions[1]*dimensions[2])
            cells = [IMPHistogramCubeCellFloat](
                count: size,
                repeatedValue: IMPHistogramCubeCellFloat()
            )
        }
        
        func index(red:Int, green:Int, blue:Int) -> Int{
            return red+green*dimensions[0]+blue*dimensions[0]*dimensions[1]
        }
        
        public subscript(red:Int, green:Int, blue:Int) -> IMPHistogramCubeCellFloat {
            get{
                return cells[index(red,green: green,blue: blue)]
            }
            set {
                cells[index(red,green: green,blue: blue)] = newValue
            }
        }
        
        
        private var localMaxima:[LocalMaximum]{
            
            //
            // the main idea has been taken from: https://github.com/pixelogik/ColorCube
            //
            
            var maxima = [LocalMaximum]()
            
            for r in 0..<dimensions[0]{
                for g in 0..<dimensions[1]{
                    for b in 0..<dimensions[2]{
                        
                        let cell = self[r,g,b]
                        
                        let count = cell.count
                        if  count == 0 { continue }
                        
                        var isMaxima = true
                        
                        for n in 0..<27{
                            
                            let redIndex   = r+IMPHistogramCube.neighbours[n][0]
                            let greenIndex = g+IMPHistogramCube.neighbours[n][1]
                            let blueIndex  = b+IMPHistogramCube.neighbours[n][2]
                            
                            if (redIndex >= 0 && greenIndex >= 0 && blueIndex >= 0) {
                                if (redIndex < dimensions[0] && greenIndex < dimensions[1] && blueIndex < dimensions[2]) {
                                    if (self[redIndex, greenIndex, blueIndex].count > count) {

                                        isMaxima = false

                                        break
                                    }
                                }
                            }
                        }
                        
                        if !isMaxima { continue }
                        let idx   = index(r,green:g,blue:b)
                        let r     = cell.reds/cell.count
                        let g     = cell.greens/cell.count
                        let b     = cell.blues/cell.count
                        let brightnes = max(max(r, g), b)
                        let local = LocalMaximum(count: Int(count), index: idx, color: float3(r,g,b), brightnes: brightnes)

                        maxima.append(local)
                    }
                }
            }
            
            return maxima.sort{ $0.count>$1.count }
        }
        
        func distinctMaxima(maxima:[LocalMaximum], threshold:Float) -> [LocalMaximum] {
            
            var filtered = [LocalMaximum]()
            
            for var k = 0; k < maxima.count ; k++ {
                
                let max1 = maxima[k]
                var isDistinct = true
                
                for var n = 0; n<k; n++ {
                    let max2 = maxima[n]
                    
                    let delta = max1.color-max2.color
                    
                    let distance = sqrt(pow(delta.r, 2)+pow(delta.g,2)+pow(delta.b,2))
                    
                    if threshold>distance {
                        isDistinct = false
                        break
                    }
                }
            
                if isDistinct {
                    filtered.append(max1)
                }
            }
            
            return filtered
        }
        
        func filteredMaxima(maxima:[LocalMaximum], count:Int) -> [LocalMaximum] {
            
            if count>=maxima.count { return maxima }
            
            var filtered = maxima
            var temp     = [LocalMaximum]()
            var treshold = Float(0.1)
            
            for var k = 0 ; k<10 ; k++ {
                temp = distinctMaxima(filtered, threshold: treshold)
                if temp.count <= count {
                    break
                }
                filtered = temp
                treshold += 0.05
            }
            
            return [LocalMaximum](filtered[0..<count])
        }
        
        public func pallete(count count: Int) -> [float3] {
            let maximas = filteredMaxima(localMaxima,count: count)
            return maximas.colors
        }
        
    }
    
    public var cube   = Cube()
    public let size   = Int(kIMP_HistogramCubeSize)    
    
    public func updateWithData(dataIn: UnsafePointer<Void>, dataCount: Int){
        clearHistogram()
        var buffer = [IMPHistogramCubeCellFloat](count: size, repeatedValue: IMPHistogramCubeCellFloat())
        for i in 0..<dataCount {
            let dataIn = UnsafePointer<IMPHistogramCubeBuffer>(dataIn)+i
            clear(&buffer)
            updateCells(&buffer, address: dataIn)
            addCells(from: &buffer, to: &cube.cells)
        }
    }
    
    private let dim = sizeof(UInt32)/sizeof(simd.uint);
    
    private func updateCells(inout cells:[IMPHistogramCubeCellFloat], address:UnsafePointer<IMPHistogramCubeBuffer>){
        let p = UnsafePointer<UInt32>(address)
        let to = UnsafeMutablePointer<Float>(cells)
        vDSP_vfltu32(p, 1, to, 1, vDSP_Length(cells.count*4))
    }
    
    private func addCells(inout from from:[IMPHistogramCubeCellFloat], inout to:[IMPHistogramCubeCellFloat]){
        let tobuffer   = UnsafeMutablePointer<Float>(to)
        let frombuffer = UnsafeMutablePointer<Float>(from)
        vDSP_vadd(tobuffer, 1, frombuffer, 1, tobuffer, 1, vDSP_Length(to.count*4))
    }
    
    private func clear(inout cells:[IMPHistogramCubeCellFloat]){
        let buffer = UnsafeMutablePointer<Float>(cells)
        vDSP_vclr(buffer, 1, vDSP_Length(cells.count*4))
    }
    
    private func clearHistogram(){
        clear(&cube.cells)
    }
}

extension IMPHistogramCube {
    static let neighbours:[[Int]] = [
        [ 0, 0, 0],
        [ 0, 0, 1],
        [ 0, 0,-1],
        
        [ 0, 1, 0],
        [ 0, 1, 1],
        [ 0, 1,-1],
        
        [ 0,-1, 0],
        [ 0,-1, 1],
        [ 0,-1,-1],
        
        [ 1, 0, 0],
        [ 1, 0, 1],
        [ 1, 0,-1],
        
        [ 1, 1, 0],
        [ 1, 1, 1],
        [ 1, 1,-1],
        
        [ 1,-1, 0],
        [ 1,-1, 1],
        [ 1,-1,-1],
        
        [-1, 0, 0],
        [-1, 0, 1],
        [-1, 0,-1],
        
        [-1, 1, 0],
        [-1, 1, 1],
        [-1, 1,-1],
        
        [-1,-1, 0],
        [-1,-1, 1],
        [-1,-1,-1]
    ]
}