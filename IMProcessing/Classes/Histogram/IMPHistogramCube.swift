//
//  IMPHistogramCube.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 28.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Accelerate
import simd

extension IMPHistogramCube.Cube:Comparable{}

public func == (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxDimension.dimension == rhs.maxDimension.dimension
}

public func <= (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxDimension.dimension <= rhs.maxDimension.dimension
}

public func > (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxDimension.dimension > rhs.maxDimension.dimension
}

public func < (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxDimension.dimension < rhs.maxDimension.dimension
}

public func >= (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool{
    return lhs.maxDimension.dimension >= rhs.maxDimension.dimension
}


extension IMPHistogramCube.Cell:Comparable{}

func == (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.count == rhs.count
}

func <= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.count <= rhs.count
}

func > (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.count > rhs.count
}

func < (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.count < rhs.count
}

func >= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool{
    return lhs.count >= rhs.count
}

extension IMPHistogramCubeCell:Comparable{}

public func == (lhs: IMPHistogramCubeCell, rhs: IMPHistogramCubeCell) -> Bool {
    return lhs.count == rhs.count
}

public func <= (lhs: IMPHistogramCubeCell, rhs: IMPHistogramCubeCell) -> Bool {
    return lhs.count <= rhs.count
}

public func > (lhs: IMPHistogramCubeCell, rhs: IMPHistogramCubeCell) -> Bool {
    return lhs.count > rhs.count
}

public func < (lhs: IMPHistogramCubeCell, rhs: IMPHistogramCubeCell) -> Bool {
    return lhs.count < rhs.count
}

public func >= (lhs: IMPHistogramCubeCell, rhs: IMPHistogramCubeCell) -> Bool{
    return lhs.count >= rhs.count
}


extension SequenceType where Generator.Element == IMPHistogramCube.LocalMaximum {
    var colors:[float3]{
        get{
            var v = [float3]()
            for lm in self{
                v.append(lm.color)
            }
            return v
        }
    }
}

/// Cube RGB-Histogram presentation
public class IMPHistogramCube{
    
    ///  @brief Cube Histogram cell uses in median-cut
    internal struct Cell{
        var index:Int
        var count:Float
    }
    
    ///  @brief Local maximum cell presentation
    internal struct LocalMaximum{
        var count:Int
        var index:Int
        var color:float3
        var brightnes:Float
    }
    
    ///  @brief RGB-Cube is a statistics accumulator.
    public struct Cube {
        
        /// Red minimum presents lower corner of the RGB-Cube
        public var rmin:Int = 0
        /// Red maximum presents higher corner of the RGB-Cube
        public var rmax:Int = Int(kIMP_HistogramCubeResolution)
        /// Green minimum presents lower corner of the RGB-Cube
        public var gmin:Int = 0
        /// Green maximum presents higher corner of the RGB-Cube
        public var gmax:Int = Int(kIMP_HistogramCubeResolution)
        /// Blue minimum presents lower corner of the RGB-Cube
        public var bmin:Int = 0
        /// Blue maximum presents higher corner of the RGB-Cube
        public var bmax:Int = Int(kIMP_HistogramCubeResolution)
        
        /// RGB-Cube statistics
        public var cells:[IMPHistogramCubeCell]
        public let dimensions:[Int]
        
        public init(){
            dimensions = [Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution)]
            let size = Int(dimensions[0]*dimensions[1]*dimensions[2])
            cells = [IMPHistogramCubeCell](
                count: size,
                repeatedValue: IMPHistogramCubeCell()
            )
        }
        
        public init(dimensions:[Int], rmin:Int, gmin:Int, bmin:Int){
            self.dimensions = dimensions
            
            self.rmin = rmin
            self.gmin = gmin
            self.bmin = bmin
            self.rmax = rmin+dimensions[0]
            self.gmax = gmin+dimensions[1]
            self.bmax = bmin+dimensions[2]
            
            let size = Int(dimensions[0]*dimensions[1]*dimensions[2])
            cells = [IMPHistogramCubeCell](
                count: size,
                repeatedValue: IMPHistogramCubeCell()
            )
        }
        
