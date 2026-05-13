//
//  RewardedLifecycleController.swift
//  MSPiOSCore
//

import Foundation

/// Manages rewarded ad lifecycle state: impression, click, reward, and dismiss.
/// Provides idempotency guards so each event fires at most once per ad session,
/// preventing duplicate MES event reporting regardless of how many times the
/// underlying SDK fires a given callback.
///
/// - Note: This class is an SDK utility exposed publicly so adapter modules in
///   sibling packages can construct it. It is not intended for direct use by SDK
///   integrators — adapters route lifecycle events through this controller to
///   centralize MES dispatch. All methods must be called on the main queue
///   (`dispatchPrecondition` enforced).
public final class RewardedLifecycleController {
    private enum Constants {
        static let logTag = "Rewarded"
    }

    private weak var adListener: AdListener?
    // `weak` rather than `unowned`: the controller is always owned by the ad itself, so
    // this reference will never dangle in practice, but `weak` is more resilient to future
    // refactoring and avoids a crash if the ownership invariant ever breaks.
    private weak var ad: RewardedAd?

    /// Reporter, request, and bid response used to emit MES events for impression / click /
    /// reward. Held weakly to avoid retaining the adapter's reporter; nil-tolerant.
    /// When the caller does not pass these explicitly, they are looked up at use time via
    /// `ad.adNetworkAdapter` so adapters wire up MES through the protocol getters without
    /// each call site repeating the boilerplate. The bid response is critical: without it
    /// `MESMetricReporter` falls back to a synthetic seatBid with empty
    /// `adid/adm/crid/cid/id/lurl/nurl/impid`, which silently degrades the rewarded MES
    /// payload on the backend.
    private weak var injectedAdMetricReporter: AdMetricReporter?
    private let injectedAdRequest: AdRequest?
    private let injectedBidResponse: Any?

    private var resolvedAdMetricReporter: AdMetricReporter? {
        injectedAdMetricReporter ?? ad?.adNetworkAdapter?.getAdMetricReporter()
    }

    private var resolvedAdRequest: AdRequest? {
        injectedAdRequest ?? ad?.adNetworkAdapter?.getAdRequest()
    }

    private var resolvedBidResponse: Any? {
        injectedBidResponse ?? ad?.adNetworkAdapter?.getBidResponse()
    }

    private var hasDisplayed = false
    private var hasClicked = false
    private var hasEarnedReward = false
    private var hasDismissed = false

    public init(
        adListener: AdListener?,
        ad: RewardedAd,
        adMetricReporter: AdMetricReporter? = nil,
        adRequest: AdRequest? = nil,
        bidResponse: Any? = nil
    ) {
        self.adListener = adListener
        self.ad = ad
        self.injectedAdMetricReporter = adMetricReporter
        self.injectedAdRequest = adRequest
        self.injectedBidResponse = bidResponse
    }

    public func markDisplayed() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasDisplayed else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Duplicate rewarded impression callback ignored")
            return
        }
        guard let ad else {
            MSPLogger.shared.error(
                tag: Constants.logTag, message: "Rewarded impression dropped because ad is already released")
            return
        }
        hasDisplayed = true
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "Rewarded ad impression recorded. requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        if let adListener {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching impression callback to listener")
            adListener.onAdImpression(ad: ad)
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Impression callback cannot be forwarded because listener is nil")
        }
        if let adRequest = resolvedAdRequest, let reporter = resolvedAdMetricReporter {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching ad_impression MES event for rewarded ad")
            reporter.logAdImpression(ad: ad, adRequest: adRequest, bidResponse: resolvedBidResponse)
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Skipping ad_impression MES (adRequest=\(resolvedAdRequest != nil), reporter=\(resolvedAdMetricReporter != nil))")
        }
    }

    public func markClicked(clickMetadata: AdClickMetadata? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasClicked else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Duplicate rewarded click callback ignored")
            return
        }
        guard let ad else {
            MSPLogger.shared.error(
                tag: Constants.logTag, message: "Rewarded click dropped because ad is already released")
            return
        }
        hasClicked = true
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message: "Rewarded ad click recorded. requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        if let adListener {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching click callback to listener")
            adListener.onAdClick(ad: ad)
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Click callback cannot be forwarded because listener is nil")
        }
        if let adRequest = resolvedAdRequest, let reporter = resolvedAdMetricReporter {
            MSPLogger.shared.info(
                tag: Constants.logTag,
                message:
                    "Dispatching ad_click MES event for rewarded ad. clickAreaName=\(clickMetadata?.clickAreaName ?? "nil"), clickPosition=\(clickMetadata?.clickPosition.map(String.init) ?? "nil")"
            )
            reporter.logAdClick(
                ad: ad,
                adRequest: adRequest,
                bidResponse: resolvedBidResponse,
                clickMetadata: clickMetadata
            )
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Skipping ad_click MES (adRequest=\(resolvedAdRequest != nil), reporter=\(resolvedAdMetricReporter != nil))")
        }
    }

    public func markRewardEarned() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasDismissed else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Reward callback ignored because ad is already dismissed")
            return
        }
        guard !hasEarnedReward else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Duplicate rewarded callback ignored")
            return
        }
        guard let ad else {
            MSPLogger.shared.error(
                tag: Constants.logTag, message: "Reward callback dropped because ad is already released")
            return
        }
        hasEarnedReward = true
        let rewardDescription = ad.reward.map { "\($0.type):\($0.amount)" } ?? "nil"
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "Rewarded ad reward earned. reward=\(rewardDescription), requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")"
        )
        // Rewarded uses only the Nova `AD_EVENT_REWARDED` event (FR-023), fired by
        // `NovaAdMetricReporter.logAdRewarded` at the JSBridge call site. There is no
        // MES `ad_rewarded` event — earlier wiring mistakenly added one.
        guard let adListener else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Reward callback cannot be forwarded because listener is nil")
            return
        }
        MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching rewarded callback to listener")
        adListener.onAdRewardReceived(ad: ad)
    }

    public func markDismissed() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasDismissed else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Duplicate rewarded dismiss ignored")
            return
        }
        guard let ad else {
            MSPLogger.shared.error(
                tag: Constants.logTag, message: "Rewarded dismiss dropped because ad is already released")
            return
        }
        hasDismissed = true
        let order = hasEarnedReward ? "after_reward" : "before_reward"
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "Rewarded ad dismissed. order=\(order), requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")"
        )
        if let adListener {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching dismiss callback to listener")
            adListener.onAdDismissed(ad: ad)
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Dismiss callback cannot be forwarded because listener is nil")
        }
        if let adRequest = resolvedAdRequest, let reporter = resolvedAdMetricReporter {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching ad_dismiss MES event for rewarded ad")
            reporter.logAdDismiss(ad: ad, adRequest: adRequest, bidResponse: resolvedBidResponse)
        } else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "Skipping ad_dismiss MES (adRequest=\(resolvedAdRequest != nil), reporter=\(resolvedAdMetricReporter != nil))")
        }
    }
}
