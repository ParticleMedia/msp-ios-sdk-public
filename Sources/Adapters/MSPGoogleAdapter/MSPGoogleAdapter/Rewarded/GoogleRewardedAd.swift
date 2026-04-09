//
//  GoogleRewardedAd.swift
//  MSPGoogleAdapter
//

import Foundation
import GoogleMobileAds
import MSPGoogleAdsTypes
import MSPiOSCore
import UIKit

public final class GoogleRewardedAd: MSPiOSCore.RewardedAd {
    private enum Constants {
        static let logTag = "Rewarded"
    }

    static var presenter = MSPGADRewardedAdPresent

    weak var rootViewController: UIViewController?
    var rewardedAdItem: MSPGADRewardedAd?

    private lazy var lifecycleController = RewardedLifecycleController(adListener: adListener, ad: self)

    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward,
        rewardedAdItem: MSPGADRewardedAd?,
        rootViewController: UIViewController?,
        adListener: AdListener?
    ) {
        self.rewardedAdItem = rewardedAdItem
        self.rootViewController = rootViewController
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        self.adListener = adListener
    }

    public override func show(rootViewController: UIViewController?) {
        let presentingViewController = rootViewController ?? self.rootViewController
        MSPLogger.shared.info(
            tag: Constants.logTag,
            message:
                "[Adapter: Google] Showing rewarded ad. hasAdItem=\(rewardedAdItem != nil), hasRootViewController=\(presentingViewController != nil), reward=\(reward.type):\(reward.amount)"
        )

        guard let presentingViewController else {
            MSPLogger.shared.error(
                tag: Constants.logTag,
                message: "[Adapter: Google] Root view controller is required for Google rewarded ad")
            return
        }

        Self.presenter(rewardedAdItem, presentingViewController) { [weak self] in
            guard let self else { return }
            MSPLogger.shared.info(
                tag: Constants.logTag,
                message:
                    "[Adapter: Google] Reward callback received from Google SDK. reward=\(self.reward.type):\(self.reward.amount)"
            )
            self.lifecycleController.markRewardEarned()
        }
    }

    public override func isValid() -> Bool {
        rewardedAdItem != nil
    }

    func markDisplayed() {
        MSPLogger.shared.info(
            tag: Constants.logTag, message: "[Adapter: Google] Rewarded ad impression callback received")
        lifecycleController.markDisplayed()
    }

    func markClicked() {
        MSPLogger.shared.info(tag: Constants.logTag, message: "[Adapter: Google] Rewarded ad click callback received")
        lifecycleController.markClicked()
    }

    func markDismissed() {
        MSPLogger.shared.info(tag: Constants.logTag, message: "[Adapter: Google] Rewarded ad dismiss callback received")
        lifecycleController.markDismissed()
    }

    func handlePresentError(_ error: Error) {
        MSPLogger.shared.error(
            tag: Constants.logTag,
            message: "[Adapter: Google] Failed to present rewarded ad. error=\(error.localizedDescription)")
    }
}
