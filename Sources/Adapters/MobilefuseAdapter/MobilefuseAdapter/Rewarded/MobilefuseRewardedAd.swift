//
//  MobilefuseRewardedAd.swift
//  MobilefuseAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

/// MobileFuse implementation of rewarded ads.
/// Wraps MFRewardedAd SDK and manages reward lifecycle through RewardedLifecycleController.
import Foundation
import MSPiOSCore
import MobileFuseSDK
import UIKit

public final class MobilefuseRewardedAd: MSPiOSCore.RewardedAd {
    // MARK: - Properties
    /// The MFRewardedAd instance for ad presentation
    private let mfRewardedAd: MFRewardedAd?

    /// Weak reference to root view controller for presentation
    private weak var rootViewController: UIViewController?

    /// Delegate handler for MFRewardedAd callbacks
    private let delegateHandler: MobilefuseRewardedAdDelegateHandler

    /// Internal lifecycle controller for managing reward/dismiss state
    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()

    // MARK: - Initialization

    /// Initialize with MFRewardedAd instance and reward configuration
    /// - Parameters:
    ///   - reward: The reward configuration for this ad
    ///   - adListener: Listener for ad events
    ///   - mfRewardedAd: The MFRewardedAd SDK instance
    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, mfRewardedAd: MFRewardedAd?) {
        self.mfRewardedAd = mfRewardedAd
        self.delegateHandler = MobilefuseRewardedAdDelegateHandler()
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)

        // Set up delegate chain
        delegateHandler.rewardedAd = self
        mfRewardedAd?.register(delegateHandler)
    }

    // MARK: - RewardedAd Override Methods

    public override func isValid() -> Bool {
        mfRewardedAd != nil
    }

    /// Presents the rewarded ad full-screen
    /// - Parameter rootViewController: The view controller from which to present
    public override func show(rootViewController: UIViewController?) {
        guard let mfRewardedAd = mfRewardedAd else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: MobileFuse] MFRewardedAd instance is nil")
            return
        }

        guard let viewController = rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: MobileFuse] Root view controller is required for MobileFuse rewarded ad")
            return
        }

        self.rootViewController = viewController

        // Add to view hierarchy and show
        viewController.view.addSubview(mfRewardedAd)
        mfRewardedAd.show()
    }

    // MARK: - Internal Methods

    /// Called by delegate handler when the rewarded ad is rendered/displayed
    internal func handleAdRendered() {
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

    /// Called by delegate handler when the rewarded ad is closed/dismissed
    internal func handleAdClosed() {
        lifecycleController.markDismissed()
    }

    /// Called by delegate handler when an error occurs with the rewarded ad
    internal func handleAdError(reason: String) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: MobileFuse] Rewarded ad error: \(reason)")
    }
}

// MARK: - MobilefuseRewardedAdDelegateHandler

/// NSObject-based delegate handler for IMFAdCallbackReceiver callbacks
private final class MobilefuseRewardedAdDelegateHandler: NSObject, IMFAdCallbackReceiver {
    /// Weak reference to the MobilefuseRewardedAd instance
    weak var rewardedAd: MobilefuseRewardedAd?

    /// Called when the rewarded ad successfully loads
    /// - Parameter ad: The MFRewardedAd instance
    func onAdLoaded(_ ad: MFRewardedAd) {
        // Load success is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }

    /// Called when the rewarded ad is rendered/displayed
    /// - Parameter ad: The MFRewardedAd instance
    func onAdRendered(_ ad: MFRewardedAd) {
        rewardedAd?.handleAdRendered()
    }

    /// Called when the rewarded ad is clicked
    /// - Parameter ad: The MFRewardedAd instance
    func onAdClicked(_ ad: MFRewardedAd) {
        rewardedAd?.handleAdClicked()
    }

    /// Called when the user earns the reward
    /// - Parameter ad: The MFRewardedAd instance
    func onUserEarnedReward(_ ad: MFRewardedAd) {
        rewardedAd?.handleRewardEarned()
    }

    /// Called when the rewarded ad is closed/dismissed
    /// - Parameter ad: The MFRewardedAd instance
    func onAdClosed(_ ad: MFRewardedAd) {
        rewardedAd?.handleAdClosed()
    }

    /// Called when an error occurs with the rewarded ad
    /// - Parameters:
    ///   - ad: The MFRewardedAd instance
    ///   - reason: The error reason
    func onAdError(_ ad: MFRewardedAd, reason: String) {
        rewardedAd?.handleAdError(reason: reason)
    }
}
