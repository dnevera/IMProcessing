//
//  IMPTypes.h
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPTypes_h
#define IMPTypes_h

#ifdef __METAL_VERSION__
# include <metal_stdlib>
using namespace metal;

# define metal_float4 float4
# define metal_float3 float3

#else
# include <stdlib.h>
# include <simd/simd.h>

# define constant const
# define metal_float4 vector_float4
# define metal_float3 vector_float3

#endif

# include <simd/simd.h>


struct IMPCropRegion {
    float top;
    float right;
    float left;
    float bottom;
};

typedef enum : uint {
    LUMINOSITY = 0,
    NORMAL
}IMPBlendingMode;

typedef struct {
    IMPBlendingMode    mode;
    float              opacity;
} IMPBlending;

typedef struct{
    IMPBlending    blending;
} IMPAdjustment;


typedef struct{
    packed_float4  dominantColor;
    IMPBlending    blending;
} IMPWBAdjustment;

typedef struct{
    packed_float4  minimum;
    packed_float4  maximum;
    IMPBlending    blending;
} IMPContrastAdjustment;


//typedef struct {
//    packed_float4 reds;
//    packed_float4 yellows;
//    packed_float4 greens;
//    packed_float4 cyans;
//    packed_float4 blues;
//    packed_float4 magentas;
//    IMPBlending   blending;
//} IMPHSVAdjustment;

typedef struct {
    metal_float4 reds;
    metal_float4 yellows;
    metal_float4 greens;
    metal_float4 cyans;
    metal_float4 blues;
    metal_float4 magentas;
    IMPBlending   blending;
} IMPHSVAdjustment;

#endif /* IMPTypes_h */
