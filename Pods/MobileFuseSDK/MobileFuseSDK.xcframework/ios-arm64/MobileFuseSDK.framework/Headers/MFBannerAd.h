//
//  BannerAd.h
//  MobileFuseSDK
//

#ifndef BannerAd_h
#define BannerAd_h

@import Foundation;

#import <MobileFuseSDK/MFAd.h>

#ifndef MFUSE_AD_TYPE_VIDEO
#define MFUSE_AD_TYPE_VIDEO (@"video")
#endif

#ifndef MFUSE_AD_TYPE_BANNER
#define MFUSE_AD_TYPE_BANNER (@"banner")
#endif

typedef NS_ENUM(NSUInteger, MFBannerAdSize) {
    MOBILEFUSE_BANNER_SIZE_DEFAULT = 1,
    MOBILEFUSE_BANNER_SIZE_320x50,
    MOBILEFUSE_BANNER_SIZE_300x50,
    MOBILEFUSE_BANNER_SIZE_300x250,
    MOBILEFUSE_BANNER_SIZE_728x90
};

@interface MFBannerAd : MFAd

- (MFBannerAd *)initWithSize:(MFBannerAdSize)size;
- (MFBannerAd *)initWithPlacementId:(NSString *)placementId withSize:(MFBannerAdSize)size;

/* Initializers kept for compatibility - note these will assign MOBILEFUSE_BANNER_SIZE_DEFAULT */
- (MFBannerAd *)init;
- (MFBannerAd *)initWithPlacementId:(NSString *)placementId;

- (void)loadAd;
- (void)showAd; /* Preferred - call this after adding the MFBannerAd to your view hierarchy */
- (void)showAdWithViewController:(UIViewController *)controller; /* Use this if you cannot use showAd */
- (void)destroy;

- (void)setAutorefreshEnabled:(BOOL)enabled;
- (BOOL)getAutorefreshEnabled;
- (void)setAutorefreshInterval:(int)seconds;
- (void)forceRefresh;

@end

#endif /* BannerAd_h */
