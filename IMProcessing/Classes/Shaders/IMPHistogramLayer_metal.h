//
//  IMPHistogramLayer_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 18.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPHistogramLayer_metal_h
#define IMPHistogramLayer_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPConstants_metal.h"
#include "IMPBlending_metal.h"
#include "IMPCommon_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    kernel void kernel_histogramLayer(texture2d<float, access::sample>    inTexture   [[texture(0)]],
                                      texture2d<float, access::write>   outTexture  [[texture(1)]],
                                      constant IMPHistogramFloatBuffer  &histogram  [[buffer(0)]],
                                      constant uint                     &channels   [[buffer(1)]],
                                      constant IMPHistogramLayer        &layer      [[buffer(2)]],
                                      uint2 gid [[thread_position_in_grid]])
    {
        
        constexpr uint Im(kIMP_HistogramSize - 1);
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        
        float  width             = float(outTexture.get_width());
        float  height            = float(outTexture.get_height());
        float  y_position        = (height-float(gid.y));
        
        uint   histogramBinIndex = uint(gid.x/width*Im);   // normalize to histogram length
        float  delim = height;
        
        float4 result;
        if (layer.backgroundSource){
            result = inColor;
        }
        else{
            result = layer.backgroundColor;
        }
        
        for (int c=channels-1; c>=0; c--){
            
            float4 component = layer.components[c].color;
            
            uint   bin       = uint(histogram.channels[c][histogramBinIndex]*delim);   // bin value
            
            float  opacity   = y_position>=bin || y_position<=bin-layer.components[c].width ? 0.0 : 1.0 * component.a;
            
            float4 color     = float4(component.r,component.g,component.b,opacity);
            
            result = IMProcessing::blendNormal(result, color);
        }
        
        outTexture.write(result, gid);
    }
}

#endif

#endif

#endif /* IMPHistogramLayer_metal_h */
