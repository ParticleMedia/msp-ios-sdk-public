//
//  MolocoRewardedAd.swift
//  MolocoAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

import Foundation
import MolocoSDK
import MSPiOSCore
import UIKit

/// Moloco implementation of rewarded ads.
/// Wraps MolocoRewardedInterstitial SDK and manages reward lifecycle through RewardedLifecycleController.
public final class MolocoRewardedAd: MSPiOSCore.RewardedAd {
    // MARK: - Properties

    /// The Moloco rewarded instance for ad presentation.
    private let molocoRewarded: (any MolocoRewardedInterstitial)?

    /// Weak reference to root view controller for presentation
    private weak var rootViewController: UIViewController?

    /// Internal lifecycle controller for managing reward/dismiss state
    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    // MARK: - Initialization

    /// Initialize with MolocoRewardedInterstitial instance and reward configuration
    /// - Parameters:
    ///   - adNetworkAdapter: The adapter that loaded the ad
    ///   - reward: The reward configuration for this ad
    ///   - rewardedAdItem: The Moloco rewarded SDK instance
    ///   - rootViewController: Cached root view controller for presentation
    ///   - adListener: Ad event listener
    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward,
        rewardedAdItem: (any MolocoRewardedInterstitial)?,
        rootViewController: UIViewController?,
        adListener: AdListener?
    ) {
        self.rootViewController = rootViewController
        self.molocoRewarded = rewardedAdItem
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        self.adListener = adListener
        rewardedAdItem?.rewardedDelegate = self
    }

    // MARK: - RewardedAd Override Methods

    /// Presents the rewarded ad full-screen
    /// - Parameter rootViewController: The view controller from which to present
    @MainActor
    public override func show(rootViewController: UIViewController?) {
        guard let molocoRewarded = molocoRewarded else {
            adListener?.onError(msg: "Moloco rewarded ad instance is nil", loadInfo: [:])
            return
        }

        guard let viewController = rootViewController ?? self.rootViewController else {
            adListener?.onError(msg: "Root view controller is required for Moloco rewarded ad", loadInfo: [:])
            return
        }

        self.rootViewController = viewController
        molocoRewarded.show(from: viewController)
    }

    public override func isValid() -> Bool {
        molocoRewarded?.isReady ?? false
    }
}

// MARK: - MolocoRewardedDelegate

extension MolocoRewardedAd: MolocoRewardedDelegate {
    public func didLoad(ad: any MolocoAd) {
    }

    public func failToLoad(ad: any MolocoAd, with error: (any Error)?) {
    }

    public func didShow(ad: any MolocoAd) {
        lifecycleController.markDisplayed()
    }

    public func failToShow(ad: any MolocoAd, with error: (any Error)?) {
        let message = error?.localizedDescription ?? "Moloco rewarded ad failed to show"
        adListener?.onError(msg: message, loadInfo: [:])
    }

    public func didHide(ad: any MolocoAd) {
        lifecycleController.markDismissed()
    }

    public func didClick(on ad: any MolocoAd) {
        lifecycleController.markClicked()
    }

    public func userRewarded(ad: any MolocoAd) {
        lifecycleController.markRewardEarned()
    }

    public func rewardedVideoStarted(ad: any MolocoAd) {
    }

    public func rewardedVideoCompleted(ad: any MolocoAd) {
    }
}
