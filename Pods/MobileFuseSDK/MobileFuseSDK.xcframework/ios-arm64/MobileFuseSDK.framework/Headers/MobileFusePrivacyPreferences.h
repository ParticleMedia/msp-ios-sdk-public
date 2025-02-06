//
//  MobileFusePrivacyPreferences.h
//  MobileFuseSDK
//

@import Foundation;
@class MFInternalPrivacyPreferences;

@interface MobileFusePrivacyPreferences : NSObject

@property MFInternalPrivacyPreferences *internalPreferences;

- (MobileFusePrivacyPreferences *)init;
- (MobileFusePrivacyPreferences *)initWithPrivacyPreferences:(MobileFusePrivacyPreferences *)preferences;

- (void)setSubjectToCoppa:(BOOL)coppa; /* Set to true if the app is subject to COPPA-compliance and should only allow COPPA-compliant ads */
- (void)setSubjectToGdpr:(BOOL)gdpr __deprecated_msg("GDPR Flag is no longer supported.");
- (void)setUsPrivacyConsentString:(NSString *)string; /* Set the US-privacy consent string to be used to request ads */
- (void)setIabConsentString:(NSString *)string __deprecated_msg("IAB consent string is no longer supported."); /* Set the IAB privacy consent string (used for GDPR) */
- (void)setGppConsentString:(NSString *)string; /* Set the GPP privacy consent string */
- (void)setDoNotTrack:(BOOL)doNotTrack; /* Set "do not track" opt-out. Optionally used instead of providing a GPP string */

- (BOOL)isSubjectToCoppa; /* Get COPPA setting - if true, the SDK will be configured to only allow COPPA-compliant ads */
- (BOOL)isSubjectToGdpr __deprecated_msg("GDPR Flag is no longer supported.");
- (NSString *)getUsPrivacyConsentString;
- (NSString *)getIabConsentString __deprecated_msg("IAB consent string is no longer supported.");
- (NSString *)getGppConsentString;
- (BOOL)getDoNotTrack;

@end
