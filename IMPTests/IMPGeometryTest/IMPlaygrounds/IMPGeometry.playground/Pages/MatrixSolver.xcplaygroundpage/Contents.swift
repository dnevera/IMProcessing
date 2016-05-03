//: [Previous](@previous)

import Foundation
import IMProcessing
import Accelerate
import simd

//MARK: - Printable
extension la_object_t {
    
    
    final public var rows: Int {
        return Int(la_matrix_rows(self))
    }
    
    /// Convenience accessor for column count
    final public var cols: Int {
        return Int(la_matrix_cols(self))
    }
    
    final public func toArray() -> [Float] {
        var array = [Float](count: rows * cols, repeatedValue: 0.0)
        
        let status = la_matrix_to_float_buffer(&array, la_count_t(cols), self)
        
        //assertStatusIsSuccess(status)
        
        return array
    }
    
    final public func description() -> String {
        
        let outputArray = toArray()
        
        let rowDescriptions = (0..<rows).map { x -> String in
            let valDescriptions = (0..<self.cols).map { y -> String in
                outputArray[Int(y + x * self.cols)].description
            }
            let commaJoinedVals = valDescriptions.joinWithSeparator(", ")
            return commaJoinedVals
        }
        
        let rowsJoinedByLine = rowDescriptions.joinWithSeparator("\n")
        
        return rowsJoinedByLine
    }
}

public extension float3x3 {
    public init(rows: [[Float]]){
        self.init(matrix_from_rows(vector_float3(rows[0]), vector_float3(rows[1]), vector_float3(rows[2])))
    }
    
    public init(_ columns: [[Float]]){
        self.init(matrix_from_columns(vector_float3(columns[0]), vector_float3(columns[1]), vector_float3(columns[2])))
    }
}

public extension float4x4 {
    public init(rows: [[Float]]){
        self.init(matrix_from_rows(float4(rows[0]), float4(rows[1]), float4(rows[2]),float4(rows[3])))
    }
}

public struct IMPQuad {
    var left_bottom  = float2( 0, 0)
    var left_top     = float2( 0, 1)
    var ritgh_bottom = float2( 1, 0)
    var right_top    = float2( 1, 1)
}

typealias LAInt = __CLPK_integer // = Int32

public class IMPWarpSolver {
    
    public var source = IMPQuad() {
        didSet{
            print (".... source = \(source)")
            solve()
        }
    }
    
    public var destination = IMPQuad(){
        didSet{
            print (".... destination = \(source)")
            solve()
        }
    }
    
    private var _transformation = float3x3() {
        didSet{
            print (".... _transformation = \(_transformation)")
        }
    }
    
    public var transformation:float3x3 {
        return _transformation
    }
    
    public init(source s: IMPQuad, destination d:IMPQuad){
        defer{
            source=s
            destination=d
        }
    }
    
