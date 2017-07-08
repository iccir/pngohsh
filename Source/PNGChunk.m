/*
    Created by Ricci Adams
    Public Domain
*/


#import "PNGChunk.h"
#import <zlib.h>


@implementation PNGChunk

- (instancetype) initWithType:(UInt32)type data:(NSData *)data
{
    if ((self = [super init])) {
        _type = type;
        _data = data;
        _length = (UInt32)[data length];
        
        UInt32 swappedType = OSSwapHostToBigInt(type);
        uLong checksum = crc32(0, (void *)&swappedType, sizeof(type));
        if (_length) checksum = crc32(checksum, [data bytes], _length);
        
        _checksum = (UInt32)checksum;
    }

    return self;
}


@end
