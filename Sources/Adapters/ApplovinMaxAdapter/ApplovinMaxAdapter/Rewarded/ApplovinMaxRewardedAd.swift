//
//  ApplovinMaxRewardedAd.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore
import UIKit

public final class ApplovinMaxRewardedAd: MSPiOSCore.RewardedAd {
    // MARK: - Properties

    private let maxRewardedAd: MARewardedAd?
    private weak var rootViewController: UIViewController?

    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    // MARK: - Initialization

    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, maxRewardedAd: MARewardedAd?) {
        self.maxRewardedAd = maxRewardedAd
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
    }

    // MARK: - RewardedAd Override Methods

    public override func isValid() -> Bool {
        maxRewardedAd?.isReady ?? false
    }

    public override func show(rootViewController: UIViewController?) {
        guard let maxRewardedAd = maxRewardedAd else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: ApplovinMax] MARewardedAd instance is nil")
            return
        }

        guard maxRewardedAd.isReady else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: ApplovinMax] Rewarded ad is not ready")
            return
        }

        self.rootViewController = rootViewController
        maxRewardedAd.show()
    }

    // MARK: - Internal Methods

    internal func handleAdDisplayed() {
        lifecycleController.markDisplayed()
    }

    internal func handleAdClicked() {
        lifecycleController.markClicked()
    }

    internal func handleRewardEarned() {
        lifecycleController.markRewardEarned()
    }

    internal func handleAdClosed() {
        lifecycleController.markDismissed()
    }

    internal func handleDisplayFailure(error: MAError) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: ApplovinMax] Rewarded ad failed to display: \(error.message)")
    }
}
