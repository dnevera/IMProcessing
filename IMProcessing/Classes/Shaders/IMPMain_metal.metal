//
//  IMPMetal_main.metal
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#include "IMPStdlib_metal.h"

inline void circle_bin_positionPartial(float3 hsv,
                                       device IMPHistogramBuffer *outArray,
                                       constant IMPColorWeightsClipping   &clipping,
                                       threadgroup atomic_int temp[kIMP_HistogramMaxChannels][kIMP_HistogramSize]
                                       ){
    constexpr uint c = 3;
    float      hue =  hsv.x * 360.0;
    int        bin = 0;
    
    //
    // Change REDS
    //
    if ((hue>=IMProcessing::reds.x && hue<=360.0) || (hue>=0.0 && hue<=IMProcessing::reds.w))
        bin = 0;
    
    //
    // Change YELLOWS
    //
    if (hue>=IMProcessing::yellows.x && hue<=IMProcessing::yellows.w)
        bin = 1;
    
    //
    // Change GREENS
    //
    if (hue>=IMProcessing::greens.x && hue<=IMProcessing::greens.w)
        bin = 2;
    
    //
    // Change CYANS
    //
    if (hue>=IMProcessing::cyans.x && hue<=IMProcessing::cyans.w)
        bin = 3;
    
    //
    // Change BLUES
    //
    if (hue>=IMProcessing::blues.x && hue<=IMProcessing::blues.w)
        bin = 4;

    
    //
    // Change MAGENTAS
    //
    if (hue>=IMProcessing::magentas.x && hue<=IMProcessing::magentas.w)
        bin = 5;
    
    if (hsv.y > clipping.saturation)
        atomic_fetch_add_explicit(&(temp[c][bin]), 1, memory_order_relaxed);
    
    if (hsv.y <= clipping.saturation){
        
        if (hsv.z <= clipping.black)
            //
            // Out of black point
            //
            bin = 253;
        else if (hsv.z >= (1.0-clipping.white))
            bin = 254;
        else
            //
            // GRAYS
            //
            bin = 255;
    }
    else
        //
        // COLORED
        //
        bin = 252;
    
    atomic_fetch_add_explicit(&(temp[c][bin]), 1, memory_order_relaxed);
}

///  @brief Compute color weights
///
kernel void kernel_impColorWeightsPartial(
                                          texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                          device   IMPHistogramBuffer        *outArray  [[ buffer(0)]],
                                          constant uint                      &channels  [[ buffer(1)]],
                                          constant IMPCropRegion             &regionIn  [[ buffer(2)]],
                                          constant float                     &scale     [[ buffer(3)]],
                                          constant IMPColorWeightsClipping   &clipping  [[ buffer(4)]],
                                          uint  tid      [[thread_index_in_threadgroup]],
                                          uint2 groupid  [[threadgroup_position_in_grid]],
                                          uint2 groupSize[[threadgroups_per_grid]]
                                          )
{
    threadgroup atomic_int temp[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
    
    uint w      = uint(float(inTexture.get_width())*scale)/groupSize.x;
    uint h      = uint(float(inTexture.get_height())*scale);
    uint size   = w*h;
    uint offset = kIMP_HistogramSize;
    
    for (uint i=0; i<channels; i++){
        atomic_store_explicit(&(temp[i][tid]),0,memory_order_relaxed);
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    for (uint i=0; i<size; i+=offset){
        
        uint  j = i+tid;
        uint2 gid(j%w+groupid.x*w,j/w);
        
        uint4  rgby = IMProcessing::channel_binIndex(inTexture,regionIn,scale,gid);
        
        if (rgby.a>0){
            
            float3 hsv = IMProcessing::rgb_2_HSV(float3(rgby.rgb)/float3(IMProcessing::histogram::Im));
            
            circle_bin_positionPartial(hsv,outArray,clipping,temp);
            
            for (uint c=0;
                 c<channels-1; c++){
                atomic_fetch_add_explicit(&(temp[c][rgby[c]]), 1, memory_order_relaxed);
            }
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    for (uint i=0; i<channels; i++){
        outArray[groupid.x].channels[i][tid]=atomic_load_explicit(&(temp[i][tid]), memory_order_relaxed);
    }
}
