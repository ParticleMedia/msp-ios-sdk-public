//
//  MFWinningBidInfo.h
//  MobileFuseSDK
//

@import Foundation;

@interface MFWinningBidInfo : NSObject

@property (readonly) float cpmPrice;
@property (readonly) NSString *creativeId;
@property (readonly) NSString *currency;

- (instancetype)initWithCpmPrice:(float)cpmPrice andCreativeId:(NSString *)creativeId;

@end
