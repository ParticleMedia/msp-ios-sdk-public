//
//  RewardedAd.swift
//  MSPiOSCore
//

/// Represents a loaded rewarded ad that can be presented full-screen.
import Foundation
import UIKit

open class RewardedAd: MSPAd {
    /// The reward associated with this ad instance, or `nil` if the ad network did not provide reward metadata.
    public let reward: Reward?

    /// Creates a rewarded ad wrapper for a loaded rewarded ad creative.
    /// - Parameters:
    ///   - adNetworkAdapter: The adapter that loaded the ad.
    ///   - reward: The reward metadata associated with this ad, or `nil` if unavailable.
    public init(adNetworkAdapter: AdNetworkAdapter, reward: Reward?) {
        self.reward = reward
        super.init(adNetworkAdapter: adNetworkAdapter)
    }

    /// Presents the rewarded ad. Subclasses must override this method.
    @MainActor
    open func show(rootViewController: UIViewController?) {
        MSPLogger.shared.error(
            message: "[RewardedAd] show(rootViewController:) called on base class — subclass must override")
    }
}
