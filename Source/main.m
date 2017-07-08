/*
    Created by Ricci Adams
    Public Domain
*/


#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>

#import "DataUtils.h"
#import "PNGChunk.h"


static void __attribute__((noreturn)) sPrintUsageAndExit() 
{
    fprintf(stderr, "Usage: pngohsh <verb> file\n");

    fprintf(stderr, "Usage: pngohsh <verb> file (hexString), where <verb> is:\n");
    fprintf(stderr, "    read        read the ohSH chunk as a hex string\n");
    fprintf(stderr, "    write       write a hex string to the ohSH chunk\n");
    fprintf(stderr, "    delete      delete the ohSH chunk\n");
    fprintf(stderr, "    compute     compute the ohSH chunk\n");
    fprintf(stderr, "\n");
    
    exit(1);
}


static NSData *sCreateSHA256160Hash(NSData *inData)
{
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];

    CC_SHA256_CTX ctx;

    CC_SHA256_Init(&ctx);
    CC_SHA256_Update(&ctx, [inData bytes], (CC_LONG)[inData length]);
    CC_SHA256_Final(digest, &ctx);
    
    return [[NSData alloc] initWithBytes:digest length:20];
}


static NSData *sGetHexData(NSString *hexString)
{
    NSUInteger inLength = [hexString length];
    
    unichar *inCharacters = alloca(sizeof(unichar) * inLength);
    [hexString getCharacters:inCharacters range:NSMakeRange(0, inLength)];

    UInt8 *outBytes = malloc(sizeof(UInt8) * ((inLength / 2) + 1));

    NSInteger i, o = 0;
    UInt8 outByte = 0;
    for (i = 0; i < inLength; i++) {
        UInt8 c = inCharacters[i];
        SInt8 value = -1;
        
        if      (c >= '0' && c <= '9') value =      (c - '0');
        else if (c >= 'A' && c <= 'F') value = 10 + (c - 'A');
        else if (c >= 'a' && c <= 'f') value = 10 + (c - 'a');            
        
        if (value >= 0) {
            if (i % 2 == 1) {
                outBytes[o++] = (outByte << 4) | value;
                outByte = 0;
            } else {
                outByte = value;
            }

        } else {
            if (o != 0) break;
        }        
    }

    return [NSData dataWithBytesNoCopy:outBytes length:o freeWhenDone:YES];
}


