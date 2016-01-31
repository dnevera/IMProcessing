//
//  IMPAdjustmentSHL_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 09.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPAdjustmentSHL_metal_h
#define IMPAdjustmentSHL_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPConstants_metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

//
// https://imagemetalling.wordpress.com/2015/10/30/shadow-correction/
//
namespace IMProcessing
{
    //
    // L-shadows
    //
    inline float compressSH(float Li, float W, float Wt, float Ks){
        return  W / exp( 6 * Ks * Li / Wt) * Wt;
    }
    
    //
    // L-highlights
    //
    inline float compressHL(float Li, float W, float Wt, float Ka){
        return compressSH(1-Li,W,Wt,Ka);
    }
    
    inline float4 adjustShadows(float4 source, float3 shadows, float opacity)
    {
        float3 rgb = source.rgb;
        
        //
        // source https://en.wikipedia.org/wiki/Relative_luminance
        // initial colormetric luminance transform is:
        //    Y = (r,g,b)(0.2126, 0.7152, 0.0722)'
        // but we will use from https://en.wikipedia.org/wiki/YCbCr:
        //    L(rgb)= (r,g,b)(0.299, 0.587, 0.114)'
        //
        float luminance = dot(rgb, kIMP_Y_YCbCr_factor);
        
        float ls = compressSH(luminance,
                      shadows.x,
                      shadows.y,
                      shadows.z);
        
        float  a(opacity * ls);
        
        float3 c(1.0 - pow((1.0 - rgb),4));
        
        return blendNormal (source, float4 (c , a));
    }
    
    inline float4 adjustHighlights(float4 source, float3 highlights, float opacity)
    {
        float3 rgb = source.rgb;
        
        float luminance = dot(rgb, kIMP_Y_YCbCr_factor);
        
        
        float lh = compressHL(luminance,
                      highlights.x,
                      highlights.y,
                      highlights.z);
        
        float  a(opacity * lh);
        
        float3 c(pow(rgb,4));
        
        return blendNormal (source, float4 (c , a));
    }
}

#endif

#endif

#endif /* IMPAdjustmentSHL_metal_h */
