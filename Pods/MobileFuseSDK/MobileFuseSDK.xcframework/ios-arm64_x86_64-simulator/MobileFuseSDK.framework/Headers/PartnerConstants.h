//
//  PartnerConstants.h
//  MFSDKCommon
//

#ifndef PartnerConstants_h
#define PartnerConstants_h

typedef NS_ENUM(NSUInteger, MFSDKPartner) {
    MOBILEFUSE_PARTNER_NONE = 0,
    MOBILEFUSE_PARTNER_LIVERAMP = 1,
    MOBILEFUSE_PARTNER_NEUSTAR = 2,
    MOBILEFUSE_PARTNER_NIMBUS = 3
};

typedef NS_ENUM(NSUInteger, MFSDKExtendedUidProvider) { // The uinteger values here match the MFSDKPartner enum
    MOBILEFUSE_EXTENDED_UID_PROVIDER_NONE = 0,
    MOBILEFUSE_EXTENDED_UID_PROVIDER_LIVERAMP = 1,
    MOBILEFUSE_EXTENDED_UID_PROVIDER_FABRICK = 2 // Maps to neustar in MFSDKPartner
};

#endif /* PartnerConstants_h */
