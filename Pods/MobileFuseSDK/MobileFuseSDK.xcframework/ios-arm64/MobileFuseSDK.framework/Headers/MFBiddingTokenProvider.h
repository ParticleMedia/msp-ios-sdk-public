//
//  MFBiddingTokenProvider.h
//  MobileFuseSDK
//

#ifndef MFBiddingTokenProvider_h
#define MFBiddingTokenProvider_h

@import Foundation;

// Forward declarations
typedef NS_ENUM(NSUInteger, MFSDKPartner);
@class MobileFusePrivacyPreferences;

@interface MFBiddingTokenRequest : NSObject

@property (readwrite) MobileFusePrivacyPreferences * _Nullable privacyPreferences;
@property (readwrite) BOOL isTestMode;
@property (readwrite) MFSDKPartner partner; /* Partner enum value - MOBILEFUSE_PARTNER_NIMBUS, etc */

@end

@interface MFBiddingTokenProvider : NSObject

// Create tokens with these methods
+ (void)getTokenWithRequest:(MFBiddingTokenRequest * _Nullable)request withCallback:(void (^_Nonnull)(NSString * _Nonnull token))callback; /* Use this to build a token from an MFBiddingTokenRequest object - the callback provides an NSString token */
+ (void)getTokenDataWithRequest:(MFBiddingTokenRequest * _Nullable)request withCallback:(void (^_Nonnull)(NSDictionary<NSString *, NSString *> * _Nonnull token))callback; /* Use this to build a token from an MFBiddingTokenRequest object - the callback provides an NSString token */

+ (NSString * _Nonnull)getTokenWithRequest:(MFBiddingTokenRequest * _Nullable)request __deprecated_msg("Use getTokenWithRequest:withCallback: instead");

// Read tokens with these methods
+ (NSDictionary * _Nonnull)getDictionaryFromToken:(NSString * _Nonnull)token; /* Get a dictionary from a token */
+ (NSString * _Nonnull)getJsonFromToken:(NSString * _Nonnull)token; /* Get a JSON string from a token */

@end

#endif /* MFBiddingTokenProvider_h */
