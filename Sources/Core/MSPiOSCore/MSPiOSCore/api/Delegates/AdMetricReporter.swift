//
//  AdMetricReporter.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

import Foundation

public struct AdClickMetadata {
    public let clickAreaName: String?
    public let clickPosition: UInt32?

    public init(clickAreaName: String? = nil, clickPosition: UInt32? = nil) {
        self.clickAreaName = clickAreaName
        self.clickPosition = clickPosition
    }
}

public protocol AdMetricReporter: AnyObject {
    func logAdImpression(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?)

    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?)

    /// Reports an ad click with optional click metadata captured by the creative bridge.
    /// Default implementation forwards to the legacy method for source compatibility.
    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, clickMetadata: AdClickMetadata?)

    /// Reports that the user has earned the reward for a rewarded ad.
    /// Fired exactly once per ad instance, after `RewardedLifecycleController.markRewardEarned()`.
    func logAdRewarded(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?)

    func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPAd?)

    func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool)

    func logAdHide(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, adScreenShot: Data?, fullScreenShot: Data?)

    func logAdReport(
        ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, description: String?, adScreenShot: Data?,
        fullScreenShot: Data?)

    func logAdDismiss(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?)

    func logAdResponse(
        ad: MSPiOSCore.MSPAd?, adRequest: MSPiOSCore.AdRequest, errorCode: MSPErrorCode, errorMessage: String?)
}

public extension AdMetricReporter {
    func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?, clickMetadata: AdClickMetadata?) {
        logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
    }

    /// Default no-op keeps existing custom reporters source-compatible.
    func logAdRewarded(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {}
}

public enum MSPErrorCode: Int {
    case ERROR_CODE_UNSPECIFIED = 0
    case ERROR_CODE_SUCCESS = 1
    case ERROR_CODE_NO_FILL = 2
    case ERROR_CODE_INVALID_REQUEST = 3
    case ERROR_CODE_INTERNAL_ERROR = 4
    case ERROR_CODE_NETWORK_ERROR = 5
}
