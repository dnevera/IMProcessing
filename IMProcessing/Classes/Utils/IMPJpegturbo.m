//
//  IMPJpegturbo.m
//  IMProcessing
//
//  Created by denis svinarchuk on 03.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#import "IMPJpegturbo.h"

#import <ImageIO/ImageIO.h>
#import <stdio.h>
#import <jpeglib.h>
#import <setjmp.h>

@import Security;

struct DPJpegErrorMgr {
    struct jpeg_error_mgr pub;    /* "public" fields */
    jmp_buf setjmp_buffer;        /* for return to caller */
};

typedef struct DPJpegErrorMgr         *DPJpegErrorRef;
typedef struct jpeg_decompress_struct  DPJpegDecompressInfo;

/*
 * Here's the routine that will replace the standard error_exit method:
 */

static void my_error_exit (j_common_ptr cinfo)
{
    /* cinfo->err really points to a my_error_mgr struct, so coerce pointer */
    DPJpegErrorRef myerr = (DPJpegErrorRef) cinfo->err;
    
    /* Always display the message. */
    /* We could postpone this until after returning, if we chose. */
    (*cinfo->err->output_message) (cinfo);
    
    /* Return control to the setjmp point */
    longjmp(myerr->setjmp_buffer, 1);
}


/**
 * Save jpeg in NSMutableData object
 */
typedef struct {
    struct jpeg_destination_mgr pub;
    void   *jpegData;
} mem_destination_mgr;

typedef mem_destination_mgr *mem_dest_ptr;

#define BLOCK_SIZE 4096

METHODDEF(void) init_destination(j_compress_ptr cinfo)
{
    mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
    NSMutableData  *data = (__bridge NSMutableData *)(dest->jpegData);
    dest->pub.next_output_byte = (JOCTET *)data.mutableBytes;
    dest->pub.free_in_buffer   = data.length;
}

METHODDEF(boolean) empty_output_buffer(j_compress_ptr cinfo)
{
    mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
    NSMutableData  *data = (__bridge NSMutableData *)(dest->jpegData);
    
    size_t oldsize = data.length;
    [data setLength: oldsize + BLOCK_SIZE];
    
    dest->pub.next_output_byte = &data.mutableBytes[oldsize];
    dest->pub.free_in_buffer   =  data.length - oldsize;
    
    return true;
}

METHODDEF(void) term_destination(j_compress_ptr cinfo)
{
    mem_dest_ptr dest = (mem_dest_ptr) cinfo->dest;
    NSMutableData  *data = (__bridge NSMutableData *)(dest->jpegData);
    [data setLength:data.length-dest->pub.free_in_buffer];
}

static GLOBAL(void) jpeg_mem_dest_dp(j_compress_ptr cinfo, NSData* data)
{
    mem_dest_ptr dest;
    
    if (cinfo->dest == NULL) {
        cinfo->dest = (struct jpeg_destination_mgr *)
        (*cinfo->mem->alloc_small)((j_common_ptr)cinfo, JPOOL_PERMANENT,
                                   sizeof(mem_destination_mgr));
    }
    
    dest = (mem_dest_ptr) cinfo->dest;
    
    dest->jpegData = (__bridge void *)(data);
    
    dest->pub.init_destination    = init_destination;
    dest->pub.empty_output_buffer = empty_output_buffer;
    dest->pub.term_destination    = term_destination;
}

//
// IMP jpegturbo interface
//
@implementation IMPJpegturbo

