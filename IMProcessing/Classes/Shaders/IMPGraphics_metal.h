//
//  IMPGraphics_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 04.05.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPGraphics_metal_h
#define IMPGraphics_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    vertex IMPVertexOut vertex_transformation(
                                              const device IMPVertex*      vertex_array [[ buffer(0) ]],
                                              const device float4x4&       matrix_model [[ buffer(1) ]],
                                              unsigned int vid [[ vertex_id ]]) {
        
        
        IMPVertex in = vertex_array[vid];
        float3 position = float3(in.position);
        
        IMPVertexOut out;
        out.position = matrix_model * float4(position,1);
        out.texcoord = float2(float3(in.texcoord).xy);
        
        return out;
    }
    

    vertex IMPVertexOut vertex_warpTransformation(
                                                  const device IMPVertex*   vertex_array     [[ buffer(0) ]],
                                                  const device float4x4    &homography_model [[ buffer(1) ]],
                                                  unsigned int vid [[ vertex_id ]]) {
        
        
        IMPVertex in = vertex_array[vid];
        float3 position = float3(in.position);
        
        IMPVertexOut out;
        out.position =    homography_model * float4(position,1);
        
        out.texcoord = float2(float3(in.texcoord).xy);
        
        return out;
    }
    
    fragment float4 fragment_transformation(
                                            IMPVertexOut in [[stage_in]],
                                            const device float4  &flip [[ buffer(0) ]],
                                            texture2d<float, access::sample> texture [[ texture(0) ]]
                                            ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        float2 flipHorizontal = flip.xy;
        float2 flipVertical   = flip.zw;
        float2 xy = float2(flipHorizontal.x+in.texcoord.x*flipHorizontal.y, flipVertical.x+in.texcoord.y*flipVertical.y);
        return texture.sample(s, xy);
    }
    
    fragment float4 fragment_passthrough(
                                         IMPVertexOut in [[stage_in]],
                                         texture2d<float, access::sample> texture [[ texture(0) ]]
                                         ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        return texture.sample(s, in.texcoord.xy);
    }

}

typedef struct {
    packed_float2 position;
    packed_float2 texcoord;
} VertexIn;

typedef struct {
    float4 position [[position]];
    float2 texcoord;
} VertexOut;


/**
 * View rendering vertex
 */
vertex VertexOut vertex_passview(
                                 device VertexIn*   verticies [[ buffer(0) ]],
                                 unsigned int        vid       [[ vertex_id ]]
                                 ) {
    VertexOut out;
    
    device VertexIn& v = verticies[vid];
    
    float3 position = float3(float2(v.position) , 0.0);
    
    out.position = float4(position, 1.0);
    
    out.texcoord = float2(v.texcoord);
    
    return out;
}

/**
 *  Pass through fragment
 *
 */
fragment float4 fragment_passview(
                                  VertexOut in [[ stage_in ]],
                                  texture2d<float, access::sample> texture [[ texture(0) ]]
                                  ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    float3 rgb = texture.sample(s, in.texcoord).rgb;
    return float4(rgb, 1.0);
}
#endif

#endif

#endif /* IMPGraphics_metal_h */
