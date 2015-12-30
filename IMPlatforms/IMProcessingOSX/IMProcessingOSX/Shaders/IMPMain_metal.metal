//
//  IMPMetal_main.metal
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#include "IMPStdlib_metal.h"


typedef struct {
    atomic_uint cells[kIMP_HistogramCubeSize];
}IMPHistogramCubeAtomicBuffer;


///
///  @brief Kernel compute partial histograms
///

inline uint4 cube_binIndex(
                           texture2d<float, access::sample>  inTexture,
                           constant IMPCropRegion          &regionIn,
                           constant float                    &scale,
                           uint2 gid
                           ){
    
    float4 inColor = IMProcessing::histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
    return uint4(uint3(inColor.rgb * (kIMP_HistogramCubeResolution-1)),inColor.a * (kIMP_HistogramCubeResolution-1));
}



///
///  @brief Kernel compute partial histograms
///
kernel void kernel_impHistogramCubePartial(
                                           texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                           device   IMPHistogramCubeBuffer    *outArray  [[ buffer(0)]],
                                           constant IMPCropRegion             &regionIn  [[ buffer(1)]],
                                           constant float                     &scale     [[ buffer(2)]],
                                           uint tid       [[thread_index_in_threadgroup]],
                                           uint2 groupid  [[threadgroup_position_in_grid]],
                                           uint2 groupSize[[threadgroups_per_grid]],
                                           uint2 thsize   [[threads_per_threadgroup]]
                                           )
{
    threadgroup atomic_uint temp[kIMP_HistogramCubeSize];
    
    uint w      = uint(float(inTexture.get_width())*scale)/groupSize.x;
    uint h      = uint(float(inTexture.get_height())*scale);
    uint size   = w*h;
    uint offset = thsize.x;
    uint blocks = kIMP_HistogramCubeSize/thsize.x;
    
    for (uint i=0; i<blocks; i++){
        atomic_store_explicit(&(temp[tid + i*thsize.x]),0,memory_order_relaxed);
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    for (uint i=0; i<size; i+=offset){
        
        uint  j = i+tid;
        uint2 gid(j%w+groupid.x*w,j/w);
        
        uint4  rgby = cube_binIndex(inTexture,regionIn,scale,gid);
        
        if (rgby.a>0){
            uint index = kIMP_HistogramCubeIndex(rgby.rgb);
            atomic_fetch_add_explicit(&(temp[index]), 1, memory_order_relaxed);
            //atomic_fetch_add_explicit(&(outArray[groupid.x].cells[index]), 1, memory_order_relaxed);
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    for (uint i=0; i<blocks; i++){
        outArray[groupid.x].cells[tid + i*thsize.x] = atomic_load_explicit(&(temp[tid + i*thsize.x]), memory_order_relaxed);
    }
}