    func solve(){
        var xy0 = source.left_bottom
        var xy1 = source.left_top
        var xy2 = source.ritgh_bottom
        var xy3 = source.right_top
        
        var uv0 = destination.left_bottom
        var uv1 = destination.left_top
        var uv2 = destination.ritgh_bottom
        var uv3 = destination.right_top
        
        var A:[Float] = [
            xy0.x, xy0.y, 1, 0,     0,     0, -uv0.x * xy0.x, -uv0.x * xy0.y,
            0,     0,     0, xy0.x, xy0.y, 1, -uv0.y * xy0.x, -uv0.y * xy0.y,
            xy1.x, xy1.y, 1, 0,     0,     0, -uv1.x * xy1.x, -uv1.x * xy1.y,
            0,     0,     0, xy1.x, xy1.y, 1, -uv1.y * xy1.x, -uv1.y * xy1.y,
            xy2.x, xy2.y, 1, 0,     0,     0, -uv2.x * xy2.x, -uv2.x * xy2.y,
            0,     0,     0, xy2.x, xy2.y, 1, -uv2.y * xy2.x, -uv2.y * xy2.y,
            xy3.x, xy3.y, 1, 0,     0,     0, -uv3.x * xy3.x, -uv3.x * xy3.y,
            0,     0,     0, xy3.x, xy3.y, 1, -uv3.y * xy3.x, -uv3.y * xy3.y,
            ]
        
        var B:[Float] = [
            uv0.x,
            uv0.y,
            uv1.x,
            uv1.y,
            uv2.x,
            uv2.y,
            uv3.x,
            uv3.y
        ]
        
        let lA = la_matrix_from_float_buffer( &A, 8, 8, 8, 0, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING) )
        let lB = la_matrix_from_float_buffer( &B, 8, 1, 1, 0, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING) )
        
        let lh = la_solve(lA, lB)
        
        var h:[Float] = [Float](count:9, repeatedValue:1)
        let status = la_vector_to_float_buffer( &h, 1, lh )
        
        if status >= 0 {
            
            let H:[[Float]] = [
                [h[0], h[3], h[6]],
                [h[1], h[4], h[7]],
                [h[2], h[5], h[8]]
            ]
            //print("LH = \(lh.description())")
            _transformation = float3x3(rows:H)
            
//            let equations = 8
//
//            var numberOfEquations:LAInt = 8
//            var columnsInA:       LAInt = 8
//            var elementsInB:      LAInt = 8
//            var bSolutionCount:   LAInt = 1
//            
//            var outputOk: LAInt = 0
//            var pivot = [LAInt](count: equations, repeatedValue: 0)
//            
//            sgesv_( &numberOfEquations, &bSolutionCount, &A, &columnsInA, &pivot, &B, &elementsInB, &outputOk)
//            print(" --> \(pivot)")

        }
        else{
            NSLog("IMPWarpSolver: error \(status)")
        }
    }
}

//
//var xy0 = float2(0,0)
//var xy1 = float2(0,1)
//var xy2 = float2(1,0)
//var xy3 = float2(1,1)
//
//var uv0 = float2(0.0,0.0)
//var uv1 = float2(0.0,1.0)
//var uv2 = float2(1.0,0.0)
//var uv3 = float2(1.0,1.0)
//
let source = IMPQuad(left_bottom:  float2(-0.1,0),
                     left_top:     float2(0,1),
                     ritgh_bottom: float2(1,0),
                     right_top:    float2(1,1))

let destination = IMPQuad(left_bottom:  float2(0,0),
                          left_top:     float2(0,1),
                          ritgh_bottom: float2(1,0),
                          right_top:    float2(1,1.1))

let solver = IMPWarpSolver(source: source, destination: destination)

let c = solver.transformation.cmatrix.columns

print(c.0.x,c.1.x,c.2.x)
print(c.0.y,c.1.y,c.2.y)
print(c.0.z,c.1.z,c.2.z)

//var A:[Float] = [
//    xy0.x, xy0.y, 1, 0,     0,     0, -uv0.x * xy0.x, -uv0.x * xy0.y,
//    0,     0,     0, xy0.x, xy0.y, 1, -uv0.y * xy0.x, -uv0.y * xy0.y,
//    xy1.x, xy1.y, 1, 0,     0,     0, -uv1.x * xy1.x, -uv1.x * xy1.y,
//    0,     0,     0, xy1.x, xy1.y, 1, -uv1.y * xy1.x, -uv1.y * xy1.y,
//    xy2.x, xy2.y, 1, 0,     0,     0, -uv2.x * xy2.x, -uv2.x * xy2.y,
//    0,     0,     0, xy2.x, xy2.y, 1, -uv2.y * xy2.x, -uv2.y * xy2.y,
//    xy3.x, xy3.y, 1, 0,     0,     0, -uv3.x * xy3.x, -uv3.x * xy3.y,
//    0,     0,     0, xy3.x, xy3.y, 1, -uv3.y * xy3.x, -uv3.y * xy3.y,
//]
//
//var B:[Float] = [
//    uv0.x,
//    uv0.y,
//    uv1.x,
//    uv1.y,
//    uv2.x,
//    uv2.y,
//    uv3.x,
//    uv3.y
//]
//
//
//var h:[Float] = [Float](count:8, repeatedValue:0)
//
//let lA = la_matrix_from_float_buffer( &A, 8, 8, 8, 0, 0 )
//let lB = la_matrix_from_float_buffer( &B, 8, 1, 1, 0, 0 )
//
//let lh = la_solve( lA, lB)
//
//let status = la_vector_to_float_buffer( &h, 1, lh )
//
//let HA:[[Float]] = [
//    [h[0], h[1], h[2]],
//    [h[3], h[4], h[5]],
//    [h[6], h[7], 1]
//]
//
//let HA4:[[Float]] = [
//    [h[0], h[1], 0, h[2]],
//    [h[3], h[4], 0, h[5]],
//    [0,    0,    1, 0],
//    [h[6], h[7], 0, 1]
//]
//
//
//let H = float3x3(rows:HA)
//let H4 = float4x4(rows:HA4)
//
//print(HA4)


