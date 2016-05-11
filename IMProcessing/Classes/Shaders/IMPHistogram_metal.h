//
//  File.metal
//  IMProcessing
//
//  Created by denis svinarchuk on 17.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPHistogram_h
#define IMPHistogram_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
#include "IMPFlowControl_metal.h"
#include "IMPConstants_metal.h"
#include "IMPColorSpaces_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    
    namespace histogram{
        
        static constant float3 Im(kIMP_HistogramSize - 1);
        
        ///  @brief Get a sample acording texture scale factor value.
        ///
        ///  @param inTexture       input texture
        ///  @param scale           scale factor
        ///  @param gid             position thread in grrid, equal x,y coordiant position of pixel in texure
        ///
        ///  @return sampled color value
        ///
        inline float4 sampledColor(
                                   texture2d<float, access::sample> inTexture,
                                   float                   scale,
                                   uint2 gid
                                   ){
            constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
            
            float w = float(inTexture.get_width())  * scale;
            float h = float(inTexture.get_height()) * scale;
            
            return mix(inTexture.sample(s, float2(gid) * float2(1.0/w, 1.0/h)),
                       inTexture.read(gid),
                       IMProcessing::when_eq(inTexture.get_width(), w) // whe equal read exact texture color
                       );
        }
        
        
        ///  @brief Test is there pixel inside in a box or not
        ///
        ///  @param v          pixel coordinate
        ///  @param bottomLeft offset from bottom-left conner
        ///  @param topRight   offset from top-right conner
        ///
        ///  @return 0 or 1
        ///
        inline  float coordsIsInsideBox(float2 v, float2 bottomLeft, float2 topRight) {
            float2 s =  step(bottomLeft, v) - step(topRight, v);
            return s.x * s.y;
        }
        
        inline float4 histogramSampledColor(
                                            texture2d<float, access::sample>  inTexture,
                                            constant IMPRegion               &regionIn,
                                            float                             scale,
                                            uint2 gid){
            
            float w = float(inTexture.get_width())  * scale;
            float h = float(inTexture.get_height()) * scale;
            
            float2 coords  = float2(gid) * float2(1.0/w,1.0/h);
            //
            // для всех пикселей за пределами расчета возвращаем чорную точку с прозрачным альфа-каналом
            //
            float  isBoxed = coordsIsInsideBox(coords, float2(regionIn.left,regionIn.bottom), float2(1.0-regionIn.right,1.0-regionIn.top));
            return sampledColor(inTexture,scale,gid) * isBoxed;
        }        
    }
    
    ///  @brief Compute bin index of a color in input texture.
    ///
    ///  @param inTexture       input texture
    ///  @param regionIn        idents region which explore for the histogram calculation
    ///  @param scale           scale factor
    ///  @param gid             position thread in grrid, equal x,y coordiant position of pixel in texure
    ///
    ///  @return bin index
    ///
    inline uint4 channel_binIndex(
                                  texture2d<float, access::sample>  inTexture,
                                  constant IMPRegion               &regionIn,
                                  constant float                    &scale,
                                  uint2 gid
                                  ){
        
        float4 inColor = histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
        uint   Y       = uint(dot(inColor.rgb, kIMP_Y_YCbCr_factor) * inColor.a * histogram::Im.x);
        
        return uint4(uint3(inColor.rgb * histogram::Im), Y);
    }
    
    ///
    ///  @brief Kernel compute partial histograms
    ///
    kernel void kernel_impHistogramPartial(
                                           texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                           device   IMPHistogramBuffer        *outArray  [[ buffer(0)]],
                                           constant uint                      &channels  [[ buffer(1)]],
                                           constant IMPRegion                 &regionIn  [[ buffer(2)]],
                                           constant float                     &scale     [[ buffer(3)]],
                                           uint  tid      [[thread_index_in_threadgroup]],
                                           uint2 groupid  [[threadgroup_position_in_grid]],
                                           uint2 gridSize [[threadgroups_per_grid]]
                                           )
    {
        threadgroup atomic_int temp[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
        
        uint w      = uint(float(inTexture.get_width())*scale)/gridSize.x;
        uint h      = uint(float(inTexture.get_height())*scale)/gridSize.y;
        uint size   = w*h;
        uint offset = kIMP_HistogramSize;
        
        for (uint i=0; i<channels; i++){
            atomic_store_explicit(&(temp[i][tid]),0,memory_order_relaxed);
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        for (uint i=0; i<size; i+=offset){
            
            uint  j = i+tid;
            uint2 gid(j%w+groupid.x*w,j/w+groupid.y*h);
            
            uint4  rgby = IMProcessing::channel_binIndex(inTexture,regionIn,scale,gid);
            
            if (rgby.a>0){
                for (uint c=0;
                     c<channels; c++){
                    atomic_fetch_add_explicit(&(temp[c][rgby[c]]), 1, memory_order_relaxed);
                }
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        for (uint i=0; i<channels; i++){
            outArray[groupid.y*gridSize.x+groupid.x].channels[i][tid]=atomic_load_explicit(&(temp[i][tid]), memory_order_relaxed);
        }

    }
    
    
    ///  @brief Compute bin index of a color in input texture.
    ///
    ///  @param inTexture       input texture
    ///  @param regionIn        idents region which explore for the histogram calculation
    ///  @param scale           scale factor
    ///  @param gid             position thread in grrid, equal x,y coordiant position of pixel in texure
    ///
    ///  @return bin index
    ///
    typedef struct {
        atomic_uint channels[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
    }IMPHistogramAtomicBuffer;
    
    kernel void kernel_impHistogramAtomic(
                                          texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                          device IMPHistogramAtomicBuffer    &out       [[ buffer(0)]],
                                          constant uint                      &channels  [[ buffer(1)]],
                                          constant IMPRegion                &regionIn  [[ buffer(2)]],
                                          constant float                     &scale     [[ buffer(3)]],
                                          uint2 gid [[thread_position_in_grid]]
                                          )
    {
        constexpr float3 Im(kIMP_HistogramSize - 1);
        float4 inColor = IMProcessing::histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
        uint   Y   = uint(dot(inColor.rgb,kIMP_Y_YCbCr_factor) * inColor.a * Im.x);
        uint4  rgby(uint3(inColor.rgb * Im), Y);
        
        if (inColor.a>0){
            for (uint i=0; i<channels; i++){
                atomic_fetch_add_explicit(&out.channels[i][rgby[i]], 1, memory_order_relaxed);
            }
        }
    }
    
    kernel void kernel_impHistogramVImage(
                                          texture2d<float, access::sample>  inTexture  [[texture(0)]],
                                          texture2d<float, access::write>  outTexture  [[texture(1)]],
                                          constant IMPRegion               &regionIn   [[ buffer(0)]],
                                          constant float                   &scale      [[ buffer(1)]],
                                          uint2 gid [[thread_position_in_grid]]
                                          )
    {
        float4 inColor = IMProcessing::histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
        float   Y   = dot(inColor.rgb,kIMP_Y_YCbCr_factor) * inColor.a;
        float4  rgby = clamp(float4(inColor.rgb, Y),0.0,1.0);
        outTexture.write(rgby,gid);
    }

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
        if ((hue>=kIMP_Reds.x && hue<=360.0) || (hue>=0.0 && hue<=kIMP_Reds.w))
            bin = 0;
        
        //
        // Change YELLOWS
        //
        if (hue>=kIMP_Yellows.x && hue<=kIMP_Yellows.w)
            bin = 1;
        
        //
        // Change GREENS
        //
        if (hue>=kIMP_Greens.x && hue<=kIMP_Greens.w)
            bin = 2;
        
        //
        // Change CYANS
        //
        if (hue>=kIMP_Cyans.x && hue<=kIMP_Cyans.w)
            bin = 3;
        
        //
        // Change BLUES
        //
        if (hue>=kIMP_Blues.x && hue<=kIMP_Blues.w)
            bin = 4;
        
        
        //
        // Change MAGENTAS
        //
        if (hue>=kIMP_Magentas.x && hue<=kIMP_Magentas.w)
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
                                              constant IMPRegion                 &regionIn  [[ buffer(2)]],
                                              constant float                     &scale     [[ buffer(3)]],
                                              constant IMPColorWeightsClipping   &clipping  [[ buffer(4)]],
                                              uint  tid      [[thread_index_in_threadgroup]],
                                              uint2 groupid  [[threadgroup_position_in_grid]],
                                              uint2 gridSize [[threadgroups_per_grid]]
                                              )
    {
        threadgroup atomic_int temp[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
        
        uint w      = uint(float(inTexture.get_width())*scale)/gridSize.x;
        uint h      = uint(float(inTexture.get_height())*scale)/gridSize.y;
        uint size   = w*h;
        uint offset = kIMP_HistogramSize;
        
        for (uint i=0; i<channels; i++){
            atomic_store_explicit(&(temp[i][tid]),0,memory_order_relaxed);
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        for (uint i=0; i<size; i+=offset){
            
            uint  j = i+tid;
            uint2 gid(j%w+groupid.x*w,j/w+groupid.y*h);
            
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
            outArray[groupid.y*gridSize.x+groupid.x].channels[i][tid]=atomic_load_explicit(&(temp[i][tid]), memory_order_relaxed);
        }
    }
    
    inline void circle_bin_positionAtomic(float3 hsv,
                                          device IMProcessing::IMPHistogramAtomicBuffer    &out,
                                          constant IMPColorWeightsClipping   &clipping
                                          ){
        constexpr uint c = 3;
        float      hue =  hsv.x * 360.0;
        int        bin = 0;
        
        //
        // Change REDS
        //
        if ((hue>=kIMP_Reds.x && hue<=360.0) || (hue>=0.0 && hue<=kIMP_Reds.w))
            bin = 0;
        
        //
        // Change YELLOWS
        //
        if (hue>=kIMP_Yellows.x && hue<=kIMP_Yellows.w)
            bin = 1;
        
        //
        // Change GREENS
        //
        if (hue>=kIMP_Greens.x && hue<=kIMP_Greens.w)
            bin = 2;
        
        //
        // Change CYANS
        //
        if (hue>=kIMP_Cyans.x && hue<=kIMP_Cyans.w)
            bin = 3;
        
        //
        // Change BLUES
        //
        if (hue>=kIMP_Blues.x && hue<=kIMP_Blues.w)
            bin = 4;
        
        
        //
        // Change MAGENTAS
        //
        if (hue>=kIMP_Magentas.x && hue<=kIMP_Magentas.w)
            bin = 5;
        
        if (hsv.y > clipping.saturation)
            atomic_fetch_add_explicit(&(out.channels[c][bin]), 1, memory_order_relaxed);
        
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
        
        atomic_fetch_add_explicit(&(out.channels[c][bin]), 1, memory_order_relaxed);
    }
        
    ///  @brief Compute color weights
    ///
    kernel void kernel_impColorWeightsAtomic(
                                             texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                             device IMProcessing::IMPHistogramAtomicBuffer    &out  [[ buffer(0)]],
                                             constant uint                      &channels  [[ buffer(1)]],
                                             constant IMPRegion                 &regionIn  [[ buffer(2)]],
                                             constant float                     &scale     [[ buffer(3)]],
                                             constant IMPColorWeightsClipping   &clipping  [[ buffer(4)]],
                                             uint2 gid [[thread_position_in_grid]]
                                             )
    {
        
        uint4  rgby = IMProcessing::channel_binIndex(inTexture,regionIn,scale,gid);
        float3 hsv = IMProcessing::rgb_2_HSV(float3(rgby.rgb)/float3(IMProcessing::histogram::Im));
        circle_bin_positionAtomic(hsv,out,clipping);
        
        if (rgby.a>0){
            for (uint i=0; i<channels; i++){
                atomic_fetch_add_explicit(&out.channels[i][rgby[i]], 1, memory_order_relaxed);
            }
        }
    }

    inline float2 circle_bin_positionVImage(float3 hsv,
                                            constant IMPColorWeightsClipping   &clipping
                                            ){
        float      hue =  hsv.x * 360.0;
        int        bin = 0;
        float2     cn(0,0);
        
        //
        // Change REDS
        //
        if ((hue>=kIMP_Reds.x && hue<=360.0) || (hue>=0.0 && hue<=kIMP_Reds.w))
            bin = 0;
        
        //
        // Change YELLOWS
        //
        if (hue>=kIMP_Yellows.x && hue<=kIMP_Yellows.w)
            bin = 1;
        
        //
        // Change GREENS
        //
        if (hue>=kIMP_Greens.x && hue<=kIMP_Greens.w)
            bin = 2;
        
        //
        // Change CYANS
        //
        if (hue>=kIMP_Cyans.x && hue<=kIMP_Cyans.w)
            bin = 3;
        
        //
        // Change BLUES
        //
        if (hue>=kIMP_Blues.x && hue<=kIMP_Blues.w)
            bin = 4;
        
        
        //
        // Change MAGENTAS
        //
        if (hue>=kIMP_Magentas.x && hue<=kIMP_Magentas.w)
            bin = 5;
        
        if (hsv.y > clipping.saturation){
            cn.x = float(bin);
        }
        
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
        
        cn.y = float(bin);
        
        return cn;
    }
    
    ///  @brief Compute color weights
    ///
    kernel void kernel_impColorWeightsVImage(
                                             texture2d<float, access::sample>   inTexture  [[texture(0)]],
                                             texture2d<float, access::write>  outTexture   [[texture(1)]],
                                             constant IMPRegion                 &regionIn  [[ buffer(0)]],
                                             constant float                     &scale     [[ buffer(1)]],
                                             constant IMPColorWeightsClipping   &clipping  [[ buffer(2)]],
                                             uint2 gid [[thread_position_in_grid]]
                                             )
    {
        
        float4 inColor = IMProcessing::histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
        
        float3 hsv = IMProcessing::rgb_2_HSV(inColor.rgb);
        
        float2 cn = circle_bin_positionVImage(hsv,clipping)/IMProcessing::histogram::Im.x;
        
        inColor.a = cn.x;
        inColor.b = cn.y;
        
        float4  rgby = clamp(inColor,0.0,1.0);

        outTexture.write(rgby,gid);
    }
    
    
    typedef struct {
        atomic_uint count;
        atomic_uint reds;
        atomic_uint greens;
        atomic_uint blues;
    } IMPHistogramCubeCellAtomic;
    
    typedef struct {
        IMPHistogramCubeCellAtomic cells[kIMP_HistogramCubeSize];
    }IMPHistogramCubeAtomicBuffer;
    
    ///
    ///  @brief Kernel compute partial histograms
    ///
    
    typedef struct{
        uint4 index;
        uint4 value;
    }IMPHistogramCubeValue;
    
    inline IMPHistogramCubeValue cube_binIndex(
                                               texture2d<float, access::sample>  inTexture,
                                               constant IMPRegion               &regionIn,
                                               constant float                    &scale,
                                               uint2 gid
                                               ){
        
        float4 inColor = IMProcessing::histogram::histogramSampledColor(inTexture,regionIn,scale,gid);
        IMPHistogramCubeValue value;
        value.index = uint4(uint3(inColor.rgb * (kIMP_HistogramCubeResolution-1)),inColor.a * (kIMP_HistogramCubeResolution-1));
        value.value = uint4(uint3(inColor.rgb * (kIMP_HistogramSize-1)),inColor.a * (kIMP_HistogramSize-1));
        return value;
    }
    
    
    
    ///
    ///  @brief Kernel compute partial histograms
    ///
    kernel void kernel_impHistogramCubePartial(
                                               texture2d<float, access::sample>      inTexture  [[texture(0)]],
                                               device   IMPHistogramCubeAtomicBuffer *outArray  [[ buffer(0)]],
                                               constant IMPRegion                    &regionIn [[ buffer(1)]],
                                               constant float                         &scale    [[ buffer(2)]],
                                               constant IMPHistogramCubeClipping      &clipping [[ buffer(3)]],
                                               uint tid       [[thread_index_in_threadgroup]],
                                               uint2 groupid  [[threadgroup_position_in_grid]],
                                               uint2 groupSize[[threadgroups_per_grid]],
                                               uint2 thsize   [[threads_per_threadgroup]]
                                               )
    {
        uint w      = uint(float(inTexture.get_width())*scale)/groupSize.x;
        uint h      = uint(float(inTexture.get_height())*scale);
        uint size   = w*h;
        uint offset = thsize.x;
        
        for (uint i=0; i<size; i+=offset){
            
            uint  j = i+tid;
            uint2 gid(j%w+groupid.x*w,j/w);
            
            IMPHistogramCubeValue  rgby = cube_binIndex(inTexture,regionIn,scale,gid);
            
            float3 shadows    = (float3(rgby.value.rgb)/float(kIMP_HistogramSize-1));
            float3 highlights = 1.0-(float3(rgby.value.rgb)/float(kIMP_HistogramSize-1));
            
            if (clipping.shadows.r>shadows.r && clipping.shadows.g>shadows.g && clipping.shadows.b>shadows.b){
                continue;
            }
            
            if (clipping.highlights.r>highlights.r && clipping.highlights.g>highlights.g && clipping.highlights.b>highlights.b){
                continue;
            }
            
            
            if (rgby.index.a>0){
                uint index = kIMP_HistogramCubeIndex(rgby.index);
                atomic_fetch_add_explicit(&(outArray[groupid.x].cells[index].count),  1, memory_order_relaxed);
                atomic_fetch_add_explicit(&(outArray[groupid.x].cells[index].reds),   rgby.value.r, memory_order_relaxed);
                atomic_fetch_add_explicit(&(outArray[groupid.x].cells[index].greens), rgby.value.g, memory_order_relaxed);
                atomic_fetch_add_explicit(&(outArray[groupid.x].cells[index].blues),  rgby.value.b, memory_order_relaxed);
            }
        }
    }
    
    
}

#endif

#endif

#endif
