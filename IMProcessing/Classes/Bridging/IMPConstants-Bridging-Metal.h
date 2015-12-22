//
//  IMPConstants-Bridging-Metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#ifndef IMPConstants_Bridging_Metal_h
#define IMPConstants_Bridging_Metal_h

#ifdef __METAL_VERSION__

# include <metal_stdlib>
using namespace metal;

#ifdef metal_float4
# undef metal_float4
#endif

#ifdef metal_float3
# undef metal_float3
#endif

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

static constant float kIMP_Cielab_X = 95.047;
static constant float kIMP_Cielab_Y = 100.000;
static constant float kIMP_Cielab_Z = 108.883;

// YCbCr luminance(Y) values
static constant metal_float3 kIMP_Y_YCbCr_factor = {0.299, 0.587, 0.114};

// average
static constant metal_float3 kIMP_Y_mean_factor = {0.3333, 0.3333, 0.3333};

// sRGB luminance(Y) values
static constant metal_float3 kIMP_Y_YUV_factor = {0.2125, 0.7154, 0.0721};

static constant metal_float4 kIMP_Reds     = {315.0, 345.0, 15.0,   45.0};
static constant metal_float4 kIMP_Yellows  = { 15.0,  45.0, 75.0,  105.0};
static constant metal_float4 kIMP_Greens   = { 75.0, 105.0, 135.0, 165.0};
static constant metal_float4 kIMP_Cyans    = {135.0, 165.0, 195.0, 225.0};
static constant metal_float4 kIMP_Blues    = {195.0, 225.0, 255.0, 285.0};
static constant metal_float4 kIMP_Magentas = {255.0, 285.0, 315.0, 345.0};


#endif /* IMPConstants_Bridging_Metal_h */
