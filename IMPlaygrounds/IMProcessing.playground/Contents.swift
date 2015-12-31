//: Playground - noun: a place where people can play

import Cocoa
import simd
import Accelerate


uint.max/255

public struct Cell{
    var index:Int
    var value:Float
}

extension Cell:Comparable{}

public func == (lhs: Cell, rhs: Cell) -> Bool {
    return lhs.value == rhs.value
}

public func + (lhs: Cell, rhs: Cell) -> Cell {
    return Cell(index: lhs.index, value: lhs.value+rhs.value)
}

public func <= (lhs: Cell, rhs: Cell) -> Bool {
    return lhs.value <= rhs.value
}

public func > (lhs: Cell, rhs: Cell) -> Bool {
    return lhs.value > rhs.value
}

public func < (lhs: Cell, rhs: Cell) -> Bool {
    return lhs.value < rhs.value
}

public func >= (lhs: Cell, rhs: Cell) -> Bool{
    return lhs.value >= rhs.value
}

extension Array where Element: Comparable {
    var median: Element {
        return self.sort(<)[ self.count/2]
    }
}

let rr = [0,1,2,3,4].reduce(0, combine: {$0+$1})

print(" rr = \(rr)")

var vv = [
    Cell(index: 0, value: 200),
    Cell(index: 1, value: 40000),
    Cell(index: 2, value: 300),
    Cell(index: 3, value: 21),
    Cell(index: 4, value: 20),
    Cell(index: 5, value: 20),
    Cell(index: 6, value: 20000),
    Cell(index: 7, value: 2000)]

let v = vv[0..<vv.count].sort().filter { (v) -> Bool in
    v.value != 0
}

for i in v.sort(>){
    print(i)
}

print("--")
print(v.median)

let h      = Float(3024)
let c      = Float(16)
let offset = h/c

Int(2000/offset)
Int(3024/offset)





