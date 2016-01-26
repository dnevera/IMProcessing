//
//  IMPPerlinNoies_meta.h
//  IMProcessing
//
//  Created by denis svinarchuk on 25.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPPerlinNoise_metal_h
#define IMPPerlinNoise_metal_h

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

    constant float permTexUnit     = 1.0/256.0;    // Perm texture texel-size
    constant float permTexUnitHalf = 0.5/256.0;    // Half perm texture texel-size
    
    constant float grainamount = 0.2; //grain amount
    
    //a random texture generator, but you can also use a pre-computed perturbation texture
    inline float4 rnm(float2 tc, float uTime)
    {
        constexpr float2 k = float2(12.9898,78.233);
        constexpr float  m = 43758.5453;
        float t =  dot(tc + float2(uTime,uTime),k);
        float noise =  sin(t) * m;
        
        float noiseR =  fract(noise)*2.0-1.0;
        float noiseG =  fract(noise*1.2154)*2.0-1.0;
        float noiseB =  fract(noise*1.3453)*2.0-1.0;
        float noiseA =  fract(noise*1.3647)*2.0-1.0;
        
        return float4(noiseR,noiseG,noiseB,noiseA);
    }
    
    inline float fade(float t) {
        return t*t*t*(t*(t*6.0-15.0)+10.0);
    }
    
    inline float pnoise3D(float3 p, float uTime)
    {
        float3 pi = permTexUnit*floor(p)+permTexUnitHalf; // Integer part, scaled so +1 moves permTexUnit texel
        // and offset 1/2 texel to sample texel centers
        float3 pf = fract(p);     // Fractional part for interpolation
        
        // Noise contributions from (x=0, y=0), z=0 and z=1
        float perm00 = rnm(pi.xy,uTime).a ;
        float3  grad000 = rnm(float2(perm00, pi.z),uTime).rgb * 4.0 - 1.0;
        float n000 = dot(grad000, pf);
        float3  grad001 = rnm(float2(perm00, pi.z + permTexUnit),uTime).rgb * 4.0 - 1.0;
        float n001 = dot(grad001, pf - float3(0.0, 0.0, 1.0));
        
        // Noise contributions from (x=0, y=1), z=0 and z=1
        float perm01 = rnm(pi.xy + float2(0.0, permTexUnit),uTime).a ;
        float3  grad010 = rnm(float2(perm01, pi.z),uTime).rgb * 4.0 - 1.0;
        float n010 = dot(grad010, pf - float3(0.0, 1.0, 0.0));
        float3  grad011 = rnm(float2(perm01, pi.z + permTexUnit),uTime).rgb * 4.0 - 1.0;
        float n011 = dot(grad011, pf - float3(0.0, 1.0, 1.0));
        
        // Noise contributions from (x=1, y=0), z=0 and z=1
        float perm10 = rnm(pi.xy + float2(permTexUnit, 0.0),uTime).a ;
        float3  grad100 = rnm(float2(perm10, pi.z),uTime).rgb * 4.0 - 1.0;
        float n100 = dot(grad100, pf - float3(1.0, 0.0, 0.0));
        float3  grad101 = rnm(float2(perm10, pi.z + permTexUnit),uTime).rgb * 4.0 - 1.0;
        float n101 = dot(grad101, pf - float3(1.0, 0.0, 1.0));
        
        // Noise contributions from (x=1, y=1), z=0 and z=1
        float perm11 = rnm(pi.xy + float2(permTexUnit, permTexUnit),uTime).a ;
        float3  grad110 = rnm(float2(perm11, pi.z),uTime).rgb * 4.0 - 1.0;
        float n110 = dot(grad110, pf - float3(1.0, 1.0, 0.0));
        float3  grad111 = rnm(float2(perm11, pi.z + permTexUnit),uTime).rgb * 4.0 - 1.0;
        float n111 = dot(grad111, pf - float3(1.0, 1.0, 1.0));
        
        // Blend contributions along x
        float4 n_x = mix(float4(n000, n001, n010, n011), float4(n100, n101, n110, n111), fade(pf.x));
        
        // Blend contributions along y
        float2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));
        
        // Blend contributions along z
        float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));
        
        // We're done, return the final noise value.
        return n_xyz;
    }
    
    //2d coordinate orientation thing
    inline float2 coordRot(float2 tc, float angle, float width, float height)
    {
        float aspect = width/height;
        float rotX = ((tc.x*2.0-1.0)*aspect*cos(angle)) - ((tc.y*2.0-1.0)*sin(angle));
        float rotY = ((tc.y*2.0-1.0)*cos(angle)) + ((tc.x*2.0-1.0)*aspect*sin(angle));
        rotX = ((rotX/aspect)*0.5+0.5);
        rotY = rotY*0.5+0.5;
        return float2(rotX,rotY);
    }
    
    kernel void kernel_perlinNoise(
                                   texture2d<float, access::sample>            inTexture     [[texture(0)]],
                                   texture2d<float, access::write>             outTexture    [[texture(1)]],
                                   constant IMPFilmGrainAdjustment             &adjustment   [[buffer(0)]],
                                   constant float                             *time          [[buffer(1)]],
                                   uint2 gid [[thread_position_in_grid]]){
        
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::pixel);
        
        float4 inColor  = IMProcessing::sampledColor(inTexture,outTexture,gid);
        
        float width     = float(inTexture.get_width());
        float height    = float(inTexture.get_height());
        float grainsize = adjustment.size * adjustment.scale;
        
        float2 texCoord = float2(gid) * float2(1/width,1/height);
        
        float3 rotOffset  = float3(1.425,3.892,5.835); //rotation offset values
        
        float4 rnd   = IMProcessing::snoise(time[0],inColor);
        
        float2 rotCoordsR = coordRot(texCoord, rnd.x + rotOffset.x, width, height);
        
        float3 noise = float3(pnoise3D(float3(rotCoordsR*float2(width/grainsize,height/grainsize),0.0), time[1]));
        
        float gray   = dot(inColor.rgb, kIMP_Y_YCbCr_factor);
        
        if (adjustment.isColored)
        {
            float coloramount = adjustment.amount.color * smoothstep(1.0,0.0,gray) * smoothstep(1.0,0.0,gray);
            
            float2 rotCoordsG = coordRot(texCoord, rnd.y + rotOffset.y, width, height);
            float2 rotCoordsB = coordRot(texCoord, rnd.z + rotOffset.z, width, height);
            noise.g = mix(noise.r,pnoise3D(float3(rotCoordsG*float2(width/grainsize,height/grainsize),1.0),time[2]),coloramount);
            noise.b = mix(noise.r,pnoise3D(float3(rotCoordsB*float2(width/grainsize,height/grainsize),2.0),time[3]),coloramount);
        }
        
        //noisiness response curve based on scene luminance
        float luminance = mix(0.0,gray,adjustment.amount.luma);
        float lum       = smoothstep(0.2,0.0,luminance);
        lum            += luminance;
        
        noise = mix(noise,float3(0.0),pow(lum,4.0)) * (1.0-pow(luminance, 2.0)) ;
        
        float3 rgb  = inColor.rgb + noise * grainamount * adjustment.amount.total;
        
        float4 result;
        
        if (adjustment.blending.mode == 0)
            result = IMProcessing::blendLuminosity(inColor, float4(rgb, adjustment.blending.opacity));
        else
            result = IMProcessing::blendNormal    (inColor, float4(rgb, adjustment.blending.opacity));
        
        outTexture.write(result,gid);
    }}

#endif

#endif

#endif /* IMPPerlinNoise_metal_h */
