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
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward,
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
            adListener?.onError(msg: "Root view controller is required for Mintegral rewarded ad", loadInfo: [:])
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

    internal func handleImpression() {
        lifecycleController.markDisplayed()
    }

    internal func handleClick() {
        lifecycleController.markClicked()
    }

    internal func handleDismiss(converted: Bool) {
        if converted {
            lifecycleController.markRewardEarned()
        }
        lifecycleController.markDismissed()
    }

    internal func handleShowFailure(_ error: Error) {
        adListener?.onError(msg: "Mintegral rewarded ad failed to show: \(error.localizedDescription)", loadInfo: [:])
    }
}

private final class MintegralRewardedAdDelegateHandler: NSObject, MTGRewardAdShowDelegate {
    weak var rewardedAd: MintegralRewardedAd?

    func onVideoAdShowSuccess(_ placementId: String?, unitId: String?) {
        rewardedAd?.handleImpression()
    }

    func onVideoAdClicked(_ placementId: String?, unitId: String?) {
        rewardedAd?.handleClick()
    }

    func onVideoAdDismissed(
        _ placementId: String?,
        unitId: String?,
        withConverted converted: Bool,
        withRewardInfo rewardInfo: MTGRewardAdInfo?
    ) {
        rewardedAd?.handleDismiss(converted: converted)
    }

    func onVideoAdShowFailed(_ placementId: String?, unitId: String?, withError error: Error) {
        rewardedAd?.handleShowFailure(error)
    }
}
