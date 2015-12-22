//
//  IMPMetal_main.metal
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#include "IMPStdlib_metal.h"

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

    float3 rgb(IMProcessing::HSV_2_rgb(hsv));
    
    if (adjust.blending.mode == 0)
        return IMProcessing::blendLuminosity(input_color, float4(rgb, adjust.blending.opacity));
    else
        return IMProcessing::blendNormal(input_color, float4(rgb, adjust.blending.opacity));    
}

kernel void kernel_adjustHSV(texture2d<float, access::sample>  inTexture         [[texture(0)]],
                             texture2d<float, access::write>   outTexture        [[texture(1)]],
                             texture1d_array<float, access::sample>  hueWeights  [[texture(2)]],
                             constant IMPHSVAdjustment               &adjustment  [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]){
    
    
    float4 input_color   = inTexture.read(gid);
    
    float4 result =  adjustHSV(input_color, hueWeights, adjustment);
    
    outTexture.write(result, gid);
}