+ (id<MTLTexture> _Nullable) updateMTLTexture:(nullable id<MTLTexture>)textureIn withPixelFormat:(MTLPixelFormat)pixelFormat withDevice:(id<MTLDevice>)device fromFile:(NSString*)filePath  maxSize:(CGFloat)maxSize  error:(NSError *__autoreleasing *)error{
    
    
    
    const char *filename = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    DPJpegDecompressInfo cinfo;
    struct DPJpegErrorMgr jerr;
    FILE         *infile;           /* source file */
    JSAMPARRAY    buffer;           /* Output row buffer */
    int           row_stride;       /* physical row width in output buffer */
    
    
    if ((infile = fopen(filename, "rb")) == NULL) {
        if (error) {
            *error = [[NSError alloc ] initWithDomain:@"com.improcessing.jpeg.read"
                                                 code: ENOENT
                                             userInfo: @{
                                                         NSLocalizedDescriptionKey:  [NSString stringWithFormat:NSLocalizedString(@"Image file %@ can't be open", ""),filePath],
                                                         NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"File not found", ""),
                                                         }];
        }
        return textureIn;
    }
    
    /* Step 1: allocate and initialize JPEG decompression object */
    
    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = my_error_exit;
    if (setjmp(jerr.setjmp_buffer)) {
        jpeg_destroy_decompress(&cinfo);
        fclose(infile);
        
        if (error) {
            *error = [[NSError alloc ] initWithDomain:@"com.improcessing.jpeg.read"
                                                 code: ENOENT
                                             userInfo: @{
                                                         NSLocalizedDescriptionKey: NSLocalizedString(@"Not enough memory to write jpeg file", ""),
                                                         NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Not enough memory", ""),
                                                         }];
        }
        
        return textureIn;
    }
    jpeg_create_decompress(&cinfo);
    
    
    /* Step 2: specify data source (eg, a file) */
    
    jpeg_stdio_src(&cinfo, infile);
    
    
    /* Step 3: read file parameters with jpeg_read_header() */
    
    (void) jpeg_read_header(&cinfo, TRUE);
    
    
    /* Step 4: set parameters for decompression */
    
    cinfo.out_color_space = JCS_EXT_RGBA;
    
    /* In this example, we don't need to change any of the defaults set by
     * jpeg_read_header(), so we do nothing here.
     */
    
    float scale = 1.0;
    
    if (maxSize>0.0 && maxSize<fmin(cinfo.image_width,cinfo.image_height) ) {
        scale = fmin(maxSize/cinfo.image_width,maxSize/cinfo.image_height) ;
    }
    
    cinfo.scale_num   = scale<1.0f?1:scale;
    cinfo.scale_denom = scale<1.0f?(unsigned int)floor(1.0f/scale):1;
    
    /* Step 5: Start decompressor */
    
    (void) jpeg_start_decompress(&cinfo);
    
    row_stride = cinfo.output_width * cinfo.output_components;
    buffer = (*cinfo.mem->alloc_sarray)
    ((j_common_ptr) &cinfo, JPOOL_IMAGE, row_stride, 1);
    
    
    /* Step 6: while (scan lines remain to be read) */
    
    NSUInteger width  = cinfo.output_width;
    NSUInteger height = cinfo.output_height;
    
    @autoreleasepool {
        
        
        id<MTLTexture> texture = textureIn;
        
        if (texture == nil
            ||
            [texture width]!=width
            ||
            [texture height]!=height
            ){
            MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                                                                         width:width
                                                                                                        height:height
                                                                                                     mipmapped:NO];
            texture = [device newTextureWithDescriptor:textureDescriptor];
        }
        
        while (cinfo.output_scanline < cinfo.output_height) {
            
            (void) jpeg_read_scanlines(&cinfo, buffer, 1);
            
            if (texture.pixelFormat == MTLPixelFormatRGBA16Unorm) {
                int componentsPerPixel = 4;
                int componentsPerRow   = componentsPerPixel * cinfo.output_width;
                uint16_t u16[sizeof(uint16_t)*componentsPerRow];
                
                for (int i=0; i < componentsPerRow; i++) {
                    uint16_t  pixel = 0;
                    uint8_t  *address = buffer[0]+i;
                    memcpy(&pixel, address, sizeof(uint8_t));
                    u16[i] = (uint16_t)(pixel<<8);
                }
                [texture replaceRegion:MTLRegionMake2D(0, cinfo.output_scanline-1, cinfo.output_width, 1)
                           mipmapLevel:0
                             withBytes:u16
                           bytesPerRow:row_stride*sizeof(uint16_t)/sizeof(uint8_t)];
            }
            else{
                [texture replaceRegion:MTLRegionMake2D(0, cinfo.output_scanline-1, cinfo.output_width, 1)
                           mipmapLevel:0
                             withBytes:buffer[0]
                           bytesPerRow:row_stride];
            }
        }
        
        /* Step 7: Finish decompression */
        
        (void) jpeg_finish_decompress(&cinfo);
        
        /* Step 8: Release JPEG decompression object */
        
        jpeg_destroy_decompress(&cinfo);
        fclose(infile);
        
        return texture;
    }
}


