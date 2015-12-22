//
//  IMPHistogramTypes.h
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPHistogramTypes_h
#define IMPHistogramTypes_h

#ifdef __METAL_VERSION__
# include <metal_stdlib>
#else
# include <stdlib.h>
# define constant const
#endif

# include <simd/simd.h>


///  @brief Histogram width
static constant uint kIMP_HistogramSize        = 256;

///  @brief Maximum channels histogram may contain
static constant uint kIMP_HistogramMaxChannels = 4;

///  @brief Interchangeable integral buffer between Metal host implementation and
/// Metal Shading Language shaders
///
typedef struct IMPHistogramBuffer {
    uint channels[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
}IMPHistogramBuffer;

///  @brief Interchangeable float number buffer
typedef struct {
    float channels[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
}IMPHistogramFloatBuffer;

///  @brief Histogram visualization color options
typedef struct {
    float r,g,b,a;
}IMPHistogramLayerComponent;

struct IMPHistogramLayer {
#ifdef __METAL_VERSION__
    float4                      components[kIMP_HistogramMaxChannels];;
    float4                      backgroundColor;
#else
    vector_float4               components[kIMP_HistogramMaxChannels];;
    vector_float4               backgroundColor;
#endif
    bool                        backgroundSource;
};

typedef struct{
    float saturation;
    float black;
    float white;
} IMPColorWeightsClipping;



#endif /* IMPHistogramTypes_h */
