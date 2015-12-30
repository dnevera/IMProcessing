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

public class IMPHistogramCube{
    
    public struct Cell{
        var index:Int
        var value:Float
    }
    
    public struct Cube {
        var counts:[Float]
        let dimensions:[Int]
        
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
        
        private func sum(red red:Int) -> Float {
            var sum = Float(0)
            for g in 0..<dimensions[1]{
                for b in 0..<dimensions[2]{ sum += self[red, g, b] }
            }
            return sum
        }
        
        private func sum(green green:Int) -> Float {
            var sum = Float(0)
            for r in 0..<dimensions[0]{
                for b in 0..<dimensions[2]{  sum += self[r, green, b] }
            }
            return sum
        }

        private func sum(blue blue:Int) -> Float {
            var sum = Float(0)
            for r in 0..<dimensions[0]{
                for g in 0..<dimensions[1]{ sum += self[r, g, blue] }
            }
            return sum
        }

        private func median(side side:Int) -> Cell {
            
            var v = [Cell](count: dimensions[side], repeatedValue: Cell(index: 0, value: 0))
            var asum = Float(0)
            for i in 0..<dimensions[side]{
                v[i].index = i
                if side == 0 {
                    v[i].value = sum(red: i)
                }
                else if side == 1 {
                    v[i].value = sum(green: i)
                }
                else if side == 2 {
                    v[i].value = sum(blue: i)
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
            newDimensions2[side.0]=newDimensions2[side.0]-index
            var cube1 = Cube(dimensions: newDimensions1)
            
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
                sr = index
            }
            else if side.0 == 1 {
                sg = index
            }
            else if side.0 == 2 {
                sb = index
            }
            
            var cube2 = Cube(dimensions: newDimensions2)

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
            while cubes.count<number && cubes.count<Int(kIMP_HistogramCubeResolution) {
                cubes = cubes.sort(>)
                let current = cubes.removeFirst()
                let list = current.split()
                cubes.append(list[0])
                cubes.append(list[1])
            }
            return cubes
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
