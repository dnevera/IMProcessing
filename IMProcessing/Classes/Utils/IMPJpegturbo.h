//
//  IMPJpegturbo.h
//  IMProcessing
//
//  Created by denis svinarchuk on 03.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef __METAL_VERSION__

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

typedef BOOL (^writeInitBlock)(void *cinfo, void **userData);
typedef void (^writeFinishBlock)(void *cinfo, void *userData);

@interface IMPJpegturbo : NSObject

+ (id<MTLTexture>) updateMTLTexture:(id<MTLTexture>)texture
                    withPixelFormat:(MTLPixelFormat)pixelFormat
                         withDevice:(id<MTLDevice>)device
                           fromFile:(NSString*)filePath
                            maxSize:(CGFloat)maxSize
                              error:(NSError *__autoreleasing *)error;

+ (NSData*) dataFromMTLTexture:(id<MTLTexture>)texture
                   compression:(CGFloat)quality;

+ (void) writeMTLTexture:(id<MTLTexture>)texture
              toJpegFile:(NSString *)filePath
             compression:(CGFloat)quality
                   error:(NSError *__autoreleasing *)error;
@end

#endif