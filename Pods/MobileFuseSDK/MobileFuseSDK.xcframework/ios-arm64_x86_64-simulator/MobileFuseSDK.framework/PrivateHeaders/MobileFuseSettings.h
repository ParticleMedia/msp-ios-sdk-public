//
//  MobileFuseSettings.h
//  MFSDKCore
//

#ifndef MobileFuseSettings_h
#define MobileFuseSettings_h

@import Foundation;

typedef NS_ENUM(NSUInteger, MFVideoClickthroughBehavior) {
    VIDEO_CLICKTHROUGH_BEHAVIOR_CTA_AND_VIDEO = 0,
    VIDEO_CLICKTHROUGH_BEHAVIOR_CTA_ONLY = 1
};

typedef enum {
    MOBILEFUSE_SETTING_IFA = 0,
    MOBILEFUSE_SETTING_INIT_ENDPOINT,
    MOBILEFUSE_SETTING_IP_ADDRESS,
    MOBILEFUSE_SETTING_USER_AGENT,
    MOBILEFUSE_SETTING_GEOLOCATION_JSON
} MobileFuseSetting;

/* INTERNAL CLASS - NOT EXPOSED TO PUBLIC FRAMEWORK INTERFACE, ACCESS WITH #import <MFSDKCore/MobileFuseSettings.h> */

@interface MobileFuseSettings : NSObject

@property (class, atomic, strong, readonly) NSNumber *maxInterstitialCloseButtonDelay;

+ (void)setOverride:(MobileFuseSetting)setting withValue:(NSString *)value; /* Assign a value to a specific setting defined in the MobileFuseSetting enum */
+ (NSString *)getOverride:(MobileFuseSetting)setting; /* Get the previously assigned value of a setting, or NULL if not set */

+ (void)setTestMode:(BOOL)test; /* SDK test mode */
+ (BOOL)testMode;
+ (void)setSdkAdapter:(NSString *)adapter;
+ (NSString *)sdkAdapter;
+ (void)setSdkAdapterVersion:(NSString *)version;
+ (NSString *)sdkAdapterVersion;

+ (void)setVideoClickthroughBehavior:(MFVideoClickthroughBehavior)behaviour __deprecated_msg("This method is no longer supported, and the setting should be applied on your dashboard.");
+ (MFVideoClickthroughBehavior)videoClickthroughBehavior __deprecated_msg("This property is no longer used, and its value is meaningless.");

+ (void)setMaxInterstitialCloseButtonDelayInSeconds:(NSNumber *)maximum __deprecated_msg("This method is no longer supported, and the setting should be applied on your dashboard.");

@end

#endif /* MobileFuseSettings_h */
