//
//  MFRenderingLog.h
//  MobileFuseSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MFRenderingLog : NSObject

@property (nonatomic, strong, readonly) NSString *placementId;
@property (nonatomic, strong, readonly) NSString *rendererType;
@property (nonatomic, strong, readonly) NSString *creativeId;
@property (nonatomic, strong, readonly) NSDate *timestamp;

- (instancetype)initWithPlacementId:(NSString *)placementId rendererType:(NSString *)rendererType creativeId:(NSString *)creativeId;

@end

NS_ASSUME_NONNULL_END
