/*
    Created by Ricci Adams
    Public Domain
*/


#import <Foundation/Foundation.h>

@interface PNGChunk : NSObject

- (instancetype) initWithType:(UInt32)type data:(NSData *)data;

@property (nonatomic, readonly) UInt32 length; 
@property (nonatomic, readonly) UInt32 type; 
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) UInt32 checksum; 

@end
