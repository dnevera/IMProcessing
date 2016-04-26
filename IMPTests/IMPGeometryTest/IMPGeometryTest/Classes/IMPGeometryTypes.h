//
//  IMPGeometryTypes.h
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#ifndef IMPGeometryTypes_h
#define IMPGeometryTypes_h

#include "IMPConstants-Bridging-Metal.h"

#ifdef __cplusplus
extern "C" {
#endif
    
#ifdef __METAL_VERSION__

    typedef struct {
        packed_float3 position;
        float2 texcoord;
    } IMPVertexModel;
    
#else
    
    typedef struct {
        float3 position;
        float2 texcoord;
    } IMPVertexModel;
    
#endif
    
    typedef struct {
        float4x4      transform;
        float4x4      projection;
    } IMPMatrixModel;
    
#ifdef __cplusplus
    extern }
#endif

#endif /* IMPGeometryTypes_h */
