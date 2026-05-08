//
//  PubmaticRewardedAd.swift
//  PubmaticAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

/// PubMatic implementation of rewarded ads.
/// Wraps POBRewardedAd SDK and manages reward lifecycle through RewardedLifecycleController.
import Foundation
import MSPiOSCore
import OpenWrapSDK
import UIKit

public final class PubmaticRewardedAd: MSPiOSCore.RewardedAd {
    // MARK: - Properties
    /// The POBRewardedAd instance for ad presentation
    private let pobRewardedAd: POBRewardedAd?

    /// Weak reference to root view controller for presentation
    private weak var rootViewController: UIViewController?

    /// Delegate handler for POBRewardedAd callbacks
    private let delegateHandler: PubmaticRewardedAdDelegateHandler

    /// Internal lifecycle controller for managing reward/dismiss state
    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    // MARK: - Initialization

    /// Initialize with POBRewardedAd instance and reward configuration
    /// - Parameters:
    ///   - reward: The reward configuration for this ad
    ///   - adListener: Listener for ad events
    ///   - pobRewardedAd: The POBRewardedAd SDK instance
    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, pobRewardedAd: POBRewardedAd?) {
        self.pobRewardedAd = pobRewardedAd
        self.delegateHandler = PubmaticRewardedAdDelegateHandler()
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)

        // Set up delegate chain
        delegateHandler.rewardedAd = self
        pobRewardedAd?.delegate = delegateHandler
    }

    // MARK: - RewardedAd Override Methods

    public override func isValid() -> Bool {
        pobRewardedAd?.isReady ?? false
    }

    /// Presents the rewarded ad full-screen
    /// - Parameter rootViewController: The view controller from which to present
    public override func show(rootViewController: UIViewController?) {
        guard let pobRewardedAd = pobRewardedAd else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: PubMatic] POBRewardedAd instance is nil")
            return
        }

        guard let viewController = rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: PubMatic] Root view controller is required for PubMatic rewarded ad")
            return
        }

        self.rootViewController = viewController
        pobRewardedAd.show(from: viewController)
    }

    // MARK: - Internal Methods

    /// Called by delegate handler when the rewarded ad records an impression
    internal func handleAdImpression() {
        lifecycleController.markDisplayed()
    }

    /// Called by delegate handler when the rewarded ad is clicked
    internal func handleAdClicked() {
        lifecycleController.markClicked()
    }

    /// Called by delegate handler when the user earns the reward
    internal func handleRewardEarned() {
        lifecycleController.markRewardEarned()
    }

    /// Called by delegate handler when the rewarded ad is dismissed
    internal func handleAdDismissed() {
        lifecycleController.markDismissed()
    }

    /// Called by delegate handler when the rewarded ad fails to show
    internal func handleShowFailure(error: Error) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: PubMatic] Rewarded ad failed to show: \(error.localizedDescription)")
    }
}

// MARK: - PubmaticRewardedAdDelegateHandler

/// NSObject-based delegate handler for POBRewardedAdDelegate callbacks
private final class PubmaticRewardedAdDelegateHandler: NSObject, POBRewardedAdDelegate {
    /// Weak reference to the PubmaticRewardedAd instance
    weak var rewardedAd: PubmaticRewardedAd?

    /// Called when the rewarded ad successfully loads
    /// - Parameter rewardedAd: The POBRewardedAd instance
    func rewardedAdDidReceive(_ rewardedAd: POBRewardedAd) {
        // Load success is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }

    /// Called when the rewarded ad records an impression
    /// - Parameter rewardedAd: The POBRewardedAd instance
    func rewardedAdDidRecordImpression(_ rewardedAd: POBRewardedAd) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.handleAdImpression()
        }
    }

    /// Called when the rewarded ad is clicked
    /// - Parameter rewardedAd: The POBRewardedAd instance
    func rewardedAdDidClick(_ rewardedAd: POBRewardedAd) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.handleAdClicked()
        }
    }

    /// Called when the user earns the reward
    /// - Parameters:
    ///   - rewardedAd: The POBRewardedAd instance
    ///   - reward: The reward information from PubMatic SDK
    func rewardedAd(_ rewardedAd: POBRewardedAd, didReward reward: POBReward) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.handleRewardEarned()
        }
    }

    /// Called when the rewarded ad is dismissed
    /// - Parameter rewardedAd: The POBRewardedAd instance
    func rewardedAdDidDismiss(_ rewardedAd: POBRewardedAd) {
        DispatchQueue.main.async { [weak self] in
            self?.rewardedAd?.handleAdDismissed()
            self?.rewardedAd?.adNetworkAdapter?.sendDismissAdEvent()
        }
    }

    /// Called when the rewarded ad fails to show
    /// - Parameters:
    ///   - rewardedAd: The POBRewardedAd instance
    ///   - error: The error that occurred
    func rewardedAdDidFailToShow(_ rewardedAd: POBRewardedAd, error: Error) {
        self.rewardedAd?.handleShowFailure(error: error)
    }

    /// Called when the rewarded ad fails to load
    /// - Parameters:
    ///   - rewardedAd: The POBRewardedAd instance
    ///   - error: The error that occurred
    func rewardedAdDidFailToReceive(_ rewardedAd: POBRewardedAd, error: Error) {
        // Load failure is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }
}
