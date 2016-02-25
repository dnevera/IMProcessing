//
//  IMPAdjustmentSaturation_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 24.02.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentSaturation_metal_h
#define IMPAdjustmentSaturation_metal_h

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

    inline float4 adjustSaturation(float4 inColor, constant IMPLevelAdjustment &adjustment) {
        
        float3 grayScale = float3(dot(inColor.rgb,kIMP_Y_YCbCr_factor));

        float4 result = float4(mix(grayScale, inColor.rgb, adjustment.level * 2), adjustment.blending.opacity);
        
        if (adjustment.blending.mode == LUMINOSITY)
            return blendLuminosity(inColor, result);
        else
            return blendNormal(inColor, result);
    }
    
    kernel void kernel_adjustSaturation(
                                texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                constant IMPLevelAdjustment &adjustment [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
        
        float4 inColor = sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustSaturation(inColor,adjustment),gid);
    }
}

#endif

#endif

#endif /* IMPAdjustmentSaturation_metal_h */
