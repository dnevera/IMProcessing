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

typedef BOOL (^writeInitBlock)( void * _Null_unspecified cinfo,  void *_Null_unspecified*_Null_unspecified userData);
typedef void (^writeFinishBlock)(void  *_Null_unspecified cinfo, void   *_Null_unspecified userData);

@interface IMPJpegturbo : NSObject

+ (id<MTLTexture> _Nullable) updateMTLTexture:(nullable  id<MTLTexture>)texture
                    withPixelFormat:(MTLPixelFormat)pixelFormat
                         withDevice:(nonnull id<MTLDevice>)device
                           fromFile:(nonnull NSString*)filePath
                            maxSize:(CGFloat)maxSize
                              error:(NSError *_Null_unspecified __autoreleasing *_Null_unspecified)error;

+ (nullable NSData*) dataFromMTLTexture:(nonnull id<MTLTexture>)texture
                   compression:(CGFloat)quality;

+ (void) writeMTLTexture:(nonnull id<MTLTexture>)texture
              toJpegFile:(nonnull NSString *)filePath
             compression:(CGFloat)quality
                   error:(NSError *_Null_unspecified __autoreleasing *_Null_unspecified)error;
@end

#endif