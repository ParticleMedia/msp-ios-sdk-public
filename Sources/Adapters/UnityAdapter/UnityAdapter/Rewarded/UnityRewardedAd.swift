//
//  UnityRewardedAd.swift
//  UnityAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

import Foundation
import UIKit
import MSPiOSCore
import IronSource

/// Unity/LevelPlay implementation of rewarded ads.
/// Wraps LPMRewardedAd SDK and manages reward lifecycle through RewardedLifecycleController.
public final class UnityRewardedAd: MSPiOSCore.RewardedAd {
    
    // MARK: - Properties
    
    /// The LPMRewardedAd instance for ad presentation
    private let lpmRewardedAd: LPMRewardedAd?
    
    /// Weak reference to root view controller for presentation
    private weak var rootViewController: UIViewController?
    
    /// Delegate handler for LPMRewardedAd callbacks
    private let delegateHandler: UnityRewardedAdDelegateHandler
    
    /// Internal lifecycle controller for managing reward/dismiss state
    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()
    
    // MARK: - Initialization
    
    /// Initialize with LPMRewardedAd instance and reward configuration
    /// - Parameters:
    ///   - adNetworkAdapter: The adapter that loaded the ad
    ///   - reward: The reward configuration for this ad
    ///   - lpmRewardedAd: The LPMRewardedAd SDK instance
    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, lpmRewardedAd: LPMRewardedAd?) {
        self.lpmRewardedAd = lpmRewardedAd
        self.delegateHandler = UnityRewardedAdDelegateHandler()
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        
        // Set up delegate chain
        delegateHandler.rewardedAd = self
        lpmRewardedAd?.setDelegate(delegateHandler)
    }
    
    // MARK: - RewardedAd Override Methods

    public override func isValid() -> Bool {
        lpmRewardedAd?.isAdReady() ?? false
    }

    /// Presents the rewarded ad full-screen
    /// - Parameter rootViewController: The view controller from which to present
    public override func show(rootViewController: UIViewController?) {
        guard let lpmRewardedAd = lpmRewardedAd else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Unity] LPMRewardedAd instance is nil")
            return
        }

        guard let viewController = rootViewController else {
            MSPLogger.shared.error(
                tag: "Rewarded",
                message: "[Adapter: Unity] Root view controller is required for Unity rewarded ad")
            return
        }
        
        self.rootViewController = viewController
        lpmRewardedAd.showAd(viewController: viewController, placementName: nil)
    }
    
    // MARK: - Internal Methods
    
    /// Called by delegate handler when the rewarded ad is displayed
    internal func handleAdDisplayed() {
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
    
    /// Called by delegate handler when the rewarded ad is closed
    internal func handleAdClosed() {
        lifecycleController.markDismissed()
    }
    
    /// Called by delegate handler when the rewarded ad fails to display
    internal func handleDisplayFailure(error: Error) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message: "[Adapter: Unity] Rewarded ad failed to display: \(error.localizedDescription)")
    }
}

// MARK: - UnityRewardedAdDelegateHandler

/// NSObject-based delegate handler for LPMRewardedAdDelegate callbacks
private final class UnityRewardedAdDelegateHandler: NSObject, LPMRewardedAdDelegate {
    
    /// Weak reference to the UnityRewardedAd instance
    weak var rewardedAd: UnityRewardedAd?
    
    /// Called when the rewarded ad loads successfully
    /// - Parameter adInfo: The ad information
    func didLoadAd(with adInfo: LPMAdInfo) {
        // Load success is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }
    
    /// Called when the rewarded ad is displayed
    /// - Parameter adInfo: The ad information
    func didDisplayAd(with adInfo: LPMAdInfo) {
        rewardedAd?.handleAdDisplayed()
    }
    
    /// Called when the rewarded ad is clicked
    /// - Parameter adInfo: The ad information
    func didClickAd(with adInfo: LPMAdInfo) {
        rewardedAd?.handleAdClicked()
    }
    
    /// Called when the user earns the reward
    /// - Parameters:
    ///   - adInfo: The ad information
    ///   - reward: The reward information from Unity SDK
    func didRewardAd(with adInfo: LPMAdInfo, reward: LPMReward) {
        rewardedAd?.handleRewardEarned()
    }
    
    /// Called when the rewarded ad is closed
    /// - Parameter adInfo: The ad information
    func didCloseAd(with adInfo: LPMAdInfo) {
        rewardedAd?.handleAdClosed()
    }
    
    /// Called when the rewarded ad fails to display
    /// - Parameters:
    ///   - adInfo: The ad information
    ///   - error: The error that occurred
    func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        rewardedAd?.handleDisplayFailure(error: error)
    }
    
    /// Called when the rewarded ad fails to load
    /// - Parameters:
    ///   - adUnitId: The ad unit ID
    ///   - error: The error that occurred
    func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        // Load failure is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }
}