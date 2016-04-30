//
//  IMPMain_metal.metal
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "IMPStdlib_metal.h"


vertex IMPVertexOut vertex_transformation(
                                          const device IMPVertex*       vertex_array [[ buffer(0) ]],
                                          const device IMPMatrixModel&  matrix_model [[ buffer(1) ]],
                                          unsigned int vid [[ vertex_id ]]) {
    
    
    IMPVertex in = vertex_array[vid];
    float3 position = float3(in.position);
    
    IMPVertexOut out;
    out.position = matrix_model.projectionMatrix * matrix_model.transformMatrix * float4(position,1) * matrix_model.transitionMatrix;
    
    out.texcoord = float2(in.texcoord);
    
    return out;
}

typedef struct {
    float4 position [[position]];
    float3 texcoord;
} IMPVertexOutPerspective;


vertex IMPVertexOutPerspective vertex_warpTransformation(
                                          const device IMPVertex*   vertex_array     [[ buffer(0) ]],
                                          const device float4x4    &homography_model [[ buffer(1) ]],
                                          unsigned int vid [[ vertex_id ]]) {
    
    
    IMPVertex in = vertex_array[vid];
    float3 position = float3(in.position);
    
    IMPVertexOutPerspective out;
    out.position =    homography_model * float4(position,1);

    out.texcoord = float3(in.texcoord,out.position.z);
    
    return out;
}


fragment float4 fragment_transformation(
                                        IMPVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> texture [[ texture(0) ]]
                                        ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord.xy);
}

fragment float4 fragment_warpTransformation(
                                        IMPVertexOutPerspective in [[stage_in]],
                                        texture2d<float, access::sample> texture [[ texture(0) ]]
                                        ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord.xy);
}

typedef struct{
    float2 left_bottom;
    float2 left_top;
    float2 right_bottom;
    float2 right_top;
} IMPQuad;

kernel void kernel_quad(
                                  texture2d<float, access::sample>   inTexture   [[texture(0)]],
                                  texture2d<float, access::write>    outTexture  [[texture(1)]],
                                  constant IMPQuad     &quad [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]){
    
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    
    outTexture.write(inColor,gid);
}
