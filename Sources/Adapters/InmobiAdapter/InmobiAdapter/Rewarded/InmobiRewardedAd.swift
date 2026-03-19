//
//  InmobiRewardedAd.swift
//  InmobiAdapter
//
//  Created by MSP SDK on 2026-03-12.
//

import Foundation
import UIKit
import MSPiOSCore
import InMobiSDK

/// InMobi implementation of rewarded ads.
/// Wraps IMInterstitial SDK (shared class) and manages reward lifecycle through RewardedLifecycleController.
public final class InmobiRewardedAd: MSPiOSCore.RewardedAd {
    
    // MARK: - Properties
    
    /// The IMInterstitial instance for ad presentation (InMobi uses same class for interstitial and rewarded)
    private let imInterstitial: IMInterstitial?
    
    /// Weak reference to root view controller for presentation
    private weak var rootViewController: UIViewController?
    
    /// Internal lifecycle controller for managing reward/dismiss state
    private lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self)
    }()
    
    // MARK: - Initialization
    
    /// Initialize with IMInterstitial instance and reward configuration
    /// - Parameters:
    ///   - reward: The reward configuration for this ad
    ///   - adListener: Listener for ad events
    ///   - imInterstitial: The IMInterstitial SDK instance
    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward, imInterstitial: IMInterstitial?) {
        self.imInterstitial = imInterstitial
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        
        // Set delegate to receive IMInterstitial callbacks
        imInterstitial?.delegate = self
    }
    
    // MARK: - RewardedAd Override Methods

    public override func isValid() -> Bool {
        imInterstitial != nil
    }

    /// Presents the rewarded ad full-screen
    /// - Parameter rootViewController: The view controller from which to present
    public override func show(rootViewController: UIViewController?) {
        guard let imInterstitial = imInterstitial else {
            adListener?.onError(msg: "IMInterstitial instance is nil", loadInfo: [:])
            return
        }
        
        guard let viewController = rootViewController else {
            adListener?.onError(msg: "Root view controller is required for InMobi rewarded ad", loadInfo: [:])
            return
        }
        
        self.rootViewController = viewController
        imInterstitial.show(from: viewController)
    }
    
}

// MARK: - IMInterstitialDelegate

extension InmobiRewardedAd: IMInterstitialDelegate {
    
    /// Called when the interstitial ad loads successfully
    /// - Parameter interstitial: The IMInterstitial instance
    public func interstitialDidFinishLoading(_ interstitial: IMInterstitial) {
        // Load success is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }
    
    /// Called when the interstitial ad is presented
    /// - Parameter interstitial: The IMInterstitial instance
    public func interstitialDidPresent(_ interstitial: IMInterstitial) {
        lifecycleController.markDisplayed()
    }
    
    /// Called when the interstitial ad receives interaction
    /// - Parameters:
    ///   - interstitial: The IMInterstitial instance
    ///   - params: Interaction parameters
    public func interstitial(_ interstitial: IMInterstitial, didReceiveWith params: [String : Any]?) {
        lifecycleController.markClicked()
    }
    
    /// Called when the user completes the reward action (InMobi specific for rewarded placements)
    /// - Parameters:
    ///   - interstitial: The IMInterstitial instance
    ///   - rewards: The reward information
    public func interstitial(_ interstitial: IMInterstitial, rewardActionCompletedWithRewards rewards: [String : Any]) {
        lifecycleController.markRewardEarned()
    }
    
    /// Called when the interstitial ad is dismissed
    /// - Parameter interstitial: The IMInterstitial instance
    public func interstitialDidDismiss(_ interstitial: IMInterstitial) {
        lifecycleController.markDismissed()
    }
    
    /// Called when the interstitial ad fails to present
    /// - Parameters:
    ///   - interstitial: The IMInterstitial instance
    ///   - error: The error that occurred
    public func interstitial(_ interstitial: IMInterstitial, didFailToPresentWithError error: IMRequestStatus) {
        adListener?.onError(msg: "InMobi rewarded ad failed to present: \(error.description)", loadInfo: [:])
    }
    
    /// Called when the interstitial ad fails to load
    /// - Parameters:
    ///   - interstitial: The IMInterstitial instance
    ///   - error: The error that occurred
    public func interstitial(_ interstitial: IMInterstitial, didFailToLoadWithError error: IMRequestStatus) {
        // Load failure is handled in the adapter's loadAdCreative method
        // This callback is for internal SDK state management
    }
}