//
//  IMPAdjustmentCurves_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentCurves_metal_h
#define IMPAdjustmentCurves_metal_h

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
    /**
     *  Adjusting tone curve by curve texture
     *
     */
    
    inline float4 adjustCurve(
                              float4 inColor,
                              texture1d_array<float, access::sample> curveTexure,
                              constant IMPAdjustment &adjustment
                              )
    {
        
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        half red   = curveTexure.sample(s, inColor.r, 0).x;
        half green = curveTexure.sample(s, inColor.g, 1).x;
        half blue  = curveTexure.sample(s, inColor.b, 2).x;
        
        float4 result = float4(red, green, blue, adjustment.blending.opacity);
        
        if (adjustment.blending.mode == 0)
            result = IMProcessing::blendLuminosity(inColor, result);
        else // only two modes yet
            result = IMProcessing::blendNormal(inColor, result);
        
        
        return result;
    }
    
    kernel void kernel_adjustCurve(texture2d<float, access::sample>        inTexture   [[texture(0)]],
                                   texture2d<float, access::write>         outTexture  [[texture(1)]],
                                   texture1d_array<float, access::sample>  curveTexure [[texture(2)]],
                                   constant IMPAdjustment                  &adjustment [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]])
    {
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustCurve(inColor,curveTexure,adjustment),gid);
    }
}

#endif

#endif

#endif /* IMPAdjustmentCurves_metal_h */


