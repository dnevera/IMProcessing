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
    
//    float2 BL(-1,-1);
//    float2 BR( 1,-1.2);
//    float2 TL(-1, 1);
//    float2 TR( 1.,1.2);
//    
//
//    
//    float2 vertex_p = position.xy;
//    
//    // transform from QC object coords to 0...1
//    float2 p = (float2(vertex_p.x, vertex_p.y) + 1.) * 0.5;
//    
//    // interpolate bottom edge x coordinate
//    float2 x1 = mix(BL, BR, p.x);
//    
//    // interpolate top edge x coordinate
//    float2 x2 = mix(TL, TR, p.x);
//    
//    // interpolate y position
//    p = mix(x1, x2, p.y);
//    
//    //p = (p - 0.5) ;
//    

    IMPVertexOut out;
    out.position = matrix_model.projectionMatrix * matrix_model.transformMatrix * float4(position,1) * matrix_model.transitionMatrix;
    
    out.texcoord = float2(in.texcoord);
    
    return out;
}

vertex IMPVertexOut vertex_warpTransformation(
                                          const device IMPVertex*   vertex_array     [[ buffer(0) ]],
                                          const device float3x3    &homography_model [[ buffer(1) ]],
                                          unsigned int vid [[ vertex_id ]]) {
    
    
    IMPVertex in = vertex_array[vid];
    float3 position = float3(in.position);
    
    IMPVertexOut out;
    out.position = float4(homography_model * position,1);
    
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

