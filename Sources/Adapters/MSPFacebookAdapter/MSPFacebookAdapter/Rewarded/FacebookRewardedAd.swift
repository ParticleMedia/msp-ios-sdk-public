//
//  FacebookRewardedAd.swift
//  MSPFacebookAdapter
//

import FBAudienceNetwork
import Foundation
import MSPiOSCore
import UIKit

public final class FacebookRewardedAd: MSPiOSCore.RewardedAd {
    private enum Constants {
        static let logTag = "Rewarded"
    }

    static var presenter: (FBRewardedVideoAd?, UIViewController) -> Void = { rewardedVideoAdItem, rootViewController in
        rewardedVideoAdItem?.show(fromRootViewController: rootViewController)
    }

    weak var rootViewController: UIViewController?
    var rewardedVideoAdItem: FBRewardedVideoAd?

    private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)

    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward,
        rewardedVideoAdItem: FBRewardedVideoAd?,
        rootViewController: UIViewController?,
        adListener: AdListener?
    ) {
        self.rootViewController = rootViewController
        self.rewardedVideoAdItem = rewardedVideoAdItem
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        self.adListener = adListener
    }

    public override func show(rootViewController: UIViewController?) {
        guard let presentingViewController = rootViewController ?? self.rootViewController else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "[Adapter: Facebook] Failed to show rewarded ad because root view controller is missing")
            return
        }
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "[Adapter: Facebook] Showing rewarded ad. hasAdItem=\(rewardedVideoAdItem != nil), reward=\(reward.type):\(reward.amount)"
        )
        Self.presenter(rewardedVideoAdItem, presentingViewController)
    }

    public override func isValid() -> Bool {
        rewardedVideoAdItem?.isAdValid ?? false
    }

    func markDisplayed() {
        MSPLogger.shared.info(
            tag: Constants.logTag, message: "[Adapter: Facebook] Rewarded ad impression callback received")
        lifecycleController.markDisplayed()
    }

    func markClicked() {
        MSPLogger.shared.info(tag: Constants.logTag, message: "[Adapter: Facebook] Rewarded ad click callback received")
        lifecycleController.markClicked()
    }

    func markRewardEarned() {
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "[Adapter: Facebook] Reward callback received from Facebook SDK. reward=\(reward.type):\(reward.amount)"
        )
        lifecycleController.markRewardEarned()
    }

    func markDismissed() {
        MSPLogger.shared.info(
            tag: Constants.logTag, message: "[Adapter: Facebook] Rewarded ad dismiss callback received")
        lifecycleController.markDismissed()
    }
}
