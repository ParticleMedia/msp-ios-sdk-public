//
//  RewardedAd.swift
//  MSPiOSCore
//

/// Represents a loaded rewarded ad that can be presented full-screen.
import Foundation
import UIKit

public protocol RewardedAdReportHandling: AnyObject {
    func startReportFlow(
        from presentingVC: UIViewController?,
        for ad: RewardedAd,
        metadata: [String: Any]?
    )

    // MARK: Optional Methods
    func canShowReportButton(for ad: RewardedAd) -> Bool
}

extension RewardedAdReportHandling {
    public func canShowReportButton(for ad: RewardedAd) -> Bool { false }
}

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

    /// Presents the rewarded ad with an optional handler that powers the in-creative
    /// "..." feedback icon and the resulting report flow. Default implementation falls
    /// back to `show(rootViewController:)`; subclasses that support the report flow
    /// should override.
    @MainActor
    open func show(
        rootViewController: UIViewController?,
        rewardedAdReportHandling: (any RewardedAdReportHandling)?
    ) {
        show(rootViewController: rootViewController)
    }
}
