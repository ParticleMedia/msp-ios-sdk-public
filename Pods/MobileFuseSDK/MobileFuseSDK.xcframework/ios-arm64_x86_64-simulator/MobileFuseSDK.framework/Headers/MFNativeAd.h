//
//  MFNativeAd.h
//  MobileFuseSDK
//

#ifndef MFNativeAd_h
#define MFNativeAd_h

@import Foundation;

#import <MobileFuseSDK/MFAd.h>

#ifndef MFUSE_AD_TYPE_NATIVE
#define MFUSE_AD_TYPE_NATIVE (@"native")
#endif

typedef NS_ENUM(NSInteger, MobileFuseNativePlacementAssetId) {
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_AD_TITLE = 100,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_ICON_IMAGE = 200,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_MAIN_IMAGE = 201,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_VIDEO = 300,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_SPONSORED_TEXT = 400,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_DESCRIPTION_TEXT = 401,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_DISPLAY_URL = 402,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_ID_CTA_BUTTON_TEXT = 403,
};

typedef NS_ENUM(NSInteger, MobileFuseNativePlacementAssetImageType) {
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_IMAGE_TYPE_INVALID = 0,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_IMAGE_TYPE_ICON = 1,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_IMAGE_TYPE_MAIN = 3
};

typedef NS_ENUM(NSInteger, MobileFuseNativePlacementAssetDataType) {
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_DATA_TYPE_INVALID = 0,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_DATA_TYPE_SPONSORED = 1,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_DATA_TYPE_DESC = 2,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_DATA_TYPE_DISPLAYURL = 11,
    MOBILEFUSE_NATIVE_PLACEMENT_ASSET_DATA_TYPE_CTATEXT = 12
};

@interface MFNativeAd : MFAd

- (MFNativeAd *)init;
- (MFNativeAd *)initWithPlacementId:(NSString *)placementId;

- (void)destroy;

- (void)registerViewForInteraction:(UIView *)container withClickableViews:(NSArray<UIView *> *)clickableViews; /* Register the view containing the native ad, and any views that should be clickable */
- (void)unregisterViews; /* Unregister all registered views */

- (BOOL)hasTitle; /* True if the native ad has associated title text */
- (NSString *)getTitle; /* Get the title text for the native ad */
- (NSString *)getTitleWithDefaultValue:(NSString *)defaultValue; /* Get the title text for the native ad, falling back to the provided default value if it is not set by the ad itself */

- (BOOL)hasSponsoredText; /* True if the native ad has associated sponsored text */
- (NSString *)getSponsoredText; /* Get the sponsored text for the native ad */
- (NSString *)getSponsoredTextWithDefaultValue:(NSString *)defaultValue; /* Get the sponsored text for the native ad, falling back to the provided default value if it is not set by the ad itself */

- (BOOL)hasDescriptionText; /* True if the native ad has associated descrption text */
- (NSString *)getDescriptionText; /* Get the description text for the native ad */
- (NSString *)getDescriptionTextWithDefaultValue:(NSString *)defaultValue; /* Get the descrption text for the native ad, falling back to the provided default value if it is not set by the ad itself */

- (BOOL)hasDisplayUrl; /* True if the native ad has an associated display url */
- (NSString *)getDisplayUrl; /* Get the display url for the native ad */
- (NSString *)getDisplayUrlWithDefaultValue:(NSString *)defaultValue; /* Get the display url for the native ad, falling back to the provided default value if it is not set by the ad itself */

- (BOOL)hasCtaButtonText; /* True if the native ad has associated CTA button text */
- (NSString *)getCtaButtonText; /* Get the CTA button text for the native ad */
- (NSString *)getCtaButtonTextWithDefaultValue:(NSString *)defaultValue; /* Get the CTA button text for the native ad, falling back to the provided default value if it is not set by the ad itself */

- (BOOL)hasIcon; /* True if the native ad has an icon image */
- (UIImage *)getIconImage; /* Get the icon image for the native ad */

- (BOOL)hasMainImage; /* True if the native ad has a main image */
- (UIImage *)getMainImage; /* Get the main image for the native ad */

- (BOOL)hasMainVideo; /* True if the native ad has a main video view */
- (UIView *)getMainVideoView; /* Get the main video view for the native ad */

- (UIView *)getMainContentView; /* Get the main content view for the ad - this is either the video view, or a view containing the main image */

@end

#endif /* MFNativeAd.h */