////
//// LAPACK la_solve works incorect...
////
//public class IMPWarpSolver {
//    
//    public var source = IMPQuad() {
//        didSet{
//            print (".... source = \(source)")
//            solve()
//        }
//    }
//    
//    public var destination = IMPQuad(){
//        didSet{
//            print (".... destination = \(source)")
//            solve()
//        }
//    }
//    
//    private var _transformation = float4x4() {
//        didSet{
//            print (".... _transformation = \(_transformation)")
//        }
//    }
//    
//    public var transformation:float4x4 {
//        return _transformation
//    }
//    
//    public init(source s: IMPQuad, destination d:IMPQuad){
//        defer{
//            source=s
//            destination=d
//        }
//    }
//    
//    func solve(){
//        var xy0 = source.left_bottom
//        var xy1 = source.left_top
//        var xy2 = source.right_bottom
//        var xy3 = source.right_top
//        
//        var uv0 = destination.left_bottom
//        var uv1 = destination.left_top
//        var uv2 = destination.right_bottom
//        var uv3 = destination.right_top
//        
//        var A:[Float] = [
//            xy0.x, xy0.y, 1, 0,     0,     0, -uv0.x * xy0.x, -uv0.x * xy0.y,
//            0,     0,     0, xy0.x, xy0.y, 1, -uv0.y * xy0.x, -uv0.y * xy0.y,
//            xy1.x, xy1.y, 1, 0,     0,     0, -uv1.x * xy1.x, -uv1.x * xy1.y,
//            0,     0,     0, xy1.x, xy1.y, 1, -uv1.y * xy1.x, -uv1.y * xy1.y,
//            xy2.x, xy2.y, 1, 0,     0,     0, -uv2.x * xy2.x, -uv2.x * xy2.y,
//            0,     0,     0, xy2.x, xy2.y, 1, -uv2.y * xy2.x, -uv2.y * xy2.y,
//            xy3.x, xy3.y, 1, 0,     0,     0, -uv3.x * xy3.x, -uv3.x * xy3.y,
//            0,     0,     0, xy3.x, xy3.y, 1, -uv3.y * xy3.x, -uv3.y * xy3.y,
//            ]
//        
//        var B:[Float] = [
//            uv0.x,
//            uv0.y,
//            uv1.x,
//            uv1.y,
//            uv2.x,
//            uv2.y,
//            uv3.x,
//            uv3.y
//        ]
//        
//        var t:[Float] = [Float](count:9, repeatedValue:1)
//        
//        let lA = la_matrix_from_float_buffer( &A, 8, 8, 8, 0, 0 )
//        let lB = la_matrix_from_float_buffer( &B, 8, 1, 1, 0, 0 )
//        
//        let lh = la_solve( lA, lB)
//        
//        let status = la_vector_to_float_buffer( &t, 1, lh )
//        
//        if status >= 0 {
//
//            for i in 0..<9 {
//                t[i] =  t[i]/t[8]
//            }
//            
//            let T = [
//                [t[0], t[1], 0, t[2]],
//                [t[3], t[4], 0, t[5]],
//                [0   , 0   , 1, 0   ],
//                [t[6], t[7], 0, t[8]]
//            ];
//
////            let T = [
////                [t[0], t[3], 0, t[6]],
////                [t[1], t[4], 0, t[7]],
////                [0   , 0   , 1, 0   ],
////                [t[2], t[5], 0, t[8]]
////            ];
//
//            _transformation = float4x4(rows: T)
//            
////            let H:[[Float]] = [
////                [h[0], h[1], h[2]],
////                [h[3], h[4], h[5]],
////                [h[6], h[7], 1]
////            ]
////            _transformation = float3x3(rows:H)
//        }
//        else{
//            NSLog("IMPWarpSolver: error \(status)")
//        }
//    }
//}
