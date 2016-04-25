//
//  IMPMain_metal.metal
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "IMPStdlib_metal.h"



/**
 *  Pass through vertex
 *
 */
vertex IMPVertexOut vertex_passthrough(
                                    device IMPVertexIn*    verticies   [[ buffer(0) ]],
                                    device IMPTransformIn& transform   [[ buffer(1) ]],
                                    device IMPOrthoMatrix& orthoMatrix [[ buffer(2) ]],
                                    unsigned int        vid         [[ vertex_id ]]
                                    ) {
    IMPVertexOut out;
    
//    float3x3         m = transform.transform;
    
    float3x3 tranformMatrix = transform.transform;
//    float3x3(
//                                       float3( m[0], m[1], m[2]),
//                                       float3( m[3], m[4], m[5]),
//                                       float3( m[6], m[7], m[8])
//                                       );
    
    device IMPVertexIn& v = verticies[vid];
    
    float3 position = tranformMatrix * float3(float2(v.position) , 0.0);
    
    out.position = (float4(position, 1.0) * orthoMatrix.matrix) * transform.transition;
    //out.position = (float4(position, 1.0) ) * transform.transition;
    
    out.texcoord = float2(v.texcoord);
    
    return out;
}

/**
 * View rendering vertex
 */
vertex IMPVertexOut vertex_passview(
                                 device IMPVertexIn*    verticies [[ buffer(0) ]],
                                 unsigned int        vid       [[ vertex_id ]]
                                 ) {
    IMPVertexOut out;
    
    device IMPVertexIn& v = verticies[vid];
    
    float3 position = float3(float2(v.position) , 0.0);
    
    out.position = float4(position, 1.0);
    
    out.texcoord = float2(v.texcoord);
    
    return out;
}


/**
 *  Pass through fragment
 *
 */
fragment half4 fragment_passthrough(
                                    IMPVertexOut in [[ stage_in ]],
                                    texture2d<float, access::sample> texture [[ texture(0) ]]
                                    ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    float3 rgb = texture.sample(s, in.texcoord).rgb;
    return half4(half3(rgb), 1.0);
}

