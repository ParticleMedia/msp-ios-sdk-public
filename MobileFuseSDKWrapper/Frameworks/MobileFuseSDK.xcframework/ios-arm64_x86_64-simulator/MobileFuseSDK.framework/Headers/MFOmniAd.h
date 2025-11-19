//
//  MFOmniAd.h
//  MobileFuseSDK
//

#ifndef MFOmniAd_h
#define MFOmniAd_h

@import Foundation;

#import <MobileFuseSDK/MFInterstitialAd.h>

#ifndef MFUSE_AD_TYPE_OMNI
#define MFUSE_AD_TYPE_OMNI (@"omni")
#endif

typedef NS_ENUM(NSUInteger, MobileFuseOmniAdStartingPosition) {
    MOBILEFUSE_OMNI_AD_POSITION_BOTTOM_RIGHT = 0,
    MOBILEFUSE_OMNI_AD_POSITION_BOTTOM_LEFT,
    MOBILEFUSE_OMNI_AD_POSITION_TOP_LEFT,
    MOBILEFUSE_OMNI_AD_POSITION_TOP_RIGHT
};

typedef NS_ENUM(NSUInteger, MobileFuseOmniAdRenderState) {
    MOBILEFUSE_OMNI_AD_STATE_THUMBNAIL = 0,
    MOBILEFUSE_OMNI_AD_STATE_FULL_SCREEN
};

@interface MFOmniAd : MFInterstitialAd

- (MFOmniAd *)init;
- (void)setStartingPosition:(MobileFuseOmniAdStartingPosition)position; /* Call this before showing the ad to set the starting position */
- (void)setRenderState:(MobileFuseOmniAdRenderState)state; /* Call this to set the ad to full screen or thumbnail mode */

@end

#endif /* MFOmniAd_h */
