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


/// @brief Histogram width
#define kIMP_HistogramSize  256

/// @brief Maximum channels histogram may contain
#define kIMP_HistogramMaxChannels 4

/// @brief Interchangeable integral buffer between Metal host implementation and
/// Metal Shading Language shaders
///
typedef struct {
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

///  @brief Histogram layer presentation
struct IMPHistogramLayer {
    IMPHistogramLayerComponent  components[kIMP_HistogramMaxChannels];
    metal_float4                backgroundColor;
    bool                        backgroundSource;
};

///  @brief Color weights clipping preferences
typedef struct{
    float white;
    float black;
    float saturation;
} IMPColorWeightsClipping;


#define kIMP_HistogramCubeThreads      512
#define kIMP_HistogramCubeSize         32768
#define kIMP_HistogramCubeResolution   32
#define kIMP_HistogramCubeIndex(rgb) uint(rgb.r+rgb.g*kIMP_HistogramCubeResolution+rgb.b*kIMP_HistogramCubeResolution*kIMP_HistogramCubeResolution)

typedef struct {
    uint cells[kIMP_HistogramCubeSize];
}IMPHistogramCubeBuffer;

typedef struct{
    metal_float4 color;
}IMPPaletteBuffer;

typedef struct{
    metal_float4     backgroundColor;
    bool             backgroundSource;
}IMPPaletteLayerBuffer;


#endif /* IMPHistogramTypes_h */
