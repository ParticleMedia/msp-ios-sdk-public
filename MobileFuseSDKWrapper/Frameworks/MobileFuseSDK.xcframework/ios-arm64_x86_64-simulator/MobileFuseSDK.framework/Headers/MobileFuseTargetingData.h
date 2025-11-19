//
//  MobileFuseTargetingData.h
//  MobileFuseSDK
//

#ifndef MobileFuseTargetingData_h
#define MobileFuseTargetingData_h

@import Foundation;
@protocol MFExtendedIdDelegate;

// Forward declarations
typedef NS_ENUM(NSUInteger, MFTargetingDataGender);
typedef NS_ENUM(NSUInteger, MFSDKPartner);

@interface MobileFuseTargetingData : NSObject

+ (void)clearAll;

+ (void)setEmail:(NSString * __nullable)email;
+ (nullable NSString *)getEmail;

+ (void)setPhoneNumber:(NSString * __nullable)phoneNumber;
+ (nullable NSString *)getPhoneNumber;

+ (void)setYearOfBirth:(uint)yearOfBirth;
+ (uint)getYearOfBirth;

+ (void)setAge:(uint)age;
+ (uint)getAge;

+ (void)setGender:(MFTargetingDataGender)gender;
+ (MFTargetingDataGender)getGender;

+ (void)setAllowLocation:(BOOL)allow;
+ (BOOL)getAllowLocation;

+ (void)setExtendedUserId:(NSString * __nullable)value forPartner:(NSString * _Nonnull)partner;
+ (nullable NSString *)getExtendedUserIdForPartner:(NSString * _Nonnull)partner;

+ (void)setExtendedUserIdServiceEnabled:(BOOL)enabled;
+ (BOOL)getExtendedUserIdServiceEnabled;

+ (void)setVendorEnabled:(BOOL)enabled forPartner:(NSString * _Nonnull)partner;
+ (BOOL)getVendorEnabledForPartner:(NSString * _Nonnull)partner;

+ (void)setExtendedIdDelegate:(id<MFExtendedIdDelegate> _Nullable)delegate;

+ (void)registerObserver:(id _Nonnull)observer;
+ (void)unregisterObserver:(id _Nonnull)observer;

// Deprecated Methods
+ (void)setLiveRampEnvelope:(NSString * __nullable)envelope __deprecated_msg("Use + (void)setExtendedUserId:(NSString * __nullable)value forPartner:(NSString * _Nonnull)partner");
+ (nullable NSString *)getLiveRampEnvelope __deprecated_msg("Use + (nullable NSString *)getExtendedUserIdForPartner:(NSString * _Nonnull)partner");

+ (void)setFabrickId:(NSString * __nullable)fabrickId __deprecated_msg("Use + (void)setExtendedUserId:(NSString * __nullable)value forPartner:(NSString * _Nonnull)partner");
+ (nullable NSString *)getFabrickId __deprecated_msg("Use + (nullable NSString *)getExtendedUserIdForPartner:(NSString * _Nonnull)partner");

+ (void)setVendorEnabled:(BOOL)enabled forVendor:(MFSDKPartner)vendor __deprecated_msg("Use + (void)setVendorEnabled:(BOOL)enabled forPartner:(NSString *)vendor");
+ (BOOL)getVendorEnabled:(MFSDKPartner)vendor __deprecated_msg("Use + (void)getVendorEnabled:(BOOL)enabled forPartner:(NSString *)vendor");

@end

#endif /* MobileFuseTargetingData_h */
