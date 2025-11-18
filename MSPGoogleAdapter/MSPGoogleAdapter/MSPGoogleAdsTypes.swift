//
//  MSPGoogleAdsTypes.swift
//  GoogleAdapter
//
//  Unified typealias abstraction layer for CocoaPods and SwiftPM compatibility
//  This is the ONLY file that should use #if SWIFT_PACKAGE for Google Mobile Ads types
//

#if SWIFT_PACKAGE
import GoogleMobileAds
import UIKit

// View Types
public typealias MSPGADMediaView = GADMediaView
public typealias MSPGADNativeAdView = GADNativeAdView
public typealias MSPGADBannerView = GADBannerView

// Ad Types
public typealias MSPGADNativeAd = GADNativeAd
public typealias MSPGADInterstitialAd = GADInterstitialAd
public typealias MSPGAMBannerView = GAMBannerView

// Request Types
public typealias MSPGADRequest = GADRequest
public typealias MSPGADAdLoader = GADAdLoader
public typealias MSPGADAdLoaderAdType = GADAdLoaderAdType
public typealias MSPGADVideoOptions = GADVideoOptions
public typealias MSPGADExtras = GADExtras

// Size Types
public typealias MSPGADAdSize = GADAdSize

// Protocol Types
public typealias MSPGADFullScreenPresentingAd = GADFullScreenPresentingAd

// Delegate Protocols
public typealias MSPGADBannerViewDelegate = GADBannerViewDelegate
public typealias MSPGADNativeAdLoaderDelegate = GADNativeAdLoaderDelegate
public typealias MSPGADNativeAdDelegate = GADNativeAdDelegate
public typealias MSPGADFullScreenContentDelegate = GADFullScreenContentDelegate
public typealias MSPGAMBannerAdLoaderDelegate = GAMBannerAdLoaderDelegate

#else
import GoogleMobileAds
import UIKit

// View Types
public typealias MSPGADMediaView = GoogleMobileAds.MediaView
public typealias MSPGADNativeAdView = GoogleMobileAds.NativeAdView
public typealias MSPGADBannerView = GoogleMobileAds.BannerView

// Ad Types
public typealias MSPGADNativeAd = GoogleMobileAds.NativeAd
public typealias MSPGADInterstitialAd = GoogleMobileAds.InterstitialAd
public typealias MSPGAMBannerView = GoogleMobileAds.AdManagerBannerView

// Request Types
public typealias MSPGADRequest = GoogleMobileAds.AdManagerRequest
public typealias MSPGADAdLoader = GoogleMobileAds.AdLoader
public typealias MSPGADAdLoaderAdType = GoogleMobileAds.AdLoaderAdType
public typealias MSPGADVideoOptions = GoogleMobileAds.VideoOptions
public typealias MSPGADExtras = GoogleMobileAds.Extras

// Size Types
public typealias MSPGADAdSize = GoogleMobileAds.AdSize

// Protocol Types
public typealias MSPGADFullScreenPresentingAd = GoogleMobileAds.FullScreenPresentingAd

// Delegate Protocols
public typealias MSPGADBannerViewDelegate = GoogleMobileAds.BannerViewDelegate
public typealias MSPGADNativeAdLoaderDelegate = GoogleMobileAds.NativeAdLoaderDelegate
public typealias MSPGADNativeAdDelegate = GoogleMobileAds.NativeAdDelegate
public typealias MSPGADFullScreenContentDelegate = GoogleMobileAds.FullScreenContentDelegate
public typealias MSPGAMBannerAdLoaderDelegate = GoogleMobileAds.AdManagerBannerAdLoaderDelegate

#endif

// Helper functions for API differences that can't be typealiased
#if SWIFT_PACKAGE
public func MSPGADMobileAdsStart(completionHandler: ((Error?) -> Void)?) {
    let sharedInstance = GADMobileAds.sharedInstance()
    if let completionHandler = completionHandler {
        sharedInstance.start(completionHandler: { (status: GADInitializationStatus) in
            // Convert GADInitializationStatus to Error? if needed
            // For now, pass nil as error since initialization succeeded
            completionHandler(nil)
        })
    } else {
        sharedInstance.start(completionHandler: nil)
    }
}

public func MSPGADMobileAdsSDKVersion() -> String {
    return GADMobileAds.sharedInstance().sdkVersion
}

public func MSPGADInterstitialAdLoad(adUnitID: String, request: MSPGADRequest, completion: @escaping (MSPGADInterstitialAd?, Error?) -> Void) {
    GADInterstitialAd.load(withAdUnitID: adUnitID, request: request, completionHandler: completion)
}

// AdSize constants
public let MSPGADAdSizeBanner = GADAdSizeBanner
public let MSPGADAdSizeMediumRectangle = GADAdSizeMediumRectangle

