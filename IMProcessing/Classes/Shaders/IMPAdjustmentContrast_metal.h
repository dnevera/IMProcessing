//
//  IMPAdjustmentContrast_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentContrast_metal_h
#define IMPAdjustmentContrast_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPConstants_metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    inline float4 adjustContrast(float4 inColor, constant IMPContrastAdjustment &adjustment){
        float4 result = inColor;
        
        float3 alow  = float4(adjustment.minimum).rgb;
        float3 ahigh = float4(adjustment.maximum).rgb;
        
        result.rgb  = clamp((result.rgb - alow)/(ahigh-alow), float3(0.0), float3(1.0));
        
        if (adjustment.blending.mode == LUMINOSITY) {
            result = blendLuminosity(inColor, float4(result.rgb, adjustment.blending.opacity));
        }
        else {// only two modes yet
            result = blendNormal(inColor, float4(result.rgb, adjustment.blending.opacity));
        }
        
        return result;
    }
    
    kernel void kernel_adjustContrast(
                                      texture2d<float, access::sample>   inTexture   [[texture(0)]],
                                      texture2d<float, access::write>    outTexture  [[texture(1)]],
                                      constant IMPContrastAdjustment     &adjustment [[buffer(0)]],
                                      uint2 gid [[thread_position_in_grid]]){
        
        float4 inColor = sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustContrast(inColor,adjustment),gid);
    }
}

#endif

#endif

#endif /* IMPAdjustmentContrast_metal_h */
