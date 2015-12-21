//
//  IMPStdlib_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 17.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPStdlib_metal_h
#define IMPStdlib_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
#include <simd/simd.h>

#include "IMPSwift-Bridging-Metal.h"
#include "IMPConstants_metal.h"
#include "IMPHistogram_metal.h"
#include "IMPHistogramLayer_metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPBlending_metal.h"
#include "IMPAdjustment_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

#ifdef __cplusplus

namespace IMProcessing
{    
    kernel void kernel_passthrough(texture2d<float, access::sample> inTexture [[texture(0)]],
                                   texture2d<float, access::write> outTexture [[texture(1)]],
                                   uint2 gid [[thread_position_in_grid]])
    {
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        outTexture.write(inColor, gid);
    }
    
    kernel void kernel_adjustWB(
                                texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                constant IMPWBAdjustment &adjustment [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
        
        float4 inColor = sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustWB(inColor,adjustment),gid);
    }
    
    kernel void kernel_adjustContrast(
                                      texture2d<float, access::sample>   inTexture   [[texture(0)]],
                                      texture2d<float, access::write>    outTexture  [[texture(1)]],
                                      constant IMPContrastAdjustment     &adjustment [[buffer(0)]],
                                      uint2 gid [[thread_position_in_grid]]){
        
        float4 inColor = sampledColor(inTexture,outTexture,gid);
        outTexture.write(adjustContrast(inColor,adjustment),gid);
    }

    kernel void kernel_desaturate(texture2d<float, access::sample> inTexture [[texture(0)]],
                                  texture2d<float, access::write> outTexture [[texture(1)]],
                                  uint2 gid [[thread_position_in_grid]])
    {
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        inColor.rgb = float3(dot(inColor.rgb,IMProcessing::Y_mean_factor));
        outTexture.write(inColor, gid);
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

#endif /*IMPStdlib_metal_h*/