// NSValue conversion helpers
public func MSPNSValueFromGADAdSize(_ adSize: MSPGADAdSize) -> NSValue {
    return NSValueFromGADAdSize(adSize)
}

// Adaptive banner helper functions (not available in SPM)
// These functions are only available in CocoaPods Ad Manager SDK
public func MSPGADCurrentOrientationAnchoredAdaptiveBanner(width: CGFloat) -> MSPGADAdSize {
    // SPM fallback: return standard banner size
    // Note: Adaptive banner APIs are Ad Manager specific and not available in SPM GoogleMobileAds package
    return MSPGADAdSizeBanner
}

public func MSPGADInlineAdaptiveBanner(width: CGFloat, maxHeight: CGFloat) -> MSPGADAdSize {
    // SPM fallback: return standard banner size
    // Note: Adaptive banner APIs are Ad Manager specific and not available in SPM GoogleMobileAds package
    return MSPGADAdSizeBanner
}

// Video options property helper (property name differs between SPM and CocoaPods)
public func MSPGADVideoOptionsSetStartMuted(_ options: MSPGADVideoOptions, muted: Bool) {
    options.startMuted = muted
}

// AdLoader ad types helper (Ad Manager banner type not available in SPM)
public func MSPGADAdLoaderAdTypesForMultiFormat() -> [MSPGADAdLoaderAdType] {
    // SPM doesn't support .adManagerBanner, fallback to .native only
    return [.native]
}

// Request adString property helper (Ad Manager specific - not available in SPM)
public func MSPGADRequestSetAdString(_ request: MSPGADRequest, adString: String?) {
    // This is a no-op for SPM builds since adString is not available
    // The property is only available in CocoaPods AdManagerRequest
}

// InterstitialAd present() method helper (method signature differs between SPM and CocoaPods)
// Extension to provide unified present(from:) method
extension MSPGADInterstitialAd {
    public func present(from rootViewController: UIViewController?) {
        // For SPM, call present(from:) on GADInterstitialAd (which accepts optional)
        (self as GADInterstitialAd).present(from: rootViewController)
    }
}
#else
public func MSPGADMobileAdsStart(completionHandler: ((Error?) -> Void)?) {
    if let completionHandler = completionHandler {
        MobileAds.shared.start(completionHandler: { _ in
            completionHandler(nil)
        })
    } else {
        MobileAds.shared.start()
    }
}

public func MSPGADMobileAdsSDKVersion() -> String {
    let versionNumber = MobileAds.shared.versionNumber
    return GoogleMobileAds.string(for: versionNumber)
}

public func MSPGADInterstitialAdLoad(adUnitID: String, request: MSPGADRequest, completion: @escaping (MSPGADInterstitialAd?, Error?) -> Void) {
    InterstitialAd.load(with: adUnitID, request: request, completionHandler: completion)
}

// AdSize constants
public let MSPGADAdSizeBanner = GoogleMobileAds.AdSizeBanner
public let MSPGADAdSizeMediumRectangle = GoogleMobileAds.AdSizeMediumRectangle

// NSValue conversion helpers
public func MSPNSValueFromGADAdSize(_ adSize: MSPGADAdSize) -> NSValue {
    // For CocoaPods, use the Swift API nsValue(for:)
    return GoogleMobileAds.nsValue(for: adSize)
}

// Adaptive banner helper functions (Ad Manager specific - available in CocoaPods)
public func MSPGADCurrentOrientationAnchoredAdaptiveBanner(width: CGFloat) -> MSPGADAdSize {
    return GoogleMobileAds.currentOrientationAnchoredAdaptiveBanner(width: width)
}

public func MSPGADInlineAdaptiveBanner(width: CGFloat, maxHeight: CGFloat) -> MSPGADAdSize {
    return GoogleMobileAds.inlineAdaptiveBanner(width: width, maxHeight: maxHeight)
}

// Video options property helper (property name differs between SPM and CocoaPods)
public func MSPGADVideoOptionsSetStartMuted(_ options: MSPGADVideoOptions, muted: Bool) {
    options.shouldStartMuted = muted
}

// AdLoader ad types helper (Ad Manager banner type not available in SPM)
public func MSPGADAdLoaderAdTypesForMultiFormat() -> [MSPGADAdLoaderAdType] {
    return [.native, .adManagerBanner]
}

// Request adString property helper (Ad Manager specific - not available in SPM)
public func MSPGADRequestSetAdString(_ request: MSPGADRequest, adString: String?) {
    if let adString = adString {
        request.adString = adString
    }
}

// InterstitialAd present() method helper (method signature differs between SPM and CocoaPods)
// Extension to provide unified present(from:) method
extension MSPGADInterstitialAd {
    public func present(from rootViewController: UIViewController?) {
        // For CocoaPods, call present(from:) on GoogleMobileAds.InterstitialAd (which accepts optional)
        (self as GoogleMobileAds.InterstitialAd).present(from: rootViewController)
    }
}
#endif
