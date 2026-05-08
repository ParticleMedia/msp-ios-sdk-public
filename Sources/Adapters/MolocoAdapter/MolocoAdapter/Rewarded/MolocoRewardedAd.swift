//
//  MolocoRewardedAd.swift
//  MolocoAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

/// Moloco implementation of rewarded ads.
/// Wraps MolocoRewardedInterstitial SDK and manages reward lifecycle through RewardedLifecycleController.
import Foundation
import MSPiOSCore
import MolocoSDK
import UIKit

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
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Moloco] Rewarded ad instance is nil")
            return
        }

        guard let viewController = rootViewController ?? self.rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Moloco] Root view controller is required for Moloco rewarded ad")
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
        DispatchQueue.main.async { [weak self] in
            self?.lifecycleController.markDisplayed()
        }
    }

    public func failToShow(ad: any MolocoAd, with error: (any Error)?) {
        let message = error?.localizedDescription ?? "Moloco rewarded ad failed to show"
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: Moloco] Rewarded ad failed to show: \(message)")
    }

    public func didHide(ad: any MolocoAd) {
        DispatchQueue.main.async { [weak self] in
            self?.lifecycleController.markDismissed()
            self?.adNetworkAdapter?.sendDismissAdEvent()
        }
    }

    public func didClick(on ad: any MolocoAd) {
        DispatchQueue.main.async { [weak self] in
            self?.lifecycleController.markClicked()
        }
    }

    public func userRewarded(ad: any MolocoAd) {
        DispatchQueue.main.async { [weak self] in
            self?.lifecycleController.markRewardEarned()
        }
    }

    public func rewardedVideoStarted(ad: any MolocoAd) {
    }

    public func rewardedVideoCompleted(ad: any MolocoAd) {
    }
}
