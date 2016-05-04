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
                                              const device IMPMatrixModel&  matrix_model [[ buffer(1) ]],
                                              unsigned int vid [[ vertex_id ]]) {
        
        
        IMPVertex in = vertex_array[vid];
        float3 position = float3(in.position);
        
        IMPVertexOut out;
        out.position = matrix_model.projection * matrix_model.transform * float4(position,1) * matrix_model.transition ;
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
#endif

#endif

#endif /* IMPGraphics_metal_h */
