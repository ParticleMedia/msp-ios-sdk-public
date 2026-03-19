//
//  RewardedLifecycleController.swift
//  MSPiOSCore
//

import Foundation

public final class RewardedLifecycleController {
    private enum Constants {
        static let logTag = "Rewarded"
    }

    private weak var adListener: AdListener?
    // `weak` rather than `unowned`: the controller is always owned by the ad itself, so
    // this reference will never dangle in practice, but `weak` is more resilient to future
    // refactoring and avoids a crash if the ownership invariant ever breaks.
    private weak var ad: RewardedAd?

    public private(set) var hasEarnedReward = false
    public private(set) var hasDismissed = false

    public init(adListener: AdListener?, ad: RewardedAd) {
        self.adListener = adListener
        self.ad = ad
    }

    public func markDisplayed() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let ad else {
            MSPLogger.shared.error(tag: Constants.logTag, message: "Rewarded impression dropped because ad is already released")
            return
        }
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message: "Rewarded ad impression recorded. requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        adListener?.onAdImpression(ad: ad)
    }

    public func markClicked() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let ad else {
            MSPLogger.shared.error(tag: Constants.logTag, message: "Rewarded click dropped because ad is already released")
            return
        }
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message: "Rewarded ad click recorded. requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        adListener?.onAdClick(ad: ad)
    }

    public func markRewardEarned() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasEarnedReward else {
            MSPLogger.shared.info(tag: Constants.logTag, message: "Duplicate rewarded callback ignored")
            return
        }
        guard let ad else {
            MSPLogger.shared.error(tag: Constants.logTag, message: "Reward callback dropped because ad is already released")
            return
        }
        hasEarnedReward = true
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message: "Rewarded ad reward earned. reward=\(ad.reward.type):\(ad.reward.amount), requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        if adListener == nil {
            MSPLogger.shared.error(tag: Constants.logTag, message: "Reward callback cannot be forwarded because listener is nil")
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
            MSPLogger.shared.error(tag: Constants.logTag, message: "Rewarded dismiss dropped because ad is already released")
            return
        }
        hasDismissed = true
        let order = hasEarnedReward ? "after_reward" : "before_reward"
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message: "Rewarded ad dismissed. order=\(order), requestId=\(ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] ?? "nil")")
        adListener?.onAdDismissed(ad: ad)
    }
}
