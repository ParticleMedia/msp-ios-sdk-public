//
//  Ad.h
//  MobileFuseSDK
//

#ifndef Ad_h
#define Ad_h

@import Foundation;
@import UIKit;
#import <MobileFuseSDK/MFWinningBidInfo.h>

typedef NS_ENUM(NSUInteger, MFSDKAdPositioningType) {
    MOBILEFUSE_AD_POSITIONING_CENTER = 1, /* Center the ad content within the container */
    MOBILEFUSE_AD_POSITIONING_STRETCH, /* Stretch the ad content to try to fill the container */
    MOBILEFUSE_AD_POSITIONING_ZERO /* Position the ad content at x: 0, y: 0 within the container */
};

@class MFAdViewController;
@class BaseAdRenderer;
@protocol IMFAdCallbackReceiver;

@interface MFAd : UIView

@property (nonatomic, strong, readonly) NSString *placementId;
@property (atomic, readwrite) BOOL testMode;
@property NSString *instanceId;

- (MFAd *)init;
- (MFAd *)initWithPlacementId:(NSString *)placementId;
- (void)loadAd; /* Load the ad so it is ready to show */
- (void)loadAdWithBiddingResponseToken:(NSString *)responseToken; /* Load an ad using a special bidding response token */
- (void)showAd; /* Show the ad! */
- (BOOL)isLoading; /* Is the ad currently loading? */
- (BOOL)isLoaded; /* Is the ad ready to be displayed? */
- (BOOL)isVisible; /* Is the ad visible to the user? */
- (BOOL)isExpired; /* Has the ad expired? */
- (void)destroy; /* Destroy this ad instance, removing any displayed ads from the screen */
- (void)registerAdCallbackReceiver:(id<IMFAdCallbackReceiver>)delegate; /* Set callback receiver for this ad */
- (void)setMuted:(BOOL)mute; /* Set the muted status of video ads */

@end

#endif /* Ad_h */
