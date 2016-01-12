//
//  IMPAdjustmentWB_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentWB_metal_h
#define IMPAdjustmentWB_metal_h

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
     * White balance adjustment
     * The main idea has been taken from http://zhur74.livejournal.com/44023.html
     */
    
    inline float4 adjustWB(float4 inColor, constant IMPWBAdjustment &adjustment) {
        
        
        float4 dominantColor = float4(adjustment.dominantColor);
        
        float4 invert_color = float4((1.0 - dominantColor.rgb), 1.0);
        
        constexpr float4 grey128 = float4(0.5,    0.5, 0.5,      1.0);
        constexpr float4 grey130 = float4(0.5098, 0.5, 0.470588, 1.0);
        
        invert_color             = blendLuminosity(invert_color, grey128); // compensate brightness
        invert_color             = blendOverlay(invert_color, grey130);    // compensate blue
        
        //
        // write result
        //
        float4 awb = blendOverlay(inColor, invert_color);
        
        float4 result = float4(awb.rgb, adjustment.blending.opacity);
        
        if (adjustment.blending.mode == LUMINOSITY)
            return blendLuminosity(inColor, result);
        else
            return blendNormal(inColor, result);
    }
    
    kernel void kernel_adjustWB(
                                texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                constant IMPWBAdjustment &adjustment [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
        
        float4 inColor = sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustWB(inColor,adjustment),gid);
    }
}

#endif

#endif

#endif /* IMPAdjustmentWB_metal_h */
