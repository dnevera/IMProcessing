//
//  IMPAdjustment3DLUT_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

//
//  IMPAdjustment_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 17.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPAdjustment3DLUT_metal_h
#define IMPAdjustment3DLUT_metal_h

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
    
    kernel void kernel_adjustLutD3D(
                                    texture2d<float, access::sample>  inTexture       [[texture(0)]],
                                    texture2d<float, access::write>   outTexture      [[texture(1)]],
                                    texture3d<float, access::sample>  lut             [[texture(2)]],
                                    constant IMPAdjustment           &adjustment      [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]){
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        float4 result  = adjustLutD3D(inColor,lut,adjustment);
        outTexture.write(result, gid);
    }
    
    
    kernel void kernel_adjustLutD1D(texture2d<float, access::sample>  inTexture       [[texture(0)]],
                                    texture2d<float, access::write>   outTexture      [[texture(1)]],
                                    texture2d<float, access::sample>  lut             [[texture(2)]],
                                    constant IMPAdjustment           &adjustment      [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]){
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        float4 result  = adjustLutD1D(inColor,lut,adjustment);
        outTexture.write(result, gid);
    }        
}

#endif

#endif

#endif /* IMPAdjustment3DLUT_metal_h */
