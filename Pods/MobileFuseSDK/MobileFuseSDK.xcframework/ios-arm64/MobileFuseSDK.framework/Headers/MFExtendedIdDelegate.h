//
//  MFExtendedIdDelegate.h
//  MobileFuseSDK
//

@protocol MFExtendedIdDelegate <NSObject>

- (void)didUpdateExtendedUserIdForPartner:(NSString *)partner withEidValue:(NSString *)eidValue isManaged:(BOOL)managed;

@end
