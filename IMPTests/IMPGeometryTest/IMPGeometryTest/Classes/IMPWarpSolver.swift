//
//  IMPWarpSolver.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
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
    var left_bottom  = float2( -1, -1)
    var left_top     = float2( -1,  1)
    var right_bottom = float2(  1, -1)
    var right_top    = float2(  1,  1)
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
    
    private var _transformation = float4x4() {
        didSet{
            print (".... _transformation = \(_transformation)")
        }
    }
    
    public var transformation:float4x4 {
        return _transformation
    }
    
    public init(source s: IMPQuad, destination d:IMPQuad){
        defer{
            source=s
            destination=d
        }
    }
    
    func solve(){
        
        var t = general2DProjection(x1s: source.left_bottom.x,
                                    y1s: source.left_bottom.x,
                                    x1d: destination.left_bottom.x,
                                    y1d: destination.left_bottom.y,
                                    x2s: source.left_top.x,
                                    y2s: source.left_top.y,
                                    x2d: destination.left_top.x,
                                    y2d: destination.left_top.y,
                                    x3s: source.right_bottom.x,
                                    y3s: source.right_bottom.y,
                                    x3d: destination.right_bottom.x,
                                    y3d: destination.right_bottom.y,
                                    x4s: source.right_top.x,
                                    y4s: source.right_top.y,
                                    x4d: destination.right_top.x,
                                    y4d: destination.right_top.y)
        
        for i in 0..<9 {
            t[i] =  t[i]/t[8]
        }
        
        let T = [
            [t[0], t[1], 0, t[2]],
            [t[3], t[4], 0, t[5]],
            [0   , 0   , 1, 0   ],
            [t[6], t[7], 0, t[8]]
        ];
        
        _transformation = float4x4(rows: T)
        
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
//    private var _transformation = float3x3() {
//        didSet{
//            print (".... _transformation = \(_transformation)")
//        }
//    }
//    
//    public var transformation:float3x3 {
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
//        var xy2 = source.ritgh_bottom
//        var xy3 = source.right_top
//        
//        var uv0 = destination.left_bottom
//        var uv1 = destination.left_top
//        var uv2 = destination.ritgh_bottom
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
//        var h:[Float] = [Float](count:8, repeatedValue:0)
//        
//        let lA = la_matrix_from_float_buffer( &A, 8, 8, 8, 0, 0 )
//        let lB = la_matrix_from_float_buffer( &B, 8, 1, 1, 0, 0 )
//        
//        let lh = la_solve( lA, lB)
//        
//        let status = la_vector_to_float_buffer( &h, 1, lh )
//        
//        if status >= 0 {
//            
//            let H:[[Float]] = [
//                [h[0], h[1], h[2]],
//                [h[3], h[4], h[5]],
//                [h[6], h[7], 1]
//            ]
//            _transformation = float3x3(rows:H)
//        }
//        else{
//            NSLog("IMPWarpSolver: error \(status)")
//        }
//    }
//}
