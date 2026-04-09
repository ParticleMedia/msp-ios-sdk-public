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
/// - Note: **Internal SDK use only.** This class is an implementation detail of the
///   adapter layer and is not part of the public API contract. It may change without notice.
///   All methods must be called on the main queue (`dispatchPrecondition` enforced).
public final class RewardedLifecycleController {
    private enum Constants {
        static let logTag = "Rewarded"
    }

    private weak var adListener: AdListener?
    // `weak` rather than `unowned`: the controller is always owned by the ad itself, so
    // this reference will never dangle in practice, but `weak` is more resilient to future
    // refactoring and avoids a crash if the ownership invariant ever breaks.
    private weak var ad: RewardedAd?

    private var hasDisplayed = false
    private var hasClicked = false
    private var hasEarnedReward = false
    private var hasDismissed = false

    public init(adListener: AdListener?, ad: RewardedAd) {
        self.adListener = adListener
        self.ad = ad
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
    }

    public func markClicked() {
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
    }

    public func markRewardEarned() {
        dispatchPrecondition(condition: .onQueue(.main))
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
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "Rewarded ad reward earned. reward=\(ad.reward.type):\(ad.reward.amount), requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")"
        )
        if adListener == nil {
            MSPLogger.shared.error(
                tag: Constants.logTag, message: "Reward callback cannot be forwarded because listener is nil")
            return
        }
        MSPLogger.shared.info(tag: Constants.logTag, message: "Dispatching rewarded callback to listener")
        adListener?.onAdRewardReceived(ad: ad)
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
        adListener?.onAdDismissed(ad: ad)
    }
}
