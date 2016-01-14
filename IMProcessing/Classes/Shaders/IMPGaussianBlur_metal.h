//
//  IMPGaussianBlur_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 14.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPGaussianBlur_metal_h
#define IMPGaussianBlur_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    inline float3 kernel_gaussianSampledBlur(
                                             texture2d<float, access::sample> inTexture,
                                             texture2d<float, access::write>  outTexture,
                                             texture1d<float, access::sample> weights,
                                             texture1d<float, access::sample> offsets,
                                             float2 offsetPixel,
                                             uint2 gid){
        
        constexpr sampler p(address::clamp_to_edge, filter::linear, coord::pixel);
        
        float2 texCoord  = float2(gid);
        
        float3 color(0);
        
        for( uint i = 0; i < weights.get_width(); i++ )
        {
            float2 texCoordOffset = offsets.read(i).x * offsetPixel;
            float3 pixel          = inTexture.sample(p, texCoord - texCoordOffset ).rgb;
            pixel += inTexture.sample(p, texCoord + texCoordOffset).rgb;
            color += weights.read(i).x * pixel;
        }
        
        return color;
    }
    
    
    kernel void kernel_gaussianSampledBlurHorizontalPass(
                                                         texture2d<float, access::sample> inTexture         [[texture(0)]],
                                                         texture2d<float, access::write>  outTexture        [[texture(1)]],
                                                         texture1d<float, access::sample> weights           [[texture(2)]],
                                                         texture1d<float, access::sample> offsets           [[texture(3)]],
                                                         uint2 gid [[thread_position_in_grid]]){
        
        float3 color = kernel_gaussianSampledBlur(inTexture,outTexture,weights,offsets,float2(1,0),gid);
        outTexture.write(float4(color,1),gid);
    }
    
    kernel void kernel_gaussianSampledBlurVerticalPass(
                                                       texture2d<float, access::sample> inTexture         [[texture(0)]],
                                                       texture2d<float, access::write>  outTexture        [[texture(1)]],
                                                       texture1d<float, access::sample> weights           [[texture(2)]],
                                                       texture1d<float, access::sample> offsets           [[texture(3)]],
                                                       texture2d<float, access::sample> sourceTexture     [[texture(4)]],
                                                       constant IMPAdjustment           &adjustment       [[buffer(0)]],
                                                       uint2 gid [[thread_position_in_grid]]){
        
        float3 color = kernel_gaussianSampledBlur(inTexture,outTexture,weights,offsets,float2(0,1),gid);
        
        float4 result = IMProcessing::sampledColor(sourceTexture,outTexture,gid);
        
        if (adjustment.blending.mode == 0)
            result = IMProcessing::blendLuminosity(result, float4(color, adjustment.blending.opacity));
        else
            result = IMProcessing::blendNormal(result, float4(color, adjustment.blending.opacity));
        
        outTexture.write(result,gid);
    }
}

#endif

#endif

#endif /* IMPGaussianBlur_metal_h */
