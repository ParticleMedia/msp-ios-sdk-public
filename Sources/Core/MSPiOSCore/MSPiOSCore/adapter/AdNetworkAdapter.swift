//
//  AdNetworkAdapter.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//
import Foundation

public protocol AdNetworkAdapter: AnyObject {
    //Deprecated after SDK Bidding:
    //func loadAdCreative(bidResponse: Any, adListener: AdListener, context: Any, adRequest: AdRequest)
    func loadAdCreative(
        bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: AdListener, context: Any,
        adRequest: AdRequest, bidderPlacementId: String, bidderFormat: AdFormat?, params: [String: String]?)

    func initialize(
        initParams: InitializationParameters,
        adapterInitListener: AdapterInitListener,
        context: Any?)

    func destroyAd()

    @MainActor
    func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any)

    func setAdMetricReporter(adMetricReporter: AdMetricReporter)

    func getAdNetwork() -> AdNetwork

    func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?)

    func sendDismissAdEvent()

    func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?)

    func getSDKVersion() -> String

    /// Loads a rewarded ad if the adapter supports it, otherwise provides a default rejection.
    /// Override this method in adapters that support rewarded ads.
    /// - Parameters:
    ///   - bidResponse: The bid response containing ad data
    ///   - auctionBidListener: Listener for auction bid events
    ///   - adListener: Listener for ad events
    ///   - context: Additional context for ad loading
    ///   - adRequest: The ad request configuration
    ///   - bidderPlacementId: The placement ID for this bidder
    ///   - params: Additional parameters for ad loading
    func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    )
}

// MARK: - Rewarded Ad Support

public extension AdNetworkAdapter {
    /// Default implementation for adapters that don't support rewarded ads
    func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    ) {
        // Default implementation: adapter doesn't support rewarded ads
        auctionBidListener.onError(
            error: "\(type(of: self)) does not support the rewarded ad format."
        )
    }
}
