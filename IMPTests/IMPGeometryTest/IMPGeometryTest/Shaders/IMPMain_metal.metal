//
//  IMPMain_metal.metal
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include "IMPStdlib_metal.h"

typedef struct {
    char4 position;
} IMPBlendVertex;

vertex IMPVertexOut vertex_blending(
                                    const device IMPBlendVertex*  vertex_array [[ buffer(0) ]],
                                    unsigned int vid [[ vertex_id ]]) {
    
    constexpr float scale = 1/128;
    
    IMPBlendVertex in = vertex_array[vid];
    
    IMPVertexOut out;
    out.position = float4(-0.999 + float(in.position.x)*scale,0,0,1);
    out.texcoord = float2(0);
    
    return out;
}

fragment float4 fragment_blending(
                                  IMPVertexOut in [[stage_in]]
                                  ) {
    constexpr float scale = 1/255;
    return float4(scale,1,1,1);
}