static NSString *sGetHexString(NSData *data)
{
    NSUInteger inLength  = [data length];
    unichar *outCharacters = malloc(sizeof(unichar) * (inLength * 2));

    UInt8 *inBytes = (UInt8 *)[data bytes];
    static const char lookup[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
 
    NSUInteger i, o = 0;
    for (i = 0; i < inLength; i++) {
        UInt8 inByte = inBytes[i];
        outCharacters[o++] = lookup[(inByte & 0xF0) >> 4];
        outCharacters[o++] = lookup[(inByte & 0x0F)];
    }

    return [[NSString alloc] initWithCharactersNoCopy:outCharacters length:o freeWhenDone:YES];
}


static void sReadWriteHeader(DataReader *reader, DataWriter *writer)
{
    NSData *headerData = [reader readDataOfLength:8];
    const UInt8 *bytes = [headerData bytes];

    if (!headerData ||
        bytes[0] != 137 || bytes[1] != 'P' || bytes[2] != 'N' || bytes[3] != 'G' ||
        bytes[4] != 13  || bytes[5] != 10  || bytes[6] != 26  || bytes[7] != 10)
    {
        fprintf(stderr, "Error: Not a PNG file");
        exit(2);
    }

    [writer writeData:headerData];
}


static PNGChunk *sReadChunk(DataReader *reader)
{
    UInt32  length   = [reader readUInt32];
    UInt32  type     = [reader readUInt32];
    NSData *data     = [reader readDataOfLength:length];
    UInt32  checksum = [reader readUInt32];

    PNGChunk *chunk = [[PNGChunk alloc] initWithType:type data:data];
    
    if ([chunk checksum] != checksum) {
        fprintf(stderr, "Error: PNG file is corrupted");
        exit(2);
    }
    
    return chunk;
}


static void sWriteChunk(DataWriter *writer, PNGChunk *chunk)
{
    [writer writeUInt32:[chunk length]];
    [writer writeUInt32:[chunk type]];
    [writer writeData:  [chunk data]];
    [writer writeUInt32:[chunk checksum]];
}


static void sWriteHash(NSString *path, NSData *data)
{
    NSData        *inData  = [NSData dataWithContentsOfFile:path];
    NSMutableData *outData = [NSMutableData data];

    DataReader *reader = [[DataReader alloc] initWithData:inData];
    DataWriter *writer = [[DataWriter alloc] initWithData:outData];

    PNGChunk *ohSHChunk = [[PNGChunk alloc] initWithType:'ohSH' data:data];

    sReadWriteHeader(reader, writer);
    
    while (![reader isAtEnd]) {
        PNGChunk *chunk = sReadChunk(reader);
        
        if ([chunk type] == 'ohSH') {
            // Skip any ohSH chunk already in the file
            continue;

        } else if ([chunk type] == 'IEND') {
            // Write the ohSH chunk right before IEND
            sWriteChunk(writer, ohSHChunk);
        }

        sWriteChunk(writer, chunk);
    }

    [outData writeToFile:path atomically:YES];
}


static void sReadHash(NSString *path)
{
    NSData     *data   = [NSData dataWithContentsOfFile:path];
    DataReader *reader = [[DataReader alloc] initWithData:data];
    
    NSData *ohSHData = nil;

    sReadWriteHeader(reader, nil);
    
    while (![reader isAtEnd]) {
        PNGChunk *chunk = sReadChunk(reader);

        if ([chunk type] == 'ohSH') {
            ohSHData = [chunk data];
            break;
        }
    }

    if (ohSHData) {
        fprintf(stdout, "%s\n", [sGetHexString(ohSHData) UTF8String]);
    }
}


static void sComputeHash(NSString *path)
{
    NSData *fileData = [NSData dataWithContentsOfFile:path];
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)fileData);
    CGImageRef image = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);

    if (!image) {
        fprintf(stderr, "Error: Could not read PNG file");
        exit(2);
    }

    NSMutableData *dataToHash = [NSMutableData data];
    DataWriter *dataWriter = [[DataWriter alloc] initWithData:dataToHash];

    size_t   width       = CGImageGetWidth(image);
    size_t   height      = CGImageGetHeight(image);
    size_t   bpc         = CGImageGetBitsPerComponent(image);
    size_t   bytesPerRow = CGImageGetBytesPerRow(image);
    uint32_t bitmapInfo  = CGImageGetBitmapInfo(image);
    
    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    bitmapInfo = bitmapInfo & ~kCGBitmapAlphaInfoMask;
    
    if (alphaInfo == kCGImageAlphaLast) {
        alphaInfo = kCGImageAlphaPremultipliedLast;
    } else if (alphaInfo == kCGImageAlphaFirst) {
        alphaInfo = kCGImageAlphaPremultipliedFirst;
    } else if (alphaInfo == kCGImageAlphaNone) {
        alphaInfo = kCGImageAlphaNoneSkipLast;
    }
    
    bitmapInfo |= alphaInfo;
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    
    NSString *name = CFBridgingRelease(CGColorSpaceCopyName(colorSpace));
    if (!colorSpace) {
        [dataWriter writeUInt8:0];

    } else if ([name isEqualToString:(__bridge id)kCGColorSpaceSRGB]) {
        [dataWriter writeUInt8:1];

    } else if ([name isEqualToString:(__bridge id)kCGColorSpaceDisplayP3]) {
        [dataWriter writeUInt8:2];

    } else {
        NSData *data = CFBridgingRelease(CGColorSpaceCopyICCData(colorSpace));
        [dataWriter writeUInt8:3];
        [dataWriter writeData:data];
    }

    CGContextRef context = CGBitmapContextCreate(NULL, width, height, bpc, bytesPerRow, colorSpace, bitmapInfo);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    NSData *bitmapData = nil;
    if (context) {
        bitmapData = [NSData dataWithBytes:CGBitmapContextGetData(context) length:height * bytesPerRow];
    }
    
    CGContextRelease(context);
    
    [dataWriter writeUInt32:1];
    [dataWriter writeUInt32:(UInt32)width];
    [dataWriter writeUInt32:(UInt32)height];
    [dataWriter writeUInt32:(UInt32)bpc];
    [dataWriter writeUInt32:(UInt32)bytesPerRow];
    [dataWriter writeUInt32:(UInt32)bitmapInfo];
    [dataWriter writeData:bitmapData];
    
    NSData *ohSHData = sCreateSHA256160Hash(dataToHash);
    fprintf(stdout, "%s\n", [sGetHexString(ohSHData) UTF8String]);

    CGDataProviderRelease(provider);
    CGImageRelease(image);
    
}


int main(int argc, char *argv[])
{
@autoreleasepool {
    if (argc < 3) sPrintUsageAndExit();

    NSString *verb   = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    NSString *path   = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];

    if ([verb isEqualToString:@"write"]) {
        NSString *hashString = argc > 3 ? [NSString stringWithCString:argv[3] encoding:NSUTF8StringEncoding] : nil;
        NSData   *hash       = sGetHexData(hashString);
        
        if (!hash) sPrintUsageAndExit();

        sWriteHash(path, hash);

    } else if ([verb isEqualToString:@"read"]) {
        sReadHash(path);

    } else if ([verb isEqualToString:@"delete"]) {
        sWriteHash(path, nil);

    } else if ([verb isEqualToString:@"compute"]) {
        sComputeHash(path);

    } else {
        sPrintUsageAndExit();
    }
}
    return 0;
}

