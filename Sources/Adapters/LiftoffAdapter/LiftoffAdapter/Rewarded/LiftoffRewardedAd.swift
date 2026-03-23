//
//  LiftoffRewardedAd.swift
//  LiftoffAdapter
//

import Foundation
import MSPiOSCore
import UIKit
import VungleAdsSDK

public final class LiftoffRewardedAd: MSPiOSCore.RewardedAd {
    private let vungleRewarded: VungleRewarded
    private let delegateHandler = LiftoffRewardedAdDelegateHandler()

    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, vungleRewarded: VungleRewarded) {
        self.vungleRewarded = vungleRewarded
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        delegateHandler.rewardedAd = self
        vungleRewarded.delegate = delegateHandler
    }

    public override func isValid() -> Bool {
        vungleRewarded.canPlayAd()
    }

    public override func show(rootViewController: UIViewController?) {
        guard let viewController = rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Liftoff] Root view controller is required for Liftoff rewarded ad")
            return
        }

        vungleRewarded.present(with: viewController)
    }

    internal func handleImpression() {
        lifecycleController.markDisplayed()
    }

    internal func handleClick() {
        lifecycleController.markClicked()
    }

    internal func handleReward() {
        lifecycleController.markRewardEarned()
    }

    internal func handleDismiss() {
        lifecycleController.markDismissed()
    }

    internal func handlePresentFailure(_ error: Error) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: Liftoff] Rewarded ad failed to present: \(error.localizedDescription)")
    }
}

private final class LiftoffRewardedAdDelegateHandler: NSObject, VungleRewardedDelegate {
    weak var rewardedAd: LiftoffRewardedAd?

    func rewardedAdDidTrackImpression(_ rewarded: VungleRewarded) {
        rewardedAd?.handleImpression()
    }

    func rewardedAdDidClick(_ rewarded: VungleRewarded) {
        rewardedAd?.handleClick()
    }

    func rewardedAdDidRewardUser(_ rewarded: VungleRewarded) {
        rewardedAd?.handleReward()
    }

    func rewardedAdDidClose(_ rewarded: VungleRewarded) {
        rewardedAd?.handleDismiss()
    }

    func rewardedAdDidFailToPresent(_ rewarded: VungleRewarded, withError error: NSError) {
        rewardedAd?.handlePresentFailure(error)
    }
}
