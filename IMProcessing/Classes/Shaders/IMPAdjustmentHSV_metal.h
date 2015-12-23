//
//  IMPAdjustmentHSB_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentHSB_metal_h
#define IMPAdjustmentHSB_metal_h

#ifdef __METAL_VERSION__

#include "IMPStdlib_metal.h"

using namespace metal;

#include "IMPSwift-Bridging-Metal.h"
#include "IMPConstants_metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

#ifdef __cplusplus

namespace IMProcessing
{
    //
    // HSL/V/B
    //
    inline float weightOf(float hue, texture1d_array<float, access::sample>  weights, uint index){
        //
        // weights should be float32 1d texture array
        //
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        return weights.sample(s, hue, index).x;
    }
    
    inline float3 adjust_lightness(float3 hsv, float levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index)
    {
        float v = 1.0 + levelOut * weightOf(hue,weights,index) * hsv.y;
        hsv.z = clamp(hsv.z * v, 0.0, 1.0);
        return hsv;
    }
    
    
    inline float3 adjust_saturation(float3 hsv, float levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index)
    {
        float v = 1.0 + levelOut * weightOf(hue,weights,index);
        hsv.y = clamp(hsv.y * v, 0.0, 1.0);
        return hsv;
    }
    
    inline float3 adjust_hue(float3 hsv, float levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index){
        
        //
        // hue rotates with overlap ranages
        //
        hsv.x  = hsv.x + 0.5 * levelOut * weightOf(hue,weights,index);
        return hsv;
    }
    
    inline float4 adjustHSV(float4 input_color,
                            texture1d_array<float, access::sample>  hueWeights,
                            constant IMPHSVAdjustment              &adjust
                            ){
        
        float3 hsv = IMProcessing::rgb_2_HSV(input_color.rgb);
        
        float  hue = hsv.x;
        
        for (uint i = 0; i<kIMP_Color_Ramps; i++){
            hsv = adjust_lightness(hsv, adjust.levels[i].value,    hue, hueWeights, i); // BLUES
        }
        
        for (uint i = 0; i<kIMP_Color_Ramps; i++){
            hsv = adjust_saturation(hsv, adjust.levels[i].saturation,    hue, hueWeights, i); // BLUES
        }
        
        for (uint i = 0; i<kIMP_Color_Ramps; i++){
            hsv = adjust_hue(hsv, adjust.levels[i].hue,    hue, hueWeights, i); // BLUES
        }
        
        hsv.z = clamp(hsv.z * (1.0 + adjust.master.value), 0.0, 1.0);
        hsv.y = clamp(hsv.y * (1.0 + adjust.master.saturation), 0.0, 1.0);
        hsv.x  = hsv.x + 0.5 * adjust.master.hue;
        
        float3 rgb(IMProcessing::HSV_2_rgb(hsv));
        
        if (adjust.blending.mode == 0)
            return IMProcessing::blendLuminosity(input_color, float4(rgb, adjust.blending.opacity));
        else
            return IMProcessing::blendNormal(input_color, float4(rgb, adjust.blending.opacity));
    }

    ///
    ///  @brief Kernel HSV adjustment version
    ///
    kernel void kernel_adjustHSV(texture2d<float, access::sample>  inTexture         [[texture(0)]],
                                 texture2d<float, access::write>   outTexture        [[texture(1)]],
                                 texture1d_array<float, access::sample>  hueWeights  [[texture(2)]],
                                 constant IMPHSVAdjustment               &adjustment  [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]){
        
        
        float4 input_color   = inTexture.read(gid);
        
        float4 result =  adjustHSV(input_color, hueWeights, adjustment);
        
        outTexture.write(result, gid);
    }
    
    ///
    /// @brief Kernel optimized HSV adjustment version
    ///
    kernel void kernel_adjustHSV3DLut(
                                      texture3d<float, access::write>         hsv3DLut     [[texture(0)]],
                                      texture1d_array<float, access::sample>  hueWeights   [[texture(1)]],
                                      constant IMPHSVAdjustment               &adjustment  [[buffer(0) ]],
                                      uint3 gid [[thread_position_in_grid]]){
        
        float4 input_color  = float4(float3(gid)/(hsv3DLut.get_width(),hsv3DLut.get_height(),hsv3DLut.get_depth()),1);
        float4 result       = IMProcessing::adjustHSV(input_color, hueWeights, adjustment);
        hsv3DLut.write(result, gid);
    }
}

#endif

#endif

#endif /* IMPAdjustmentHSB_metal_h */