+ (void) updateJpegWithMTLTexture:(nonnull id<MTLTexture>)texture
                   writeInitBlock:(writeInitBlock)writeInitBlock
                 writeFinishBlock:(writeFinishBlock)writeFinishBlock
                          quality:(CGFloat)qualityIn error:(NSError *__autoreleasing *)error{
    
    @autoreleasepool {
        int quality = round(qualityIn*100.0f); quality=quality<=0?10:quality>100?100:quality;
        
        struct jpeg_compress_struct cinfo;
        struct jpeg_error_mgr jerr;
        
        JSAMPROW row_pointer[1];      /* pointer to JSAMPLE row[s] */
        int row_stride;               /* physical row width in image buffer */
        
        /* Step 1: allocate and initialize JPEG compression object */
        
        cinfo.err = jpeg_std_error(&jerr);
        jpeg_create_compress(&cinfo);
        
        
        void *userData;
        if (!writeInitBlock(&cinfo,&userData)) {
            return;
        }
        
        /* Step 3: set parameters for compression */
        
        cinfo.image_width  = (int)[texture width];      /* image width and height, in pixels */
        cinfo.image_height = (int)[texture height];
        cinfo.input_components = 4;           /* # of color components per pixel */
        if (
            [texture pixelFormat] == MTLPixelFormatBGRA8Unorm
            ||
            [texture pixelFormat] == MTLPixelFormatBGRA8Unorm_sRGB
            ) {
            cinfo.in_color_space = JCS_EXT_BGRA;  /* colorspace of input image */
        }
        else if (
                 [texture pixelFormat] == MTLPixelFormatRGBA8Unorm
                 ||
                 [texture pixelFormat] == MTLPixelFormatRGBA8Unorm_sRGB
                 ) {
            cinfo.in_color_space = JCS_EXT_RGBA;  /* colorspace of input image */
        }
        else if (
                 [texture pixelFormat] == MTLPixelFormatRGBA16Unorm
                 ) {
            cinfo.in_color_space = JCS_EXT_RGBA;
        }
        
        jpeg_set_defaults(&cinfo);
        jpeg_set_quality(&cinfo, quality, TRUE /* limit to baseline-JPEG values */);
        
        
        /* Step 4: Start compressor */
        
        jpeg_start_compress(&cinfo, TRUE);
        
        /* Step 5: while (scan lines remain to be written) */
        /*           jpeg_write_scanlines(...); */
        
        row_stride = (int)cinfo.image_width  * cinfo.input_components; /* JSAMPLEs per row in image_buffer */
        
        uint    counts        = cinfo.image_width * 4;
        uint    componentSize = sizeof(uint8_t);
        uint8_t *tmp = NULL;
        if (texture.pixelFormat == MTLPixelFormatRGBA16Unorm) {
            tmp  = malloc(row_stride);
            row_stride *= 2;
            componentSize = sizeof(uint16_t);
        }
        
#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
        //
        // Synchronize texture with host memory
        //
        id<MTLCommandQueue> queue             = [texture.device newCommandQueue];
        id<MTLCommandBuffer> commandBuffer    = [queue commandBuffer];
        id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
        
        [blitEncoder synchronizeTexture:texture slice:0 level:0];
        [blitEncoder endEncoding];
        
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
#endif
        void       *image_buffer  = malloc(row_stride);
        
        int j=0;
        while (cinfo.next_scanline < cinfo.image_height) {
            
            MTLRegion region = MTLRegionMake2D(0, cinfo.next_scanline, cinfo.image_width, 1);
            
            [texture getBytes:image_buffer
                  bytesPerRow:cinfo.image_width * 4 * componentSize
                   fromRegion:region
                  mipmapLevel:0];
            
            if (texture.pixelFormat == MTLPixelFormatRGBA16Unorm) {
                uint16_t *s = image_buffer;
                for (int i=0; i<counts; i++) {
                    tmp[i] = (s[i]>>8) & 0xff;
                    j++;
                }
                row_pointer[0] = tmp;
            }
            else{
                row_pointer[0] = image_buffer;
            }
            (void) jpeg_write_scanlines(&cinfo, row_pointer, 1);
        }
        
        free(image_buffer);
        if (tmp != NULL) free(tmp);
        
        /* Step 6: Finish compression */
        jpeg_finish_compress(&cinfo);
        
        /* After finish_compress, we can clear user data. */
        writeFinishBlock(&cinfo,userData);
        
        /* Step 7: release JPEG compression object */
        jpeg_destroy_compress(&cinfo);
        
    }
}


+ (nullable NSData*) dataFromMTLTexture:(nonnull id<MTLTexture>)texture
                            compression:(CGFloat)qualityIn{
    
    __block NSMutableData *data = [NSMutableData dataWithCapacity:BLOCK_SIZE];
    
    if (data) {
        [IMPJpegturbo updateJpegWithMTLTexture:texture
                                writeInitBlock:^BOOL(void *in_cinfo, void **userData) {
                                    struct jpeg_compress_struct *cinfo = in_cinfo;
                                    [data setLength:BLOCK_SIZE];
                                    jpeg_mem_dest_dp(cinfo, data);
                                    return YES;
                                } writeFinishBlock:^(void *in_cinfo, void *userData) {
                                } quality:qualityIn error:nil
         ];
    }
    
    
    return data;
}

