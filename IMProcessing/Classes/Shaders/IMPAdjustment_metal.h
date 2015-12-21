//
//  IMPAdjustment_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 17.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPAdjustment_metal_h
#define IMPAdjustment_metal_h

#ifdef __METAL_VERSION__

#include "IMPStdlib_metal.h"

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
    
    inline  float4 adjustLutD3D(
                                   float4 inColor,
                                   texture3d<float, access::sample>  lut,
                                   constant IMPAdjustment            &adjustment
                                   ){
        
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        float4 result = lut.sample(s, inColor.rgb);
        result.rgba.a = adjustment.blending.opacity;
        
        if (adjustment.blending.mode == LUMINOSITY) {
            result = blendLuminosity(inColor, result);
        }
        else {// only two modes yet
            result = blendNormal(inColor, result);
        }
        
        return result;
    }
        
    inline float4 adjustLutD1D(
                                   float4 inColor,
                                   texture2d<float, access::sample>  lut,
                                   constant IMPAdjustment            &adjustment
                                   ){
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        half red   = lut.sample(s, float2(inColor.r, 0.0)).r;
        half green = lut.sample(s, float2(inColor.g, 0.0)).g;
        half blue  = lut.sample(s, float2(inColor.b, 0.0)).b;
        
        float4 result = float4(red, green, blue, adjustment.blending.opacity);
        
        if (adjustment.blending.mode == LUMINOSITY) {
            result = blendLuminosity(inColor, result);
        }
        else {// only two modes yet
            result = blendNormal(inColor, result);
        }
        
        return result;
    }
}

#endif

#endif

#endif /* IMPAdjustment_metal_h */
