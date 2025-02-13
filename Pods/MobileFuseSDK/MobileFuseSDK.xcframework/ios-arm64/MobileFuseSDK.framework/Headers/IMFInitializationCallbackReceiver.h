//
//  IMFInitializationCallbackReceiver.h
//  MobileFuseSDK
//

#ifndef IMFInitializationCallbackReceiver_h
#define IMFInitializationCallbackReceiver_h

#import <MobileFuseSDK/MFAdError.h>

/* Callback receiver delegate */
@protocol IMFInitializationCallbackReceiver <NSObject>

@required

@optional

- (void)onInitSuccess:(NSString *)appId withPublisherId:(NSString *)publisherId; // Callback responder for init; called on success
- (void)onInitError:(NSString *)appId withPublisherId:(NSString *)publisherId withError:(MFAdError *)error; // Called if there is an error initializing the SDK

// Deprecated
- (void) __attribute__((deprecated)) onInitError:(NSString *)message forAppId:(NSString *)appId withPublisherId:(NSString *)publisherId; // Called if there is an error initializing the SDK

@end

#endif /* IMFInitializationCallbackReceiver_h */
