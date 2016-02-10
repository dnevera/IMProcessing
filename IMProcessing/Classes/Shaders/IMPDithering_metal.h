//
//  IMPRandomDither_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 27.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPRandomDither_metal_h
#define IMPRandomDither_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"
#include "IMPRandomNoise_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    kernel void kernel_dithering(
                                 texture2d<float, access::sample>        inTexture   [[texture(0)]],
                                 texture2d<float, access::write>         outTexture  [[texture(1)]],
                                 texture2d<float, access::sample>        ditherLut   [[texture(2)]],
                                 constant IMPAdjustment                  &adjustment [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]])
    {
        float4 inColor = IMProcessing::sampledColor(inTexture, outTexture, gid);
        
        uint   w  = ditherLut.get_width();
        uint   h  = ditherLut.get_height();
        
        uint   size  = w*h;
        uint   denom = 256/size;
        uint2  xy    = uint2(gid.x % w, gid.y % h);
        
        float  threshold = ditherLut.read(xy).x;
        float3 rgb      = inColor.rgb/float3(denom);
        
        float  r = rgb.r;
        float  g = rgb.g;
        float  b = rgb.b;
        
        if (r > threshold) r = float(1);
        else r = 0;
        if (g > threshold) g = float(1);
        else g = 0;
        if (b > threshold) b = float(1);
        else b = 0;
        
        rgb = float3(r,g,b);
        
        float4 result;
        
        if (adjustment.blending.mode == 0)
            result = IMProcessing::blendLuminosity(inColor, float4(rgb,adjustment.blending.opacity));
        else // only two modes yet
            result = IMProcessing::blendNormal(inColor, float4(rgb,adjustment.blending.opacity));
        
        outTexture.write(result,gid);
    }
}
#endif
    
#endif
    
#endif /* IMPRandomDither_metal_h */
