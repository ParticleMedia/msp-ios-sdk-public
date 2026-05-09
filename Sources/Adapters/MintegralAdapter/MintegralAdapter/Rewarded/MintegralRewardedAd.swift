//
//  MintegralRewardedAd.swift
//  MintegralAdapter
//

import Foundation
import MSPiOSCore
import MTGSDK
import MTGSDKReward
import UIKit

public final class MintegralRewardedAd: MSPiOSCore.RewardedAd {
    private let placementId: String
    private let unitId: String
    private let mtgRewardAdManager: MTGBidRewardAdManager
    private let delegateHandler = MintegralRewardedAdDelegateHandler()

    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self, adMetricReporter: adNetworkAdapter?.getAdMetricReporter(), adRequest: adNetworkAdapter?.getAdRequest())
    }()

    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward?,
        placementId: String,
        unitId: String,
        mtgRewardAdManager: MTGBidRewardAdManager
    ) {
        self.placementId = placementId
        self.unitId = unitId
        self.mtgRewardAdManager = mtgRewardAdManager
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        delegateHandler.rewardedAd = self
    }

    public override func isValid() -> Bool {
        mtgRewardAdManager.isVideoReadyToPlay(withPlacementId: placementId, unitId: unitId)
    }

    public override func show(rootViewController: UIViewController?) {
        guard let viewController = rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Mintegral] Root view controller is required for Mintegral rewarded ad")
            return
        }

        mtgRewardAdManager.showVideo(
            withPlacementId: placementId,
            unitId: unitId,
            userId: nil,
            delegate: delegateHandler,
            viewController: viewController
        )
    }

    internal func markDisplayed() {
        lifecycleController.markDisplayed()
    }

    internal func markClicked() {
        lifecycleController.markClicked()
    }

    internal func markDismissed(rewardEarned: Bool) {
        if rewardEarned {
            lifecycleController.markRewardEarned()
        }
        lifecycleController.markDismissed()
    }

    internal func handleShowFailure(_ error: Error) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: Mintegral] Rewarded ad failed to show: \(error.localizedDescription)")
    }
}

private final class MintegralRewardedAdDelegateHandler: NSObject, MTGRewardAdShowDelegate {
    weak var rewardedAd: MintegralRewardedAd?

    func onVideoAdShowSuccess(_ placementId: String?, unitId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.markDisplayed()
        }
    }

    func onVideoAdClicked(_ placementId: String?, unitId: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.markClicked()
        }
    }

    func onVideoAdDismissed(
        _ placementId: String?,
        unitId: String?,
        withConverted converted: Bool,
        withRewardInfo rewardInfo: MTGRewardAdInfo?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.markDismissed(rewardEarned: converted)
            self?.rewardedAd?.adNetworkAdapter?.sendDismissAdEvent()
        }
    }

    func onVideoAdShowFailed(_ placementId: String?, unitId: String?, withError error: Error) {
        rewardedAd?.handleShowFailure(error)
    }
}
