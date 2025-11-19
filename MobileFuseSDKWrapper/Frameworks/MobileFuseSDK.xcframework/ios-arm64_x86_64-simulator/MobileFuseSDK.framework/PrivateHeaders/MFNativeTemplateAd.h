//
//  MFNativeTemplateAd.h
//  MobileFuseSDK
//

#ifndef MFNativeTemplateAd_h
#define MFNativeTemplateAd_h

@import Foundation;
#import <MobileFuseSDK/MFNativeAd.h>

@interface MFNativeTemplateAd : MFNativeAd

- (void)showAd; /* Show the ad (only works if it has been added to the view hierarchy */
- (void)showAdInDefaultWindow; /* Show the ad using the default window - note this may not work in all apps! Test thoroughly! */
- (void)showAdWithViewController:(UIViewController *)controller; /* Show the ad using a specific view controller */

@end

#endif /* MFNativeTemplateAd_h */
