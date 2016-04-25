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
                                    device IMPVertexIn*        verticies   [[ buffer(0) ]],
                                    device IMPTransformBuffer& transform   [[ buffer(1) ]],
                                    device float4x4&           orthoMatrix [[ buffer(2) ]],
                                    unsigned int               vid         [[ vertex_id ]]
                                    ) {
    
    device IMPVertexIn& v = verticies[vid];
    
    float3 position = transform.rotation * float3(float2(v.position) , 0.0) * transform.scale ;

    IMPVertexOut out;
    
    out.position = (float4(position, 1.0) * orthoMatrix) * transform.projection * transform.transition ;
    
    out.texcoord = float2(v.texcoord);
    
    return out;
}

/**
 * View rendering vertex
 */
vertex IMPVertexOut vertex_passview(
                                 device IMPVertexIn* verticies [[ buffer(0) ]],
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
fragment float4 fragment_passthrough(
                                    IMPVertexOut in [[ stage_in ]],
                                    texture2d<float, access::sample> texture [[ texture(0) ]]
                                    ) {
    
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord);
}

