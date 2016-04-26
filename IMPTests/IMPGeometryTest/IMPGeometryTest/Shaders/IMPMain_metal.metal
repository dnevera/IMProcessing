//
//  IMPMain_metal.metal
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "IMPStdlib_metal.h"


typedef struct {
    packed_float3 position;
    packed_float2 texcoord;
} IMPVertexModel;

typedef struct {
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 transitionMatrix;
} IMPMatrixModel;

vertex IMPVertexOut vertex_transformation(
                                          const device IMPVertexModel*  vertex_array [[ buffer(0) ]],
                                          const device IMPMatrixModel&  matrix_model [[ buffer(1) ]],
                                          unsigned int vid [[ vertex_id ]]) {
    
    IMPVertexModel in = vertex_array[vid];
    
    IMPVertexOut out;
    out.position = matrix_model.projectionMatrix * matrix_model.modelMatrix * float4(in.position,1) * matrix_model.transitionMatrix;
    
    out.texcoord = float2(in.texcoord);
    
    return out;
}

fragment float4 fragment_transformation(
                                        IMPVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> texture [[ texture(0) ]]
                                        ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord);
}


//typedef struct {
//    packed_float3 position;
//    packed_float2 texcoord;
//} IMPVertexModel;
//
//typedef struct {
//    //float3        scale;
//    float4x4      transform;
//    float4x4      projection;
//} IMPMatrixModel;
//
//vertex IMPVertexOut vertex_transformation(
//                                          device IMPVertexModel*     verticies   [[ buffer(0) ]],
//                                          device IMPMatrixModel&     matrix      [[ buffer(1) ]],
//                                          //device float4x4&           orthoMatrix [[ buffer(2) ]],
//                                          unsigned int               vid         [[ vertex_id ]]
//                                          ) {
//
//    device IMPVertexModel& v = verticies[vid];
//
//    IMPVertexOut out;
//
//    //out.position = matrix.projection * matrix.transform * float4(v.position,1)  * orthoMatrix;
//    //out.position = matrix.projection * matrix.transform * float4(v.position,1);
//    float4x4 m = float4x4(
//                          float4(1,0,0,0),
//                          float4(0,1,0,0),
//                          float4(0,0,1,0),
//                          float4(0,0,0,1)
//                          );
//    out.position = matrix.transform * float4(v.position,1);
//    //out.position = m * float4(v.position,1);
//
//    out.texcoord = float2(v.texcoord);
//
//    return out;
//}
//
//fragment float4 fragment_transformation(
//                                        IMPVertexOut in [[ stage_in ]],
//                                        texture2d<float, access::sample> texture [[ texture(0) ]]
//                                        ) {
//    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
//    return texture.sample(s, in.texcoord);
//}
//
//
///**
// *  Pass through vertex
// *
// */
//vertex IMPVertexOut vertex_passthrough(
//                                       device IMPVertexIn*        verticies   [[ buffer(0) ]],
//                                       device IMPTransformBuffer& transform   [[ buffer(1) ]],
//                                       device float4x4&           orthoMatrix [[ buffer(2) ]],
//                                       unsigned int               vid         [[ vertex_id ]]
//                                       ) {
//
//    device IMPVertexIn& v = verticies[vid];
//
//    float3 position = transform.rotation * float3(float2(v.position) , 0.0) * transform.scale ;
//
//    IMPVertexOut out;
//
//    out.position = (float4(position, 1.0) * orthoMatrix) * transform.projection * transform.transition ;
//
//    out.texcoord = float2(v.texcoord);
//
//    return out;
//}
//
///**
// * View rendering vertex
// */
//vertex IMPVertexOut vertex_passview(
//                                    device IMPVertexIn* verticies [[ buffer(0) ]],
//                                    unsigned int        vid       [[ vertex_id ]]
//                                    ) {
//    IMPVertexOut out;
//
//    device IMPVertexIn& v = verticies[vid];
//
//    float3 position = float3(float2(v.position) , 0.0);
//
//    out.position = float4(position, 1.0);
//
//    out.texcoord = float2(v.texcoord);
//
//    return out;
//}
//
//
///**
// *  Pass through fragment
// *
// */
//fragment float4 fragment_passthrough(
//                                     IMPVertexOut in [[ stage_in ]],
//                                     texture2d<float, access::sample> texture [[ texture(0) ]]
//                                     ) {
//
//    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
//    return texture.sample(s, in.texcoord);
//}
//
