//: [Previous](@previous)

import Foundation
import IMProcessing
import Accelerate
import simd

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
        
        var t = general2DProjection(x1s:-0.1, y1s: 0, x1d: 0, y1d: 0,
                                    x2s: 1, y2s: 0, x2d: 1, y2d: 0,
                                    x3s: 0, y3s: 1, x3d: 0, y3d: 1,
                                    x4s: 1, y4s: 1, x4d: 1, y4d: 1.1)
        
        for i in 0..<9 {
            t[i] = t[i]/t[8];
        }

        let T:[[Float]] = [
            [t[0],t[1],t[2]],
            [t[3],t[4],t[5]],
            [t[6],t[7],t[8]]
        ]
        
        _transformation = float3x3(rows: T)

    }
    
    func adj(m m:[Float]) -> [Float] { // Compute the adjugate of m
        return [
            m[4]*m[8]-m[5]*m[7], m[2]*m[7]-m[1]*m[8], m[1]*m[5]-m[2]*m[4],
            m[5]*m[6]-m[3]*m[8], m[0]*m[8]-m[2]*m[6], m[2]*m[3]-m[0]*m[5],
            m[3]*m[7]-m[4]*m[6], m[1]*m[6]-m[0]*m[7], m[0]*m[4]-m[1]*m[3]
        ]
    }
    
    func multmm(a a:[Float], b:[Float]) -> [Float] { // multiply two matrices
        var c = [Float](count:9, repeatedValue:0)
        for i in 0 ..< 3 {
            for j in 0 ..< 3 {
                var cij:Float = 0
                for k in 0 ..< 3 {
                    cij += a[3*i + k]*b[3*k + j]
                }
                c[3*i + j] = cij
            }
        }
        return c
    }
    
    func multmv(m m:[Float], v:[Float]) -> [Float] { // multiply matrix and vector
        return [
            m[0]*v[0] + m[1]*v[1] + m[2]*v[2],
            m[3]*v[0] + m[4]*v[1] + m[5]*v[2],
            m[6]*v[0] + m[7]*v[1] + m[8]*v[2]
        ]
    }
    
    func basisToPoints(x1 x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, x4:Float, y4:Float) -> [Float] {
        let m:[Float] = [
            x1, x2, x3,
            y1, y2, y3,
            1,  1,  1
        ]
        var v = multmv(m: adj(m: m), v: [x4, y4, 1]);
        return multmm(a: m, b: [
            v[0], 0, 0,
            0, v[1], 0,
            0, 0, v[2]
            ]);
    }
    
    func general2DProjection(
        x1s x1s:Float, y1s:Float, x1d:Float, y1d:Float,
            x2s:Float, y2s:Float, x2d:Float, y2d:Float,
            x3s:Float, y3s:Float, x3d:Float, y3d:Float,
            x4s:Float, y4s:Float, x4d:Float, y4d:Float
        ) -> [Float] {
        let s = basisToPoints(x1: x1s, y1: y1s, x2: x2s, y2: y2s, x3: x3s, y3: y3s, x4: x4s, y4: y4s)
        let d = basisToPoints(x1: x1d, y1: y1d, x2: x2d, y2: y2d, x3: x3d, y3: y3d, x4: x4d, y4: y4d)
        return multmm(a: d, b: adj(m: s));
    }
}



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


//
//    func project(m m:[Float], x:Float, y:Float) -> [Float] {
//        var v = multmv(m: m, v: [x, y, 1])
//        return [v[0]/v[2], v[1]/v[2]];
//    }
//
//    var t = general2DProjection(x1s:-0.1, y1s: 0, x1d: 0, y1d: 0,
//                                x2s: 1, y2s: 0, x2d: 1, y2d: 0,
//                                x3s: 0, y3s: 1, x3d: 0, y3d: 1,
//                                x4s: 1, y4s: 1, x4d: 1, y4d: 1.1)
//
//    for i in 0..<9 {
//    t[i] = t[i]/t[8];
//    }
//
//    print(t[0],t[1],t[2])
//    print(t[3],t[4],t[5])
//    print(t[6],t[7],t[8])

//
//t = [t[0], t[3], 0, t[6],
//     t[1], t[4], 0, t[7],
//     0   , 0   , 1, 0   ,
//     t[2], t[5], 0, t[8]];
//
//print(t[0],t[1],t[2],t[3])
//print(t[4],t[5],t[6],t[7])
//print(t[8],t[9],t[10],t[11])
//print(t[12],t[13],t[14],t[15])
//

