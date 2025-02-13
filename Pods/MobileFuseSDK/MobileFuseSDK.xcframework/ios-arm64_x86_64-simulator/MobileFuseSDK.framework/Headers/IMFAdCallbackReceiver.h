//
//  IMFAdCallbackReceiver.h
//  MFSDKCommon
//

#ifndef IMFAdCallbackReceiver_h
#define IMFAdCallbackReceiver_h

@class MFAd;
@class MFAdError;

/* Callback receiver delegate protocol for ad events */
@protocol IMFAdCallbackReceiver <NSObject>

@required

typedef NS_ENUM(NSUInteger, MobileFuseOmniAdRenderState);

@optional

/* Callback methods that reference the ad instance that called them */
- (void)onAdLoaded:(MFAd *)ad; /* Ad has loaded - you are able to show the ad after this callback is triggered */
- (void)onAdNotFilled:(MFAd *)ad; /* No ad is currently available to display to this user */
- (void)onAdClosed:(MFAd *)ad; /* The ad has been displayed and closed */
- (void)onAdRendered:(MFAd *)ad; /* Triggered when the ad begins to show to the user */
- (void)onAdExpanded:(MFAd *)ad; /* Called when an 'expandable banner' ad is expanded to full-screen */
- (void)onAdCollapsed:(MFAd *)ad; /* Called when an 'expandable banner' ad is collapsed back from full-screen */
- (void)onAdClicked:(MFAd *)ad; /* Triggered when the ad is clicked by the user */
- (void)onAdExpired:(MFAd *)ad; /* Triggered when a loaded ad has expired - you should manually try to load a new ad here */
- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error; // Examine the 'message' property of the error to determine what went wrong.
- (void)onAdPulled:(MFAd *)ad; /* A pull tab ad has been pulled across the screen and revealed by the user */
- (void)onAdMutedChanged:(MFAd *)ad withMuteState:(BOOL)muted; /* Called when the mute state of an ad is changed by a user-facing control */
- (void)onAdStateChanged:(MFAd *)ad withState:(MobileFuseOmniAdRenderState)state; /* Called when the render state of an omni ad changes */
- (void)onUserEarnedReward:(MFAd *)ad; /* a user has viewed a rewarded ad long enough to earn a reward */
- (void)onAdRemovedFromWindow:(MFAd *)ad; /* Called when an ad is removed from the window view hierarchy */

/* Generic callback methods - in most cases the above versions are preferred */
- (void)onAdLoaded; /* Ad has loaded - you are able to show the ad after this callback is triggered */
- (void)onAdNotFilled; /* No ad is currently available to display to this user */
- (void)onAdClosed; /* The ad has been displayed and closed */
- (void)onAdRendered; /* Triggered when the ad begins to show to the user */
- (void)onAdExpanded; /* Called when an 'expandable banner' ad is expanded to full-screen */
- (void)onAdCollapsed; /* Called when an 'expandable banner' ad is collapsed back from full-screen */
- (void)onAdClicked; /* Triggered when the ad is clicked by the user */
- (void)onAdExpired; /* Triggered when a loaded ad has expired - you should manually try to load a new ad here */
- (void)onAdError:(NSString *)message; /* An error occurred with the ad, examine the `message` argument to determine what went wrong */
- (void)onAdPulled; /* A pull tab ad has been pulled across the screen and revealed by the user */
- (void)onAdMutedChanged:(BOOL)muted; /* Called when the mute state of an ad is changed by a user-facing control */
- (void)onAdStateChanged:(MobileFuseOmniAdRenderState)state; /* Called when the render state of an omni ad changes */
- (void)onUserEarnedReward; /* a user has viewed a rewarded ad long enough to earn a reward */
- (void)onAdRemovedFromWindow; /* Called when an ad is removed from the window view hierarchy */

// Deprecated
- (void) __attribute__((deprecated)) onAdError:(MFAd *)ad withMessage:(NSString *)message; /* An error occurred with the ad, examine the `message` argument to determine what went wrong*/

@end

#endif /* IMFAdCallbackReceiver_h */
