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

    /// Returns the active `AdRequest` for the most recently loaded ad, if the adapter
    /// retains one. Used by `RewardedLifecycleController` to populate impression / click /
    /// reward MES events. Adapters that do not store the request return nil and the
    /// corresponding MES event is skipped.
    func getAdRequest() -> AdRequest?

    /// Returns the metric reporter wired into the adapter, if any. Used by
    /// `RewardedLifecycleController` to emit MES events from the rewarded lifecycle path.
    func getAdMetricReporter() -> AdMetricReporter?

    /// Returns the winning `BidResponse` (typed as `Any?` to avoid PrebidMobile coupling
    /// in the protocol surface). Used by `RewardedLifecycleController` to attach the full
    /// auction context (winning seat, adid, crid, lurl, nurl, impid, etc.) to MES events;
    /// when nil, MES falls back to a synthetic seatBid with empty fields.
    func getBidResponse() -> Any?
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

    /// Default returns nil; adapters that retain the request override to expose it.
    func getAdRequest() -> AdRequest? { nil }

    /// Default returns nil; adapters that hold a metric reporter override to expose it.
    func getAdMetricReporter() -> AdMetricReporter? { nil }

    /// Default returns nil; adapters that retain the winning bid response override to expose it.
    func getBidResponse() -> Any? { nil }
}
