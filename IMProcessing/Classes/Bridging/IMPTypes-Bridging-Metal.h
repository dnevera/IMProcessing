//
//  IMPTypes.h
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPTypes_h
#define IMPTypes_h

#include "IMPConstants-Bridging-Metal.h"

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
    metal_float4   dominantColor;
    IMPBlending    blending;
} IMPWBAdjustment;

typedef struct{
    float        value;
    IMPBlending  blending;
} IMPValueAdjustment;

typedef struct{
    float        level;
    IMPBlending  blending;
} IMPLevelAdjustment;


typedef struct{
    metal_float4   minimum;
    metal_float4   maximum;
    IMPBlending    blending;
} IMPContrastAdjustment;

typedef struct{
    float hue;
    float saturation;
    float value;
}IMPHSVLevel;

typedef struct {
    IMPHSVLevel   master;
    IMPHSVLevel   levels[kIMP_Color_Ramps];
    IMPBlending   blending;
} IMPHSVAdjustment;

typedef struct {
    float total;
    float color;
    float luma;
}IMPFilmGrainColor;

typedef struct {
    bool                isColored;
    float               size;
    float               scale;
    IMPFilmGrainColor   amount;
    IMPBlending         blending;
} IMPFilmGrainAdjustment;

#endif /* IMPTypes_h */
