#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class SharedAdNetwork, SharedAdRequest, SharedBidLoader, SharedMSPManager, SharedKotlinEnumCompanion, SharedKotlinEnum<E>, SharedKotlinArray<T>, SharedAdapterAdLoadError, SharedAdapterInitStatus, SharedBannerAdView, SharedNativeAd, SharedMSPAd, SharedGeo, SharedAdSize, SharedAdRequestBuilder, SharedMSPInitStatus, SharedLogger, SharedKotlinThrowable;

@protocol SharedAdNetworkAdapter, SharedGoogleQueryInfoFetcher, SharedFacebookBidTokenProvider, SharedBidListener, SharedPlatform, SharedInitializationParameters, SharedMSPInitListener, SharedAdNetworkAdapterProvider, SharedBidLoaderProvider, SharedKotlinComparable, SharedAdapterInitListener, SharedAdListener, SharedAdapterAdLoadListener, SharedFacebookBidTokenListener, SharedGoogleQueryInfoListener, SharedAdapterParameters, SharedKotlinIterator;

NS_ASSUME_NONNULL_BEGIN
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wincompatible-property-type"
#pragma clang diagnostic ignored "-Wnullability"

#pragma push_macro("_Nullable_result")
#if !__has_feature(nullability_nullable_result)
#undef _Nullable_result
#define _Nullable_result _Nullable
#endif

__attribute__((swift_name("KotlinBase")))
@interface SharedBase : NSObject
- (instancetype)init __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (void)initialize __attribute__((objc_requires_super));
@end

@interface SharedBase (SharedBaseCopying) <NSCopying>
@end

__attribute__((swift_name("KotlinMutableSet")))
@interface SharedMutableSet<ObjectType> : NSMutableSet<ObjectType>
@end

__attribute__((swift_name("KotlinMutableDictionary")))
@interface SharedMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@end

@interface NSError (NSErrorSharedKotlinException)
@property (readonly) id _Nullable kotlinException;
@end

