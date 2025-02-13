//
//  MobileFusePrivate.h
//  MobileFuseSDK
//

#ifndef MobileFusePrivate_h
#define MobileFusePrivate_h

@import Foundation;

/* INTERNAL CLASS - NOT EXPOSED TO PUBLIC FRAMEWORK INTERFACE, ACCESS WITH #import <MFSDKCore/MobileFusePrivate.h> */

// Forward declerations
@class AdExchangeNetworkingService;
@class MFRenderingLog;

@interface MobileFusePrivate : NSObject

@property (class, atomic, readonly) BOOL debugMraidPureMarkup;
@property (class, atomic, readonly) BOOL debugRenderCloseZones;
@property (class, atomic, readonly) BOOL internalMetricsCollection;
@property (class, atomic, readonly) BOOL debugMraidTrackUrlRequests;
@property (class, atomic, readonly) NSString *markupOverride;
@property (class, atomic, readonly) NSString *adResponseOverride;
@property (class, atomic, strong, readonly) AdExchangeNetworkingService *networkingService;
@property (class, atomic, strong, readonly) NSMutableArray<MFRenderingLog *> *renderingLogs;

+ (NSArray<NSDictionary *> *)getUrlRequestLogs;
+ (NSArray<NSDictionary *> *)getConsoleLogs;
+ (void)loadLocalAdNetworkResponseForPlacementId:(NSString *)placementId withStatusCode:(uint)statusCode mediaType:(NSString *)mediaType creativeFormat:(NSString *)creativeFormat andMarkup:(NSString *)markup;
+ (void)useLocalAdNetwork;
+ (void)useMFXAdNetwork;
+ (void)setDebugLimitTrackingOverride:(BOOL)limitTrackingOverride;

+ (void)setInternalMetricsCollection:(BOOL)enabled; /* If this is true, collect internal metrics and expose them via MobileFuseMetrics */
+ (void)configureTestCeltraIds:(NSDictionary *)mappings; /* Mappings format is NSString key (tag ID) -> NSString value (celtra ID) */
+ (NSString *)getTestCeltraId:(NSString *)tagId; /* Get a test Celtra ID given a tag Id, or NULL if it hasn't been configured with configureTestCeltraIds */

+ (void)setDebugMraidPureMarkup:(BOOL)enabled; /* If this is true, render MRAID ads as pure markup only */
+ (void)setDebugMraidTrackUrlRequests:(BOOL)enabled; /* If this is true, track URL requests originating from MRAID ads */

+ (void)setDebugRenderCloseZones:(BOOL)enabled; /* If this is true, ads shown after setting it will render their close zone as a red box */

+ (void)setDebugStoreConsoleLogs:(BOOL)enabled; // If this is true, all MFLog messages are stored.

+ (void)setMarkupOverride:(NSString *)markupOverride;
+ (void)setAdResponseOverride:(NSString *)adResponse;

+ (void)setNetworkingService:(AdExchangeNetworkingService *)service; /* Set the networking service to use. A strong reference is held */

+ (void)logAdRenderingWithPlacementId:(NSString *)placementId rendererType:(NSString *)rendererType creativeId:(NSString *)creativeId;

+ (void)logParentAppPrivacyManifest;

+ (void)clearExtendedIdData;

@end

#endif /* MobileFusePrivate_h */
