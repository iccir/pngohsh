/*
    Created by Ricci Adams
    Public Domain
*/


#import <Foundation/Foundation.h>


@interface DataReader : NSObject

- (instancetype) initWithData:(NSData *)data;

- (UInt8) readUInt8;
- (UInt32) readUInt32;
- (NSData *) readDataOfLength:(NSUInteger)length;

- (BOOL) isAtEnd;

@end


@interface DataWriter : NSObject

- (instancetype) initWithData:(NSMutableData *)data;

- (void) writeUInt8:(UInt8)i;
- (void) writeUInt32:(UInt32)i;
- (void) writeData:(NSData *)data;

@end
