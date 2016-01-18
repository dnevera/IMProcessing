//
//  IMPMetal_main.metal
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#include "IMPStdlib_metal.h"


kernel void  kernel_iirFilterHorizontal(
                                            texture2d<float, access::sample>  inTexture     [[texture(0)]],
                                            texture2d<float, access::write>   outTexture    [[texture(1)]],
                                            device float3*                    inoutBuffer   [[buffer (0)]],
                                            device float3*                    inoutBuffer2  [[buffer (1)]],
                                            constant uint2                    &bufferSize   [[buffer (2)]],
                                            constant int                      &radius       [[buffer (3)]],
                                            texture1d<float, access::sample>  b             [[texture(2)]],
                                            texture1d<float, access::sample>  a             [[texture(3)]],
                                            uint2 gid [[thread_position_in_grid]]){
    
    
    int y     = gid.y;
    int size  = inTexture.get_width();
    int bsize = bufferSize.x;
    int pada  = a.get_width();
    int padb  = b.get_width();
    int pad   = max(pada,padb);
    
    device float3 *row = &inoutBuffer[y*bsize];
    
    for(int i=0; i<bsize; i++) {
        
        for( int j=0; j<padb; j++) {
            int2   xy  = int2(i-j,y);
            row[i] +=  b.read(j).xxx*inTexture.read(uint2(xy)).rgb;
        }
        
        for( int j=1; j<pada; j++) {
            int x = i-j;
            row[i] += row[x] * a.read(j).xxx ;
        }
    }
    
    device float3 *row2 = &inoutBuffer2[y*bsize];

    for(int i=bsize-pad-1; i>=0; i--) {
        
        for( int j=0; j<padb; j++) {
            row2[i] +=  b.read(j).xxx*row[i+j];
        }
        
        for( int j=1; j<pada; j++) {
            row2[i] += row2[i+j] * a.read(j).xxx ;
        }
    }

    for (int i=0; i<size; i++){
        float3 rgb = row2[i];
        outTexture.write(float4(rgb,1),uint2(i,y));
    }
}


kernel void  kernel_iirFilterVertical(
                                        texture2d<float, access::sample>  inTexture     [[texture(0)]],
                                        texture2d<float, access::write>   outTexture    [[texture(1)]],
                                        device float3*                    inoutBuffer   [[buffer (0)]],
                                        device float3*                    inoutBuffer2  [[buffer (1)]],
                                        constant uint2                    &bufferSize   [[buffer (2)]],
                                        constant int                      &radius       [[buffer (3)]],
                                        texture1d<float, access::sample>  b             [[texture(2)]],
                                        texture1d<float, access::sample>  a             [[texture(3)]],
                                        uint2 gid [[thread_position_in_grid]]){
    
    
    int x     = gid.x;
    int size  = inTexture.get_height();
    int bsize = bufferSize.y;
    int pada  = a.get_width();
    int padb  = b.get_width();
    int pad   = max(pada,padb);

    device float3 *row = &inoutBuffer[x*bsize];
    
    for(int i=0; i<bsize; i++) {
        
        for( int j=0; j<padb; j++) {
            int2   xy  = int2(x,i-j);
            row[i] +=  b.read(j).xxx*inTexture.read(uint2(xy)).rgb;
        }
        
        for( int j=1; j<pada; j++) {
            int y = i-j;
            row[i] += row[y] * a.read(j).xxx ;
        }
    }
    
    device float3 *row2 = &inoutBuffer2[x*bsize];
    
    for(int i=bsize-pad-1; i>=0; i--) {
        
        for( int j=0; j<padb; j++) {
            row2[i] +=  b.read(j).xxx*row[i+j];
        }
        
        for( int j=1; j<pada; j++) {
            row2[i] += row2[i+j] * a.read(j).xxx ;
        }
    }
    
    for (int i=0; i<size; i++){
        float3 rgb = row2[i];
        outTexture.write(float4(rgb,1),uint2(x,i));
    }
}
