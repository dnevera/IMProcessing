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

extension IMPHistogramCube.Cube:Comparable{}

public func == (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxSide().dimension == rhs.maxSide().dimension
}

public func <= (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxSide().dimension <= rhs.maxSide().dimension
}

public func > (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxSide().dimension > rhs.maxSide().dimension
}

public func < (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool {
    return lhs.maxSide().dimension < rhs.maxSide().dimension
}

public func >= (lhs: IMPHistogramCube.Cube, rhs: IMPHistogramCube.Cube) -> Bool{
    return lhs.maxSide().dimension >= rhs.maxSide().dimension
}

extension IMPHistogramCube.Cell:Comparable{}

 func == (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.value == rhs.value
}

 func <= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.value <= rhs.value
}

 func > (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.value > rhs.value
}

 func < (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool {
    return lhs.value < rhs.value
}

 func >= (lhs: IMPHistogramCube.Cell, rhs: IMPHistogramCube.Cell) -> Bool{
    return lhs.value >= rhs.value
}

public class IMPHistogramCube{
    
    internal struct Cell{
        var index:Int
        var value:Float
    }
    
    public struct Cube {
        public var rmin  = 0
        public var rmax  = Int(kIMP_HistogramCubeResolution)
        public var gmin  = 0
        public var gmax  = Int(kIMP_HistogramCubeResolution)
        public var bmin  = 0
        public var bmax  = Int(kIMP_HistogramCubeResolution)
        public var counts:[Float]
        public let dimensions:[Int]
        
        public init(){
            dimensions = [Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution),Int(kIMP_HistogramCubeResolution)]
            counts = [Float](count: Int(dimensions[0]*dimensions[1]*dimensions[2]), repeatedValue: 0)
        }
        
        public init(counts:[Float],dimensions:[Int]){
            self.counts = counts
            self.dimensions = dimensions
        }

        public init(dimensions:[Int]){
            self.dimensions = dimensions
            counts = [Float](count: Int(dimensions[0]*dimensions[1]*dimensions[2]), repeatedValue: 0)
        }

        public subscript(red:Int, green:Int, blue:Int) -> Float {
            get{
                let index = red+green*dimensions[0]+blue*dimensions[0]*dimensions[1]
                return counts[index]
            }
            set {
                let index = red+green*dimensions[0]+blue*dimensions[0]*dimensions[1]
                counts[index] = newValue
            }
        }
        
        private func maxSide() -> (index:Int,dimension:Int) {
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
        
        private func red(red:Int) -> Float {
            return self[red, 0, 0]
        }
        
        private func green(green:Int) -> Float {
            return self[0, green, 0]
        }

        private func blue(blue:Int) -> Float {
            return self[0, 0, blue]
        }

        private func sumRed() -> Float {
            var asum = Float(0)
            var rm = Float(rmin)
            for r in 0..<dimensions[0]{
                for g in 0..<dimensions[1]{
                    for b in 0..<dimensions[2]{
                        asum += self[r,g,b]*(rm/Float(kIMP_HistogramCubeResolution))
                    }
                }
                rm += 1
            }
            return asum
        }

        private func sumGreen() -> Float {
            var asum = Float(0)
            var rm = Float(gmin)
            for g in 0..<dimensions[1]{
                for r in 0..<dimensions[0]{
                    for b in 0..<dimensions[2]{
                        asum += self[r,g,b]*(rm/Float(kIMP_HistogramCubeResolution))
                    }
                }
                rm += 1
            }
            return asum
        }

        private func sumBlue() -> Float {
            var asum = Float(0)
            var rm = Float(bmin)
            for b in 0..<dimensions[2]{
                for r in 0..<dimensions[0]{
                    for g in 0..<dimensions[1]{
                        asum += self[r,g,b]*(rm/Float(kIMP_HistogramCubeResolution))
                    }
                }
                rm += 1
            }
            return asum
        }

        private func median(side side:Int) -> Cell {
            
            var v = [Cell](count: dimensions[side], repeatedValue: Cell(index: 0, value: 0))
            var asum = Float(0)
            for i in 0..<dimensions[side]{
                v[i].index = i
                if side == 0 {
                    v[i].value = red(i)
                }
                else if side == 1 {
                    v[i].value = green(i)
                }
                else if side == 2 {
                    v[i].value = blue(i)
                }
                asum += v[i].value
            }

            asum /= 2
            
            var count = Float(0)
            var m = Cell(index: 0, value: 0)
            for iv in v {
                if count>=asum {
                    m = iv
                    break
                }
                count += iv.value
            }
            return m
        }
        
        private func split() -> [Cube] {
            let side  = maxSide()
            let index = median(side: side.0).index
            var newDimensions1 = [Int](dimensions)
            var newDimensions2 = [Int](dimensions)
            newDimensions1[side.0]=index
            newDimensions2[side.0]=newDimensions2[side.0]-index-1
            
            var cube1 = Cube(dimensions: newDimensions1)
            
            cube1.rmin = self.rmin
            cube1.gmin = self.gmin
            cube1.bmin = self.bmin

            cube1.rmax = cube1.rmin+newDimensions1[0]
            cube1.gmax = cube1.gmin+newDimensions1[1]
            cube1.bmax = cube1.bmin+newDimensions1[2]
            
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
            
            var cube2 = Cube(dimensions: newDimensions2)

            cube2.rmin = sr
            cube2.gmin = sg
            cube2.bmin = sb
            
            cube2.rmax = cube2.rmin+newDimensions2[0]
            cube2.gmax = cube2.gmin+newDimensions2[1]
            cube2.bmax = cube2.bmin+newDimensions2[2]
            

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
                cubes = cubes.sort(>)
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
                for r in 0..<self.dimensions[0] {
                    for g in 0..<self.dimensions[1] {
                        for b in 0..<self.dimensions[2] {
                            rsum += self[r,g,b]
                        }
                    }
                }
                return rsum
            }
        }
        
        var average : float3 {
            get {
                let c = count
                let rsum = sumRed()/c
                let gsum = sumGreen()/c
                let bsum = sumBlue()/c
                return float3((rmin+rmax)*rsum,(gmin+gmax)*gsum,(bmin+bmax)*bsum)/Float(kIMP_HistogramCubeResolution)
            }
        }
        
        public func pallete(count count: Int) -> [float3] {
            var p = [float3]()
            let cubes = split(count)
            
            for cube in cubes {
                p.append(cube.average*Float(cubes.count))
            }
            
            return p
        }
        
    }
    
    public var cube   = Cube()
    public let size   = Int(kIMP_HistogramCubeSize)
    
    public func updateWithData(dataIn: UnsafePointer<Void>, dataCount: Int){
        
        clearHistogram()
        
        for i in 0..<dataCount {
            
            let dataIn = UnsafePointer<IMPHistogramCubeBuffer>(dataIn)+i
            let address = UnsafePointer<UInt32>(dataIn)
            var data = [Float](count: Int(self.size), repeatedValue: 0)
            
            self.updateChannel(&data, address: address)
            self.addFromData(&data, to: &cube.counts)
        }
    }
    
    
    private let dim = sizeof(UInt32)/sizeof(simd.uint);
    
    private func updateChannel(inout counts:[Float], address:UnsafePointer<UInt32>){
        let p = address
        let dim = self.dim<1 ? 1 : self.dim
        vDSP_vfltu32(p, dim, &cube.counts, 1, vDSP_Length(self.size))
    }
    
    private func addFromData(inout data:[Float], inout to:[Float]){
        vDSP_vadd(&to, 1, &data, 1, &to, 1, vDSP_Length(self.size))
    }
    
    private func clear(inout counts:[Float]){
        vDSP_vclr(&counts, 1, vDSP_Length(self.size))
    }
    
    private func clearHistogram(){
        clear(&cube.counts)
    }
}
