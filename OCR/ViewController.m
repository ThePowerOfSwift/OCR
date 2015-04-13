//
//  ViewController.m
//  OCR
//
//  Created by huijinghuang on 4/11/15.
//  Copyright (c) 2015 huijinghuang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // change the image name to your image
    //UIImage* img = [UIImage imageNamed:@"1_sample_complete.png"];
    //UIImage* img = [UIImage imageNamed:@"2_sample_part.png"];
    UIImage* img = [UIImage imageNamed:@"3_sample_color.png"];
    //UIImage* img = [UIImage imageNamed:@"4_sample_jack-ma.png"];
    //UIImageView* initImgView = [[UIImageView alloc] initWithImage:img];
    //[self.view addSubview:initImgView];

    UIImage* BWImg = [self convertImageTOBlackNWhite:img];
    UIImageView* BWImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 45, BWImg.size.width, BWImg.size.height)];
    [BWImgView setImage:BWImg];
    [self.view addSubview:BWImgView];
    //[self lineDetection:img];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(unsigned char *)UIImageToRGBA8:(UIImage*) image {
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char* rawData = (unsigned char*) calloc(width * height * 4, sizeof(unsigned char));
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    return rawData;
}

// line detection core algorithm
-(UIImage *)convertImageTOBlackNWhite:(UIImage *) image{
    // step 2 threshold the image
    unsigned char* rawData = [self UIImageToRGBA8:image];
    CGFloat threshold = 0.5;
    for (int i = 0; i < image.size.width * image.size.height * 4; i += 4) {
        if (rawData[i] + rawData[i+1] + rawData[i+2] < 255 * 3 * threshold) {
            rawData[i] = 0;
            rawData[i+1] = 0;
            rawData[i+2] = 0;
        } else {
            rawData[i] = 255;
            rawData[i+1] = 255;
            rawData[i+2] = 255;
        }
    }
    
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    
    // step 3 horizontal projection
    NSMutableArray* lines = [NSMutableArray arrayWithCapacity:height];
    bool top = false;
    int* horiArr = (int*) calloc(height, sizeof(int));
    for (int i = 0; i < height; i++) {
        int blackPixel = 0;
        for (int j = 0; j < width; j++) {
            NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
            if (rawData[index] == 0) {
                blackPixel++;
                //NSLog(@"black");
            }
        }
        horiArr[i] = blackPixel;
        UIView* lineView = [[UIView alloc] initWithFrame:CGRectMake(200, i, horiArr[i], 1)];
        lineView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:lineView];
        
        if (blackPixel > 0) {
            if (!top || i == height-1) {
                // last black pixel should also be in
                [lines addObject:[NSNumber numberWithInt:i]];
                // draw line to test
                for (int j = 0; j < width; j++) {
                    NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
                    rawData[index] = 255;
                    rawData[index+1] = 102;
                    rawData[index+2] = 102;
                }
                //NSLog(@"top: %d", i);
                top = true;
            }
        } else {
            if (top) {
                //NSLog(@"bottom: %d", i);
                [lines addObject:[NSNumber numberWithInt:i]];
                for (int j = 0; j < width; j++) {
                    NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
                    rawData[index] = 255;
                    rawData[index+1] = 102;
                    rawData[index+2] = 102;
                }
                top = false;
            }
        }
    }
    
    image = [self convertBitmapRGBA8ToUIImage:rawData withWidth:image.size.width withHeight:image.size.height];
    
    return image;
}

//PLEASE FIND THE BELOW CONVERSION METHODS FROM HERE
//https://gist.github.com/PaulSolt/739132

-(UIImage *) convertBitmapRGBA8ToUIImage:(unsigned char *) buffer withWidth:(int) width withHeight:(int) height
{
    size_t bufferLength = width * height * 4;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, bufferLength, NULL);
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * width;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    
    if(colorSpaceRef == NULL)
    {
        NSLog(@"Error allocating color space");
        CGDataProviderRelease(provider);
        return nil;
    }
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef iref = CGImageCreate(width,
                                    height,
                                    bitsPerComponent,
                                    bitsPerPixel,
                                    bytesPerRow,
                                    colorSpaceRef,
                                    bitmapInfo,
                                    provider, // data provider
                                    NULL,  // decode
                                    YES,   // should interpolate
                                    renderingIntent);
    
    uint32_t* pixels = (uint32_t*)malloc(bufferLength);
    
    if(pixels == NULL)
    {
        NSLog(@"Error: Memory not allocated for bitmap");
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpaceRef);
        CGImageRelease(iref);
        return nil;
    }
    
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, bitsPerComponent, bytesPerRow, colorSpaceRef, bitmapInfo);
    if(context == NULL)
    {
        NSLog(@"Error context not created");
        free(pixels);
    }
    
    UIImage *image = nil;
    
    if(context)
    {
        CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), iref);
        CGImageRef imageRef = CGBitmapContextCreateImage(context);
        
        // Support both iPad 3.2 and iPhone 4 Retina displays with the correct scale
        if([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
            float scale = [[UIScreen mainScreen] scale];
            image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
        } 
        else 
        {
            image = [UIImage imageWithCGImage:imageRef];
        }
        
        CGImageRelease(imageRef);
        CGContextRelease(context);
    }
    
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(iref);
    CGDataProviderRelease(provider);
    
    if(pixels) {
        free(pixels);
    }
    
    return image;
}

@end
