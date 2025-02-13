//
//  MFAdError.h
//  MobileFuseSDK
//
//

#import <Foundation/Foundation.h>
#import <MobileFuseSDK/MFAd.h>

@class MobileFuseError;

@interface MFAdError : NSError

- (NSString *)message;

@end