        func index(red:Int, green:Int, blue:Int) -> Int{
            return red+green*dimensions[0]+blue*dimensions[0]*dimensions[1]
        }
        
        public subscript(red:Int, green:Int, blue:Int) -> IMPHistogramCubeCell {
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
                        let r     = cell.reds/cell.count/Float(kIMP_HistogramSize-1)
                        let g     = cell.greens/cell.count/Float(kIMP_HistogramSize-1)
                        let b     = cell.blues/cell.count/Float(kIMP_HistogramSize-1)
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
            
            for k in 0 ..< maxima.count  {
                
                let max1 = maxima[k]
                var isDistinct = true
                
                for n in 0 ..< k {
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
            var threshold = Float(0.1)
            
            for _ in 0  ..< 10  {
                temp = distinctMaxima(filtered, threshold: threshold)
                if temp.count <= count {
                    break
                }
                filtered = temp
                threshold += 0.05
            }
            
            return [LocalMaximum](filtered[0..<count])
        }
        
        
        private var maxDimension:(index:Int,dimension:Int) {
            if dimensions[0] >= dimensions[1] && dimensions[0] >= dimensions[2] {
                return (0,dimensions[0])
            }
            else if dimensions[1] >= dimensions[0] && dimensions[1] >= dimensions[2] {
                return (1,dimensions[1])
            }
            else {
                return (2,dimensions[2])
            }
        }
        
        private func sumRedSide(index:Int) -> Float {
            var asum = Float(0)
            for g in 0..<dimensions[1]{
                for b in 0..<dimensions[2]{
                    asum += self[index,g,b].count
                }
            }
            return asum
        }
        
        private func sumGreenSide(index:Int) -> Float {
            var asum = Float(0)
            for r in 0..<dimensions[0]{
                for b in 0..<dimensions[2]{
                    asum += self[r,index,b].count
                }
            }
            return asum
        }
        
        private func sumBlueSide(index:Int) -> Float {
            var asum = Float(0)
            for r in 0..<dimensions[0]{
                for g in 0..<dimensions[1]{
                    asum += self[r,g,index].count
                }
            }
            return asum
        }
        
        private func median(side side:Int) -> Cell {
            
            var v = [Cell]()
            
            var asum = Float(0)
            
            for i in 0..<dimensions[side]{
                var count = Float(0)
                if side == 0 {
                    count = sumRedSide(i)
                }
                else if side == 1 {
                    count = sumGreenSide(i)
                }
                else if side == 2 {
                    count = sumBlueSide(i)
                }
                asum += count
                let c = Cell(index: i, count: count)
                v.append(c)
            }
            
            asum /= 2
            
            var count = Float(0)
            var m = Cell(index: 0, count: 0)
            for iv in v {
                count += iv.count
                if count>=asum {
                    m = iv
                    break
                }
            }
            return m
        }
        
        private func split() -> [Cube] {
            
            let side  = maxDimension
            let index = median(side: side.0).index
            
            var newDimensions1 = [Int](dimensions)
            var newDimensions2 = [Int](dimensions)
            
            newDimensions1[side.0]=index
            newDimensions2[side.0]=newDimensions2[side.0]-index-1
            
            var cube1 = Cube(dimensions: newDimensions1, rmin:self.rmin, gmin: self.gmin, bmin: self.bmin)
            
            for r in 0..<cube1.dimensions[0] {
                for g in 0..<cube1.dimensions[1] {
                    for b in 0..<cube1.dimensions[2] {
                        cube1[r,g,b]=self[r,g,b]
                    }
                }
            }
            
            var sr = 0
            var sg = 0
            var sb = 0
            if side.0 == 0 {
                sr = index+1
            }
            else if side.0 == 1 {
                sg = index+1
            }
            else if side.0 == 2 {
                sb = index+1
            }
            
            var cube2 = Cube(dimensions: newDimensions2, rmin: sr, gmin: sg, bmin: sb)
            
            for r in 0..<cube2.dimensions[0] {
                for g in 0..<cube2.dimensions[1] {
                    for b in 0..<cube2.dimensions[2] {
                        cube2[r,g,b]=self[sr+r,sg+g,sb+b]
                    }
                }
            }
            
            return [cube1,cube2]
        }
        
        public func split(number:Int) -> [Cube] {
            var cubes = [Cube]()
            cubes.append(self)
            
            while cubes.count > 0 && cubes.count<number && cubes.count<Int(kIMP_HistogramCubeResolution) {
                
                cubes = cubes.sort{
                    $0.count > $1.count //&& $0.maxDimension.dimension > $1.maxDimension.dimension
                }
                
                let current = cubes.removeFirst()
                let list = current.split()
                for l in list {
                    if l.count > 0 {
                        cubes.append(l)
                    }
                }
            }
            if cubes.count == 0 {
                cubes.append(self)
            }
            return cubes
        }
        
        var count : Float {
            get{
                var rsum = Float(0)
                for r in 0..<dimensions[0]{
                    for g in 0..<dimensions[1]{
                        for b in 0..<dimensions[2]{
                            rsum+=self[r,g,b].count
                        }
                    }
                }
                return rsum
            }
        }
        
        var average : float3 {
            get {
                var rsum = Float(0)
                var gsum = Float(0)
                var bsum = Float(0)
                for r in 0..<dimensions[0]{
                    for g in 0..<dimensions[1]{
                        for b in 0..<dimensions[2]{
                            rsum+=self[r,g,b].reds
                            gsum+=self[r,g,b].greens
                            bsum+=self[r,g,b].blues
                        }
                    }
                }
                return float3(rsum,gsum,bsum)/count/Float(kIMP_HistogramSize-1)
            }
        }
        
        public func dominantColors(count count: Int) -> [float3] {
            let maximas = filteredMaxima(localMaxima,count: count)
            return maximas.colors
        }
        
        public func palette(count count: Int) -> [float3] {
            
            let cubes = self.split(count).sort {$0.count>$1.count}
            
            var p = [float3]()
            
            for cube in cubes{
                p.append(cube.average)
            }
            
            return p
        }
        
    }
    
    public var cube   = Cube()
    public let size   = Int(kIMP_HistogramCubeSize)
    
    public func update(data dataIn: UnsafePointer<Void>, dataCount: Int){
        clearHistogram()
        var buffer = [IMPHistogramCubeCell](count: size, repeatedValue: IMPHistogramCubeCell())
        for i in 0..<dataCount {
            let dataIn = UnsafePointer<IMPHistogramCubeBuffer>(dataIn)+i
            clear(&buffer)
            updateCells(&buffer, address: dataIn)
            addCells(from: &buffer, to: &cube.cells)
        }
    }
    
    private let dim = sizeof(UInt32)/sizeof(simd.uint);
    
    private func updateCells(inout cells:[IMPHistogramCubeCell], address:UnsafePointer<IMPHistogramCubeBuffer>){
        let p = UnsafePointer<UInt32>(address)
        let to = UnsafeMutablePointer<Float>(cells)
        vDSP_vfltu32(p, 1, to, 1, vDSP_Length(cells.count*4))
    }
    
    private func addCells(inout from from:[IMPHistogramCubeCell], inout to:[IMPHistogramCubeCell]){
        let tobuffer   = UnsafeMutablePointer<Float>(to)
        let frombuffer = UnsafeMutablePointer<Float>(from)
        vDSP_vadd(tobuffer, 1, frombuffer, 1, tobuffer, 1, vDSP_Length(to.count*4))
    }
    
    private func clear(inout cells:[IMPHistogramCubeCell]){
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