//: Playground - noun: a place where people can play

import IMProcessing
import Cocoa
import simd

let m2 = matrix_float4x4(columns: (
    float4(3,0,0,0),
    float4(0,4,0,0),
    float4(0,0,5,0),
    float4(0,0,0,1)
    ))

let mmm = matrix_transpose(matrix_multiply(matrix_identity_float4x4,  m2))

print("\(mmm)")

var m3 = float4x4(1)

m3.inverse