__attribute__((swift_name("KotlinNumber")))
@interface SharedNumber : NSNumber
- (instancetype)initWithChar:(char)value __attribute__((unavailable));
- (instancetype)initWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
- (instancetype)initWithShort:(short)value __attribute__((unavailable));
- (instancetype)initWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
- (instancetype)initWithInt:(int)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
- (instancetype)initWithLong:(long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
- (instancetype)initWithLongLong:(long long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
- (instancetype)initWithFloat:(float)value __attribute__((unavailable));
- (instancetype)initWithDouble:(double)value __attribute__((unavailable));
- (instancetype)initWithBool:(BOOL)value __attribute__((unavailable));
- (instancetype)initWithInteger:(NSInteger)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
+ (instancetype)numberWithChar:(char)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
+ (instancetype)numberWithShort:(short)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
+ (instancetype)numberWithInt:(int)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
+ (instancetype)numberWithLong:(long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
+ (instancetype)numberWithLongLong:(long long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
+ (instancetype)numberWithFloat:(float)value __attribute__((unavailable));
+ (instancetype)numberWithDouble:(double)value __attribute__((unavailable));
+ (instancetype)numberWithBool:(BOOL)value __attribute__((unavailable));
+ (instancetype)numberWithInteger:(NSInteger)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
@end

__attribute__((swift_name("KotlinByte")))
@interface SharedByte : SharedNumber
- (instancetype)initWithChar:(char)value;
+ (instancetype)numberWithChar:(char)value;
@end

__attribute__((swift_name("KotlinUByte")))
@interface SharedUByte : SharedNumber
- (instancetype)initWithUnsignedChar:(unsigned char)value;
+ (instancetype)numberWithUnsignedChar:(unsigned char)value;
@end

__attribute__((swift_name("KotlinShort")))
@interface SharedShort : SharedNumber
- (instancetype)initWithShort:(short)value;
+ (instancetype)numberWithShort:(short)value;
@end

__attribute__((swift_name("KotlinUShort")))
@interface SharedUShort : SharedNumber
- (instancetype)initWithUnsignedShort:(unsigned short)value;
+ (instancetype)numberWithUnsignedShort:(unsigned short)value;
@end

__attribute__((swift_name("KotlinInt")))
@interface SharedInt : SharedNumber
- (instancetype)initWithInt:(int)value;
+ (instancetype)numberWithInt:(int)value;
@end

__attribute__((swift_name("KotlinUInt")))
@interface SharedUInt : SharedNumber
- (instancetype)initWithUnsignedInt:(unsigned int)value;
+ (instancetype)numberWithUnsignedInt:(unsigned int)value;
@end

__attribute__((swift_name("KotlinLong")))
@interface SharedLong : SharedNumber
- (instancetype)initWithLongLong:(long long)value;
+ (instancetype)numberWithLongLong:(long long)value;
@end

__attribute__((swift_name("KotlinULong")))
@interface SharedULong : SharedNumber
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;
@end

__attribute__((swift_name("KotlinFloat")))
@interface SharedFloat : SharedNumber
- (instancetype)initWithFloat:(float)value;
+ (instancetype)numberWithFloat:(float)value;
@end

__attribute__((swift_name("KotlinDouble")))
@interface SharedDouble : SharedNumber
- (instancetype)initWithDouble:(double)value;
+ (instancetype)numberWithDouble:(double)value;
@end

__attribute__((swift_name("KotlinBoolean")))
@interface SharedBoolean : SharedNumber
- (instancetype)initWithBool:(BOOL)value;
+ (instancetype)numberWithBool:(BOOL)value;
@end

__attribute__((swift_name("AdNetworkAdapterProvider")))
@protocol SharedAdNetworkAdapterProvider
@required
- (id<SharedAdNetworkAdapter> _Nullable)getAdNetworkAdapterAdNetwork:(SharedAdNetwork *)adNetwork __attribute__((swift_name("getAdNetworkAdapter(adNetwork:)")));
- (int32_t)getAdNetworkAdaptersCount __attribute__((swift_name("getAdNetworkAdaptersCount()")));
@end

__attribute__((swift_name("BidListener")))
@protocol SharedBidListener
@required
- (void)onBidResponseBidResponse:(id)bidResponse adNetwork:(SharedAdNetwork *)adNetwork __attribute__((swift_name("onBidResponse(bidResponse:adNetwork:)")));
- (void)onErrorMsg:(NSString *)msg __attribute__((swift_name("onError(msg:)")));
@end

__attribute__((swift_name("BidLoader")))
@interface SharedBidLoader : SharedBase
- (instancetype)initWithGoogleQueryInfoFetcher:(id<SharedGoogleQueryInfoFetcher>)googleQueryInfoFetcher facebookBidTokenProvider:(id<SharedFacebookBidTokenProvider>)facebookBidTokenProvider __attribute__((swift_name("init(googleQueryInfoFetcher:facebookBidTokenProvider:)"))) __attribute__((objc_designated_initializer));
- (void)loadBidPlacementId:(NSString *)placementId adParams:(NSDictionary<NSString *, id> *)adParams bidListener:(id<SharedBidListener>)bidListener adRequest:(SharedAdRequest *)adRequest __attribute__((swift_name("loadBid(placementId:adParams:bidListener:adRequest:)")));
@property (readonly) id<SharedFacebookBidTokenProvider> facebookBidTokenProvider __attribute__((swift_name("facebookBidTokenProvider")));
@property (readonly) id<SharedGoogleQueryInfoFetcher> googleQueryInfoFetcher __attribute__((swift_name("googleQueryInfoFetcher")));
@end

__attribute__((swift_name("BidLoaderProvider")))
@protocol SharedBidLoaderProvider
@required
- (SharedBidLoader *)getBidLoader __attribute__((swift_name("getBidLoader()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Greeting")))
@interface SharedGreeting : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (NSString *)greet __attribute__((swift_name("greet()")));
@end

__attribute__((swift_name("Platform")))
@protocol SharedPlatform
@required
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("IOSPlatform")))
@interface SharedIOSPlatform : SharedBase <SharedPlatform>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("MSPManager")))
@interface SharedMSPManager : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)mSPManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedMSPManager *shared __attribute__((swift_name("shared")));
- (void)doInitInitParams:(id<SharedInitializationParameters>)initParams sdkInitListener:(id<SharedMSPInitListener>)sdkInitListener context:(id _Nullable)context __attribute__((swift_name("doInit(initParams:sdkInitListener:context:)")));
@property id<SharedAdNetworkAdapterProvider> _Nullable adNetworkAdapterProvider __attribute__((swift_name("adNetworkAdapterProvider")));
@property id<SharedBidLoaderProvider> _Nullable bidLoaderProvider __attribute__((swift_name("bidLoaderProvider")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WinnerBid")))
@interface SharedWinnerBid : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((swift_name("KotlinComparable")))
@protocol SharedKotlinComparable
@required
- (int32_t)compareToOther:(id _Nullable)other __attribute__((swift_name("compareTo(other:)")));
@end

__attribute__((swift_name("KotlinEnum")))
@interface SharedKotlinEnum<E> : SharedBase <SharedKotlinComparable>
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SharedKotlinEnumCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(E)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) int32_t ordinal __attribute__((swift_name("ordinal")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdNetwork")))
@interface SharedAdNetwork : SharedKotlinEnum<SharedAdNetwork *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedAdNetwork *google __attribute__((swift_name("google")));
@property (class, readonly) SharedAdNetwork *facebook __attribute__((swift_name("facebook")));
@property (class, readonly) SharedAdNetwork *prebid __attribute__((swift_name("prebid")));
@property (class, readonly) SharedAdNetwork *nova __attribute__((swift_name("nova")));
+ (SharedKotlinArray<SharedAdNetwork *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAdNetwork *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((swift_name("AdNetworkAdapter")))
@protocol SharedAdNetworkAdapter
@required
- (void)destroyAd __attribute__((swift_name("destroyAd()")));
- (void)initializeInitParams:(id<SharedInitializationParameters>)initParams adapterInitListener:(id<SharedAdapterInitListener>)adapterInitListener context:(id _Nullable)context __attribute__((swift_name("initialize(initParams:adapterInitListener:context:)")));
- (void)loadAdCreativeBidResponse:(id)bidResponse adListener:(id<SharedAdListener>)adListener context:(id)context adRequest:(SharedAdRequest *)adRequest __attribute__((swift_name("loadAdCreative(bidResponse:adListener:context:adRequest:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdapterAdLoadError")))
@interface SharedAdapterAdLoadError : SharedKotlinEnum<SharedAdapterAdLoadError *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedAdapterAdLoadError *noFill __attribute__((swift_name("noFill")));
+ (SharedKotlinArray<SharedAdapterAdLoadError *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAdapterAdLoadError *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@end

__attribute__((swift_name("AdapterAdLoadListener")))
@protocol SharedAdapterAdLoadListener
@required
- (void)onAdLoadedFailedError:(SharedAdapterAdLoadError *)error __attribute__((swift_name("onAdLoadedFailed(error:)")));
@end

__attribute__((swift_name("AdapterInitListener")))
@protocol SharedAdapterInitListener
@required
- (void)onCompleteAdNetwork:(SharedAdNetwork *)adNetwork adapterInitStatus:(SharedAdapterInitStatus *)adapterInitStatus message:(NSString *)message __attribute__((swift_name("onComplete(adNetwork:adapterInitStatus:message:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdapterInitStatus")))
@interface SharedAdapterInitStatus : SharedKotlinEnum<SharedAdapterInitStatus *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedAdapterInitStatus *success __attribute__((swift_name("success")));
+ (SharedKotlinArray<SharedAdapterInitStatus *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAdapterInitStatus *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@end

__attribute__((swift_name("AdapterParameters")))
@protocol SharedAdapterParameters
@required
- (NSString *)getConsentString __attribute__((swift_name("getConsentString()")));
- (NSDictionary<NSString *, id> *)getParameters __attribute__((swift_name("getParameters()")));
- (BOOL)hasUserConsent __attribute__((swift_name("hasUserConsent()")));
- (BOOL)isAgeRestrictedUser __attribute__((swift_name("isAgeRestrictedUser()")));
- (BOOL)isDoNotSell __attribute__((swift_name("isDoNotSell()")));
- (BOOL)isInTestMode __attribute__((swift_name("isInTestMode()")));
@end

__attribute__((swift_name("BannerAdAdapterAdLoadListener")))
@protocol SharedBannerAdAdapterAdLoadListener <SharedAdapterAdLoadListener>
@required
- (void)onBannerAdLoadedBannerAd:(SharedBannerAdView *)bannerAd __attribute__((swift_name("onBannerAdLoaded(bannerAd:)")));
@end

__attribute__((swift_name("FacebookBidTokenListener")))
@protocol SharedFacebookBidTokenListener
@required
- (void)onCompleteBidToken:(NSString *)bidToken __attribute__((swift_name("onComplete(bidToken:)")));
@end

__attribute__((swift_name("FacebookBidTokenProvider")))
@protocol SharedFacebookBidTokenProvider
@required
- (void)fetchCompleteListener:(id<SharedFacebookBidTokenListener>)completeListener context:(id)context __attribute__((swift_name("fetch(completeListener:context:)")));
@end

__attribute__((swift_name("GoogleQueryInfoFetcher")))
@protocol SharedGoogleQueryInfoFetcher
@required
- (void)fetchCompleteListener:(id<SharedGoogleQueryInfoListener>)completeListener adRequest:(SharedAdRequest *)adRequest __attribute__((swift_name("fetch(completeListener:adRequest:)")));
@end

__attribute__((swift_name("GoogleQueryInfoListener")))
@protocol SharedGoogleQueryInfoListener
@required
- (void)onCompleteQueryInfo:(NSString *)queryInfo __attribute__((swift_name("onComplete(queryInfo:)")));
@end

__attribute__((swift_name("InitializationParameters")))
@protocol SharedInitializationParameters <SharedAdapterParameters>
@required
- (NSString *)getPrebidAPIKey __attribute__((swift_name("getPrebidAPIKey()")));
- (NSString *)getPrebidHostUrl __attribute__((swift_name("getPrebidHostUrl()")));
@end

__attribute__((swift_name("LoadAdParameters")))
@protocol SharedLoadAdParameters <SharedAdapterParameters>
@required
- (NSString *)getAdUnitId __attribute__((swift_name("getAdUnitId()")));
- (int64_t)getBidExpirationMillis __attribute__((swift_name("getBidExpirationMillis()")));
- (NSString *)getBidPayload __attribute__((swift_name("getBidPayload()")));
- (NSString *)getThirdPartyAdPlacementId __attribute__((swift_name("getThirdPartyAdPlacementId()")));
@end

__attribute__((swift_name("NativeAdAdapterAdLoadListener")))
@protocol SharedNativeAdAdapterAdLoadListener <SharedAdapterAdLoadListener>
@required
- (void)onNativeAdLoadedAd:(SharedNativeAd *)ad __attribute__((swift_name("onNativeAdLoaded(ad:)")));
@end

__attribute__((swift_name("AdListener")))
@protocol SharedAdListener
@required
- (void)onAdClickAd:(SharedMSPAd *)ad __attribute__((swift_name("onAdClick(ad:)")));
- (void)onAdImpressionAd:(SharedMSPAd *)ad __attribute__((swift_name("onAdImpression(ad:)")));
- (void)onAdLoadedAd:(SharedMSPAd *)ad __attribute__((swift_name("onAdLoaded(ad:)")));
- (void)onErrorMsg:(NSString *)msg __attribute__((swift_name("onError(msg:)")));
@end

__attribute__((swift_name("AdLoader")))
@interface SharedAdLoader : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)loadAdPlacementId:(NSString *)placementId adListener:(id<SharedAdListener>)adListener context:(id)context adRequest:(SharedAdRequest *)adRequest __attribute__((swift_name("loadAd(placementId:adListener:context:adRequest:)")));
@property id<SharedAdNetworkAdapter> _Nullable adNetworkAdapter __attribute__((swift_name("adNetworkAdapter")));
@property id<SharedAdNetworkAdapterProvider> _Nullable adNetworkAdapterProvider __attribute__((swift_name("adNetworkAdapterProvider")));
@property SharedBidLoader * _Nullable bidLoader __attribute__((swift_name("bidLoader")));
@property id<SharedBidLoaderProvider> _Nullable bidLoaderProvider __attribute__((swift_name("bidLoaderProvider")));
@end

__attribute__((swift_name("AdNetworkManager")))
@interface SharedAdNetworkManager : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (id<SharedAdNetworkAdapter> _Nullable)getAdNetworkAdapter __attribute__((swift_name("getAdNetworkAdapter()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdRequest")))
@interface SharedAdRequest : SharedBase
- (instancetype)initWithCustomParams:(NSDictionary<NSString *, id> *)customParams geo:(SharedGeo * _Nullable)geo context:(id _Nullable)context adaptiveBannerSize:(SharedAdSize * _Nullable)adaptiveBannerSize adSize:(SharedAdSize * _Nullable)adSize placementId:(NSString *)placementId __attribute__((swift_name("init(customParams:geo:context:adaptiveBannerSize:adSize:placementId:)"))) __attribute__((objc_designated_initializer));
- (SharedAdRequest *)doCopyCustomParams:(NSDictionary<NSString *, id> *)customParams geo:(SharedGeo * _Nullable)geo context:(id _Nullable)context adaptiveBannerSize:(SharedAdSize * _Nullable)adaptiveBannerSize adSize:(SharedAdSize * _Nullable)adSize placementId:(NSString *)placementId __attribute__((swift_name("doCopy(customParams:geo:context:adaptiveBannerSize:adSize:placementId:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedAdSize * _Nullable adSize __attribute__((swift_name("adSize")));
@property (readonly) SharedAdSize * _Nullable adaptiveBannerSize __attribute__((swift_name("adaptiveBannerSize")));
@property (readonly) id _Nullable context __attribute__((swift_name("context")));
@property (readonly) NSDictionary<NSString *, id> *customParams __attribute__((swift_name("customParams")));
@property (readonly) SharedGeo * _Nullable geo __attribute__((swift_name("geo")));
@property (readonly) NSString *placementId __attribute__((swift_name("placementId")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdRequest.Builder")))
@interface SharedAdRequestBuilder : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SharedAdRequestBuilder *)addCustomParamKey:(NSString *)key value:(id)value __attribute__((swift_name("addCustomParam(key:value:)")));
- (SharedAdRequest *)build __attribute__((swift_name("build()")));
- (SharedAdRequestBuilder *)setAdSizeAdSize:(SharedAdSize *)adSize __attribute__((swift_name("setAdSize(adSize:)")));
- (SharedAdRequestBuilder *)setAdaptiveBannerSizeAdSize:(SharedAdSize *)adSize __attribute__((swift_name("setAdaptiveBannerSize(adSize:)")));
- (SharedAdRequestBuilder *)setContextContext:(id)context __attribute__((swift_name("setContext(context:)")));
- (SharedAdRequestBuilder *)setCustomParamsParams:(NSDictionary<NSString *, id> *)params __attribute__((swift_name("setCustomParams(params:)")));
- (SharedAdRequestBuilder *)setGeoLocationGeo:(SharedGeo *)geo __attribute__((swift_name("setGeoLocation(geo:)")));
- (SharedAdRequestBuilder *)setPlacementPlacementId:(NSString *)placementId __attribute__((swift_name("setPlacement(placementId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AdSize")))
@interface SharedAdSize : SharedBase
- (instancetype)initWithWidth:(int32_t)width height:(int32_t)height isInlineAdaptiveBanner:(BOOL)isInlineAdaptiveBanner isAnchorAdaptiveBanner:(BOOL)isAnchorAdaptiveBanner __attribute__((swift_name("init(width:height:isInlineAdaptiveBanner:isAnchorAdaptiveBanner:)"))) __attribute__((objc_designated_initializer));
- (SharedAdSize *)doCopyWidth:(int32_t)width height:(int32_t)height isInlineAdaptiveBanner:(BOOL)isInlineAdaptiveBanner isAnchorAdaptiveBanner:(BOOL)isAnchorAdaptiveBanner __attribute__((swift_name("doCopy(width:height:isInlineAdaptiveBanner:isAnchorAdaptiveBanner:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t height __attribute__((swift_name("height")));
@property (readonly) BOOL isAnchorAdaptiveBanner __attribute__((swift_name("isAnchorAdaptiveBanner")));
@property (readonly) BOOL isInlineAdaptiveBanner __attribute__((swift_name("isInlineAdaptiveBanner")));
@property (readonly) int32_t width __attribute__((swift_name("width")));
@end

__attribute__((swift_name("MSPAd")))
@interface SharedMSPAd : SharedBase
- (instancetype)initWithAdNetworkAdapter:(id<SharedAdNetworkAdapter>)adNetworkAdapter __attribute__((swift_name("init(adNetworkAdapter:)"))) __attribute__((objc_designated_initializer));
- (void)destroy __attribute__((swift_name("destroy()")));
@property (readonly) SharedMutableDictionary<NSString *, id> *adInfo __attribute__((swift_name("adInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BannerAdView")))
@interface SharedBannerAdView : SharedMSPAd
- (instancetype)initWithAdView:(id)adView adNetworkAdapter:(id<SharedAdNetworkAdapter>)adNetworkAdapter __attribute__((swift_name("init(adView:adNetworkAdapter:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithAdNetworkAdapter:(id<SharedAdNetworkAdapter>)adNetworkAdapter __attribute__((swift_name("init(adNetworkAdapter:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (readonly) id adView __attribute__((swift_name("adView")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Geo")))
@interface SharedGeo : SharedBase
- (instancetype)initWithCity:(NSString *)city stateCode:(NSString *)stateCode zipCode:(NSString *)zipCode lat:(NSString *)lat lon:(NSString *)lon __attribute__((swift_name("init(city:stateCode:zipCode:lat:lon:)"))) __attribute__((objc_designated_initializer));
- (SharedGeo *)doCopyCity:(NSString *)city stateCode:(NSString *)stateCode zipCode:(NSString *)zipCode lat:(NSString *)lat lon:(NSString *)lon __attribute__((swift_name("doCopy(city:stateCode:zipCode:lat:lon:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *city __attribute__((swift_name("city")));
@property (readonly) NSString *lat __attribute__((swift_name("lat")));
@property (readonly) NSString *lon __attribute__((swift_name("lon")));
@property (readonly) NSString *stateCode __attribute__((swift_name("stateCode")));
@property (readonly) NSString *zipCode __attribute__((swift_name("zipCode")));
@end

__attribute__((swift_name("MSPInitListener")))
@protocol SharedMSPInitListener
@required
- (void)onCompleteStatus:(SharedMSPInitStatus *)status message:(NSString *)message __attribute__((swift_name("onComplete(status:message:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("MSPInitStatus")))
@interface SharedMSPInitStatus : SharedKotlinEnum<SharedMSPInitStatus *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedMSPInitStatus *success __attribute__((swift_name("success")));
+ (SharedKotlinArray<SharedMSPInitStatus *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedMSPInitStatus *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@end

__attribute__((swift_name("MSPInitializationParameters")))
@protocol SharedMSPInitializationParameters <SharedInitializationParameters>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NativeAd")))
@interface SharedNativeAd : SharedMSPAd
- (instancetype)initWithAdNetworkAdapter:(id<SharedAdNetworkAdapter>)adNetworkAdapter __attribute__((swift_name("init(adNetworkAdapter:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Logger")))
@interface SharedLogger : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)logger __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedLogger *shared __attribute__((swift_name("shared")));
- (void)errorMessage:(NSString *)message __attribute__((swift_name("error(message:)")));
- (void)errorTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("error(tag:msg:)")));
- (void)errorTag:(NSString *)tag message:(NSString *)message throwable:(SharedKotlinThrowable *)throwable __attribute__((swift_name("error(tag:message:throwable:)")));
- (int32_t)getLogLevel __attribute__((swift_name("getLogLevel()")));
- (void)infoMessage:(NSString *)message __attribute__((swift_name("info(message:)")));
- (void)infoTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("info(tag:msg:)")));
- (void)mspdebugMessage:(NSString *)message __attribute__((swift_name("mspdebug(message:)")));
- (void)mspdebugTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("mspdebug(tag:msg:)")));
- (void)setLogLevelLevel:(int32_t)level __attribute__((swift_name("setLogLevel(level:)")));
- (void)verboseMessage:(NSString *)message __attribute__((swift_name("verbose(message:)")));
- (void)verboseTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("verbose(tag:msg:)")));
- (void)warningMessage:(NSString *)message __attribute__((swift_name("warning(message:)")));
- (void)warningTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("warning(tag:msg:)")));
- (void)wtfTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("wtf(tag:msg:)")));
@property (readonly) int32_t ASSERT __attribute__((swift_name("ASSERT")));
@property (readonly) int32_t ERROR __attribute__((swift_name("ERROR")));
@property (readonly) int32_t INFO __attribute__((swift_name("INFO")));
@property (readonly) int32_t MSPDEBUG __attribute__((swift_name("MSPDEBUG")));
@property (readonly) int32_t NONE __attribute__((swift_name("NONE")));
@property (readonly) int32_t VERBOSE __attribute__((swift_name("VERBOSE")));
@property (readonly) int32_t WARN __attribute__((swift_name("WARN")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Platform_iosKt")))
@interface SharedPlatform_iosKt : SharedBase
+ (void)doPrintMessagePriority:(int32_t)messagePriority tag:(NSString *)tag message:(NSString *)message __attribute__((swift_name("doPrint(messagePriority:tag:message:)")));
+ (int64_t)getCurrentTimeMillis __attribute__((swift_name("getCurrentTimeMillis()")));
+ (id<SharedPlatform>)getPlatform __attribute__((swift_name("getPlatform()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinEnumCompanion")))
@interface SharedKotlinEnumCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKotlinEnumCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinArray")))
@interface SharedKotlinArray<T> : SharedBase
+ (instancetype)arrayWithSize:(int32_t)size init:(T _Nullable (^)(SharedInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (T _Nullable)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (id<SharedKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(T _Nullable)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("KotlinThrowable")))
@interface SharedKotlinThrowable : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));

/**
 * @note annotations
 *   kotlin.experimental.ExperimentalNativeApi
*/
- (SharedKotlinArray<NSString *> *)getStackTrace __attribute__((swift_name("getStackTrace()")));
- (void)printStackTrace __attribute__((swift_name("printStackTrace()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedKotlinThrowable * _Nullable cause __attribute__((swift_name("cause")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
- (NSError *)asError __attribute__((swift_name("asError()")));
@end

__attribute__((swift_name("KotlinIterator")))
@protocol SharedKotlinIterator
@required
- (BOOL)hasNext __attribute__((swift_name("hasNext()")));
- (id _Nullable)next __attribute__((swift_name("next()")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
