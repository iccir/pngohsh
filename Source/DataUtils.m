/*
    Created by Ricci Adams
    Public Domain
*/


#import "DataUtils.h"


@implementation DataReader {
    NSData      *_data;
    const void  *_bytes;
    NSUInteger   _length;
    NSUInteger   _i;
}

- (instancetype) initWithData:(NSData *)data
{
    if ((self = [super init])) {
        _data = data;
        _bytes = [data bytes];
        _length = [data length];
    }
    
    return self;
}


- (BOOL) ensure:(NSUInteger)length
{
    if (length > _length) return NO;
    return _i <= (_length - length);
}


- (UInt8) readUInt8
{
    UInt8 result = 0;

    if ([self ensure:1]) {
        result = *((UInt8 *)&_bytes[_i]);
    }

    _i += 1;

    return result;
}


- (UInt32) readUInt32
{
    UInt32 result = 0;

    if ([self ensure:4]) {
        result = OSReadBigInt32(_bytes, _i);
    }

    _i += 4;

    return result;
}


- (NSData *) readDataOfLength:(NSUInteger)length
{
    NSData *result = nil;

    if ([self ensure:length]) {
        result = [NSData dataWithBytes:&_bytes[_i] length:length];
    }

    _i += length;

    return result;
}


- (BOOL) isAtEnd
{
    return _i >= _length;
}

@end




@implementation DataWriter {
    NSMutableData *_data;
}



- (instancetype) initWithData:(NSMutableData *)data
{
    if ((self = [super init])) {
        _data = data;
    }
    
    return self;
}


- (void) writeUInt8:(UInt8)i
{
    [_data appendBytes:&i length:1];
}


- (void) writeUInt32:(UInt32)i
{
    i = OSSwapHostToBigInt(i);
    [_data appendBytes:&i length:4];
}


- (void) writeData:(NSData *)data
{
    [_data appendData:data];
}


@end


