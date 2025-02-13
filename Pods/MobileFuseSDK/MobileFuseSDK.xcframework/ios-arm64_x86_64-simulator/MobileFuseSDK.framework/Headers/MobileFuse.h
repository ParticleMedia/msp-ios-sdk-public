//
//  MobileFuse.h
//  MobileFuseSDK
//

#ifndef MobileFuse_h
#define MobileFuse_h

@import Foundation;
@import UIKit;

#import <MobileFuseSDK/IMFInitializationCallbackReceiver.h>

// Forward declarations
@class MobileFusePrivacyPreferences;
@class MobileFuseTargetingData;

typedef NS_ENUM(NSUInteger, MFSDKReadyState) {
    MOBILEFUSE_SDK_NOT_READY = 1,
    MOBILEFUSE_SDK_IN_FLIGHT,
    MOBILEFUSE_SDK_READY,
    MOBILEFUSE_SDK_FAILED_TO_INITIALIZE
};

@interface MobileFuse : NSObject

/* Main initialization calls */
+ (void)initWithDelegate:(id<IMFInitializationCallbackReceiver>)delegate;
+ (void)initWithAppId:(NSString*)appId withPublisherId:(NSString *)publisherId;
+ (void)initWithAppId:(NSString*)appId withPublisherId:(NSString *)publisherId withDelegate:(id<IMFInitializationCallbackReceiver>)delegate;
+ (void)reset;

+ (BOOL)isReady; // Has the SDK been initialized successfully?

// Deprecated methods. App and Publisher IDs are no longer needed for initialization.
+ (BOOL)isReadyForAppKey:(NSString *)appKey;
+ (BOOL)isReadyForAppId:(NSString *)appId withPublisherId:(NSString *)publisherId;

+ (void)setPrivacyPreferences:(MobileFusePrivacyPreferences *)preferences; /* Provide a MobileFusePrivacyPreferences instance to set privacy preferences */

+ (MobileFusePrivacyPreferences *)getPrivacyPreferences;
+ (NSString *)version;

+ (void)enableVerboseLogging; /* This enables verbose logging from the point where it is called onward */

+ (void)initializeCoreServices; /* For advanced use only */

@end

#endif /* MobileFuse_h */
