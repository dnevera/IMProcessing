//
//  IMPGaussianBlur_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 14.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPGaussianBlur_metal_h
#define IMPGaussianBlur_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    inline float3 kernel_gaussianSampledBlur(
                                             texture2d<float, access::sample> inTexture,
                                             texture2d<float, access::write>  outTexture,
                                             texture1d<float, access::sample> weights,
                                             texture1d<float, access::sample> offsets,
                                             float2 offsetPixel,
                                             uint2 gid){
        
        constexpr sampler p(address::clamp_to_edge, filter::linear, coord::pixel);
        
        float2 texCoord  = float2(gid);
        
        float3 color(0);
        
        for( uint i = 0; i < weights.get_width(); i++ )
        {
            float2 texCoordOffset = offsets.read(i).x * offsetPixel;
            float3 pixel          = inTexture.sample(p, texCoord - texCoordOffset ).rgb;
            pixel += inTexture.sample(p, texCoord + texCoordOffset).rgb;
            color += weights.read(i).x * pixel;
        }
        
        return color;
    }
    
    
    kernel void kernel_gaussianSampledBlurHorizontalPass(
                                                         texture2d<float, access::sample> inTexture         [[texture(0)]],
                                                         texture2d<float, access::write>  outTexture        [[texture(1)]],
                                                         texture1d<float, access::sample> weights           [[texture(2)]],
                                                         texture1d<float, access::sample> offsets           [[texture(3)]],
                                                         uint2 gid [[thread_position_in_grid]]){
        
        float3 color = kernel_gaussianSampledBlur(inTexture,outTexture,weights,offsets,float2(1,0),gid);
        outTexture.write(float4(color,1),gid);
    }
    
    kernel void kernel_gaussianSampledBlurVerticalPass(
                                                       texture2d<float, access::sample> inTexture         [[texture(0)]],
                                                       texture2d<float, access::write>  outTexture        [[texture(1)]],
                                                       texture1d<float, access::sample> weights           [[texture(2)]],
                                                       texture1d<float, access::sample> offsets           [[texture(3)]],
                                                       texture2d<float, access::sample> sourceTexture     [[texture(4)]],
                                                       constant IMPAdjustment           &adjustment       [[buffer(0)]],
                                                       uint2 gid [[thread_position_in_grid]]){
        
        float3 color = kernel_gaussianSampledBlur(inTexture,outTexture,weights,offsets,float2(0,1),gid);
        
        float4 result = IMProcessing::sampledColor(sourceTexture,outTexture,gid);
        
        if (adjustment.blending.mode == 0)
            result = IMProcessing::blendLuminosity(result, float4(color, adjustment.blending.opacity));
        else
            result = IMProcessing::blendNormal(result, float4(color, adjustment.blending.opacity));
        
        outTexture.write(result,gid);
    }
    
    kernel void  kernel_iirFilterHorizontal(
                                            texture2d<float, access::sample>  inTexture     [[texture(0)]],
                                            texture2d<float, access::write>   outTexture    [[texture(1)]],
                                            device float3*                    inoutBuffer   [[buffer (0)]],
                                            device float3*                    inoutBuffer2  [[buffer (1)]],
                                            constant uint2                    &bufferSize   [[buffer (2)]],
                                            constant int                      &radius       [[buffer (3)]],
                                            texture1d<float, access::sample>  b             [[texture(2)]],
                                            texture1d<float, access::sample>  a             [[texture(3)]],
                                            uint2 gid [[thread_position_in_grid]]){
        
        
        int y     = gid.y;
        int size  = inTexture.get_width();
        int bsize = bufferSize.x;
        int pada  = a.get_width();
        int padb  = b.get_width();
        int pad   = max(pada,padb);
        
        device float3 *row = &inoutBuffer[y*bsize];
        
        for(int i=0; i<bsize; i++) {
            
            for( int j=0; j<padb; j++) {
                int2   xy  = int2(i-j,y);
                row[i] +=  b.read(j).xxx*inTexture.read(uint2(xy)).rgb;
            }
            
            for( int j=1; j<pada; j++) {
                int x = i-j;
                row[i] += row[x] * a.read(j).xxx ;
            }
        }
        
        device float3 *row2 = &inoutBuffer2[y*bsize];
        
        for(int i=bsize-pad-1; i>=0; i--) {
            
            for( int j=0; j<padb; j++) {
                row2[i] +=  b.read(j).xxx*row[i+j];
            }
            
            for( int j=1; j<pada; j++) {
                row2[i] += row2[i+j] * a.read(j).xxx ;
            }
        }
        
        for (int i=0; i<size; i++){
            float3 rgb = row2[i];
            outTexture.write(float4(rgb,1),uint2(i,y));
        }
    }
    
    
    kernel void  kernel_iirFilterVertical(
                                          texture2d<float, access::sample>  inTexture     [[texture(0)]],
                                          texture2d<float, access::write>   outTexture    [[texture(1)]],
                                          device float3*                    inoutBuffer   [[buffer (0)]],
                                          device float3*                    inoutBuffer2  [[buffer (1)]],
                                          constant uint2                    &bufferSize   [[buffer (2)]],
                                          constant int                      &radius       [[buffer (3)]],
                                          texture1d<float, access::sample>  b             [[texture(2)]],
                                          texture1d<float, access::sample>  a             [[texture(3)]],
                                          uint2 gid [[thread_position_in_grid]]){
        
        
        int x     = gid.x;
        int size  = inTexture.get_height();
        int bsize = bufferSize.y;
        int pada  = a.get_width();
        int padb  = b.get_width();
        int pad   = max(pada,padb);
        
        device float3 *row = &inoutBuffer[x*bsize];
        
        for(int i=0; i<bsize; i++) {
            
            for( int j=0; j<padb; j++) {
                int2   xy  = int2(x,i-j);
                row[i] +=  b.read(j).xxx*inTexture.read(uint2(xy)).rgb;
            }
            
            for( int j=1; j<pada; j++) {
                int y = i-j;
                row[i] += row[y] * a.read(j).xxx ;
            }
        }
        
        device float3 *row2 = &inoutBuffer2[x*bsize];
        
        for(int i=bsize-pad-1; i>=0; i--) {
            
            for( int j=0; j<padb; j++) {
                row2[i] +=  b.read(j).xxx*row[i+j];
            }
            
            for( int j=1; j<pada; j++) {
                row2[i] += row2[i+j] * a.read(j).xxx ;
            }
        }
        
        for (int i=0; i<size; i++){
            float3 rgb = row2[i];
            outTexture.write(float4(rgb,1),uint2(x,i));
        }
    }

}

#endif

#endif

#endif /* IMPGaussianBlur_metal_h */
