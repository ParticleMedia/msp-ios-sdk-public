//
//  InterstitialAd.h
//  MobileFuseSDK
//

#ifndef InterstitialAd_h
#define InterstitialAd_h

@import Foundation;

#import <MobileFuseSDK/MFAd.h>

#ifndef MFUSE_AD_TYPE_INTERSTITIAL
#define MFUSE_AD_TYPE_INTERSTITIAL (@"interstitial")
#endif

#ifndef MFUSE_AD_TYPE_VIDEO
#define MFUSE_AD_TYPE_VIDEO (@"video")
#endif

@interface MFInterstitialAd : MFAd

- (MFInterstitialAd *)init;
- (MFInterstitialAd *)initWithPlacementId:(NSString *)placementId;

- (void)showAd;
- (void)destroy;

@end

#endif /* InterstitialAd_h */
