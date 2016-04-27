//
//  IMPMain_metal.metal
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "IMPStdlib_metal.h"

vertex IMPVertexOut vertex_transformation(
                                          const device IMPVertex*       vertex_array [[ buffer(0) ]],
                                          const device IMPMatrixModel&  matrix_model [[ buffer(1) ]],
                                          unsigned int vid [[ vertex_id ]]) {
    
    IMPVertex in = vertex_array[vid];
    
    IMPVertexOut out;
    out.position = matrix_model.projectionMatrix * matrix_model.modelMatrix * float4(in.position,1) * matrix_model.transitionMatrix;
    
    out.texcoord = float2(in.texcoord);
    
    return out;
}

fragment float4 fragment_transformation(
                                        IMPVertexOut in [[stage_in]],
                                        texture2d<float, access::sample> texture [[ texture(0) ]]
                                        ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord);
}