+ (void) writeMTLTexture:(id<MTLTexture>)texture
              toJpegFile:(NSString *)filePath
             compression:(CGFloat)qualityIn
                   error:(NSError *__autoreleasing *)error{
    
    __block const char *filename = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    [[self class] updateJpegWithMTLTexture:texture
                            writeInitBlock:^BOOL(void *in_cinfo, void **userData) {
                                
                                struct jpeg_compress_struct *cinfo = in_cinfo;
                                
                                FILE * outfile;               /* target file */
                                /* Step 2: specify data destination (eg, a file) */
                                if ((outfile = fopen(filename, "wb")) == NULL) {
                                    if (error) {
                                        *error = [[NSError alloc ] initWithDomain:@"com.improcessing.jpeg.write"
                                                                             code: ENOENT
                                                                         userInfo: @{
                                                                                     NSLocalizedDescriptionKey:  [NSString stringWithFormat:NSLocalizedString(@"Image file %@ can't be created", nil),filename],
                                                                                     NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"File can't be created", nil),
                                                                                     }];
                                    }
                                    return NO;
                                }
                                jpeg_stdio_dest(cinfo, outfile);
                                
                                *userData = outfile;
                                
                                return YES;
                                
                            } writeFinishBlock:^(void *cinfo, void *userData) {
                                /* After finish_compress, we can close the output file. */
                                FILE * outfile = userData;
                                fflush(outfile);
                                fclose(outfile);
                            } quality:qualityIn error:error
     ];
}

+ (BOOL) writePixelBuffer:(CVPixelBufferRef)pixelBuffer
               toJpegFile:(NSString *)path
              compression:(CGFloat)compressionQ
          inputColorSpace:(IMPJpegColorSpace)colorSpace
                    error:(NSError *__autoreleasing *)error
{
    
    int quality = round(compressionQ*100.0f); quality=quality<=0?10:quality>100?100:quality;
    
    const char *filename = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    int q = (int)round(quality * 100.0f); q=(q<=0?10:q>=100?100:q);
    
    
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    
    FILE * outfile;               /* target file */
    JSAMPROW row_pointer[1];      /* pointer to JSAMPLE row[s] */
    int row_stride;               /* physical row width in image buffer */
    
    /* Step 1: allocate and initialize JPEG compression object */
    
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    
    /* Step 2: specify data destination (eg, a file) */
    if ((outfile = fopen(filename, "wb")) == NULL) {
        if (error) {
            *error = [[NSError alloc ] initWithDomain:@"com.improcessing.jpeg.write"
                                                 code: ENOENT
                                             userInfo: @{
                                                         NSLocalizedDescriptionKey:  [NSString stringWithFormat:NSLocalizedString(@"Image file %@ can't be created", nil),filename],
                                                         NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"File can't be created", nil),
                                                         }];
        }
        return NO;
    }
    jpeg_stdio_dest(&cinfo, outfile);
    
    
    /* Step 3: set parameters for compression */
    
    cinfo.image_width  = (int)CVPixelBufferGetWidth(pixelBuffer);      /* image width and height, in pixels */
    cinfo.image_height = (int)CVPixelBufferGetHeight(pixelBuffer);
    cinfo.input_components = 4;           /* # of color components per pixel */
    cinfo.in_color_space = JCS_EXT_RGBA;    /* colorspace of input image */
    
    switch (colorSpace) {
        case JPEG_TURBO_ABGR:
            cinfo.in_color_space = JCS_EXT_ABGR;
            break;
            
        case JPEG_TURBO_ARGB:
            cinfo.in_color_space = JCS_EXT_ARGB;
            break;
            
        case JPEG_TURBO_BGRA:
            cinfo.in_color_space = JCS_EXT_BGRA;
            break;
            
        case JPEG_TURBO_RGBA:
        default:
            break;
    }
    
    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE /* limit to baseline-JPEG values */);
    
    
    /* Step 4: Start compressor */
    
    jpeg_start_compress(&cinfo, TRUE);
    
    
    /* Step 5: while (scan lines remain to be written) */
    /*           jpeg_write_scanlines(...); */
    
    row_stride = (int)cinfo.image_width  * cinfo.input_components; /* JSAMPLEs per row in image_buffer */
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void       *image_buffer  = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    while (cinfo.next_scanline < cinfo.image_height) {
        row_pointer[0] = & image_buffer[cinfo.next_scanline * row_stride];
        (void) jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    /* Step 6: Finish compression */
    
    jpeg_finish_compress(&cinfo);
    /* After finish_compress, we can close the output file. */
    fclose(outfile);
    
    
    /* Step 7: release JPEG compression object */
    jpeg_destroy_compress(&cinfo);
    
    return YES;
}

@end
