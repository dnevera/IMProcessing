//
//  IMPHistogramTypes.h
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPHistogramTypes_h
#define IMPHistogramTypes_h

#include "IMPConstants-Bridging-Metal.h"


///  @brief Histogram width
#define kIMP_HistogramSize  256

///  @brief Maximum channels histogram may contain
#define kIMP_HistogramMaxChannels 4

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
    metal_float4 color;
    float        width;
}IMPHistogramLayerComponent;

struct IMPHistogramLayer {
    IMPHistogramLayerComponent  components[kIMP_HistogramMaxChannels];
    metal_float4                backgroundColor;
    bool                        backgroundSource;
};

typedef struct{
    float white;
    float black;
    float saturation;
} IMPColorWeightsClipping;



#endif /* IMPHistogramTypes_h */
