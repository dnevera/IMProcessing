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

inline float3 adjust_lightness(float3 hsv, float4 levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index)
{
    float v = levelOut.z * hsv.y ;//* weightOf(hue, weights, index);
    hsv.z = mix (hsv.z * (1.0 + v), hsv.z + (v * (1.0 - hsv.z)), clamp(sign(v), 0.0, 1.0));
    return hsv;
}


inline float3 adjust_saturation(float3 hsv, float4 levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index)
{
    float v = 1.0 + levelOut.y ;//* weightOf(hue,weights,index);
    hsv.y = clamp(hsv.y * v, 0.0, 1.0);
    return hsv;
}

inline float3 adjust_hue(float3 hsv, float4 levelOut, float hue, texture1d_array<float, access::sample>  weights, uint index){
    
    //
    // hue rotates with overlap ranages
    //
    hsv.x  = hsv.x + 0.5 * levelOut.x * weightOf(hue,weights,index);
    return hsv;
}

inline float4 adjustHSV(float4 input_color,
                        texture1d_array<float, access::sample>  hueWeights,
                        constant IMPHSVAdjustment              &adjust
                        ){
    
    float3 hsv = IMProcessing::rgb_2_HSV(input_color.rgb);
    
    float  hue = hsv.x;
    
    float4 areds(adjust.reds);
    float4 ayellows(adjust.yellows);
    float4 agreens(adjust.greens);
    float4 acyans(adjust.cyans);
    float4 ablues(adjust.blues);
    float4 amagentas(adjust.magentas);
    
    //
    // LIGHTNESS photoshop changes before saturation!
    //
    hsv = adjust_lightness(hsv, areds,     hue, hueWeights, 0); // REDS
    hsv = adjust_lightness(hsv, ayellows,  hue, hueWeights, 1); // YELLOWS
    hsv = adjust_lightness(hsv, agreens,   hue, hueWeights, 2); // GREENS
    hsv = adjust_lightness(hsv, acyans,    hue, hueWeights, 3); // CYANS
    hsv = adjust_lightness(hsv, ablues,    hue, hueWeights, 4); // BLUES
    hsv = adjust_lightness(hsv, amagentas, hue, hueWeights, 5); // MAGENTAS
    
    
    //
    // SATURATION!
    //
    hsv = adjust_saturation(hsv, areds,    hue, hueWeights, 0);  // REDS
    hsv = adjust_saturation(hsv, ayellows, hue, hueWeights, 1);  // YELLOWS
    hsv = adjust_saturation(hsv, agreens,  hue, hueWeights, 2);  // GREENS
    hsv = adjust_saturation(hsv, acyans,   hue, hueWeights, 3);  // CYANS
    hsv = adjust_saturation(hsv, ablues,   hue, hueWeights, 4);  // BLUES
    hsv = adjust_saturation(hsv, amagentas,hue, hueWeights, 5);  // MAGENTAS
    
    
    //
    // HUES!
    //
//    hsv = adjust_hue(hsv, areds,     hue, hueWeights, 0); // REDS
//    hsv = adjust_hue(hsv, ayellows,  hue, hueWeights, 1); // YELLOWS
//    hsv = adjust_hue(hsv, agreens,   hue, hueWeights, 2); // GREENS
//    hsv = adjust_hue(hsv, acyans,    hue, hueWeights, 3); // CYANS
    hsv = adjust_hue(hsv, float4(-0.5,0,0,0),    hue, hueWeights, 4); // BLUES
//    hsv = adjust_hue(hsv, amagentas, hue, hueWeights, 5); // MAGENTAS
    
    
    float3 rgb(IMProcessing::HSV_2_rgb(hsv));
    
//    if (adjust.blending.mode == 0)
//        return IMProcessing::blendLuminosity(input_color, float4(rgb, adjust.blending.opacity));
//    else
//        return IMProcessing::blendNormal(input_color, float4(rgb, adjust.blending.opacity));
    
    return IMProcessing::blendNormal(input_color, float4(rgb, 1));
}

kernel void kernel_adjustHSV(texture2d<float, access::sample>  inTexture         [[texture(0)]],
                             texture2d<float, access::write>   outTexture        [[texture(1)]],
                             texture1d_array<float, access::sample>  hueWeights  [[texture(2)]],
                             constant IMPHSVAdjustment               &adjustment [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]){
    
    
    float4 input_color   = inTexture.read(gid);
    
    float4 result =  adjustHSV(input_color, hueWeights, adjustment);
    
    outTexture.write(result, gid);
}

