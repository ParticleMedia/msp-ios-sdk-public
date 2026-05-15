//
//  NovaRewardedAd.swift
//  NovaAdapter
//

import Foundation
import MSPiOSCore
import NovaCore
import UIKit

/// Adapter-layer wrapper for a Nova rewarded ad.
/// Inherits `MSPiOSCore.RewardedAd` and bridges between `NovaRewardedAdItem`
/// and `RewardedLifecycleController` for correct reward state management.
public final class NovaRewardedAd: MSPiOSCore.RewardedAd {

    // MARK: - Properties

    /// The Nova ad item carrying the HTML creative.
    /// Set by `NovaAdapter` during `loadAdCreative`; read-only to external consumers.
    public internal(set) var rewardedAdItem: NovaRewardedAdItem?

    /// Weak reference to the presenting root view controller.
    public weak var rootViewController: UIViewController?

    /// Manages reward state and ensures at-most-once delivery of `onAdRewardReceived`.
    /// Initialized lazily because `self` is needed as the `ad` reference.
    /// Safe: all SDK delegate callbacks are dispatched to the main thread before first access.
    lazy var lifecycleController: RewardedLifecycleController = {
        RewardedLifecycleController(adListener: adListener, ad: self, adMetricReporter: adNetworkAdapter?.getAdMetricReporter(), adRequest: adNetworkAdapter?.getAdRequest())
    }()

    // MARK: - Init

    public init(
        adNetworkAdapter: AdNetworkAdapter,
        reward: Reward?,
        rootViewController: UIViewController?,
        adListener: AdListener?
    ) {
        self.rootViewController = rootViewController
        super.init(adNetworkAdapter: adNetworkAdapter, reward: reward)
        self.adListener = adListener
    }

    // MARK: - Show

    @MainActor
    public override func show(rootViewController: UIViewController?) {
        presentRewardedAd(
            rootViewController: rootViewController,
            reportHandling: NovaRewardedAdNoOpReportHandling()
        )
    }

    @MainActor
    public override func show(
        rootViewController: UIViewController?,
        rewardedAdReportHandling: (any RewardedAdReportHandling)?
    ) {
        presentRewardedAd(
            rootViewController: rootViewController,
            reportHandling: RewardedReportHandlerAdapter(
                outer: rewardedAdReportHandling,
                ad: self
            )
        )
    }

    @MainActor
    private func presentRewardedAd(
        rootViewController: UIViewController?,
        reportHandling: any NovaFullScreenAdReportHandling
    ) {
        guard let rewardedAdItem, let rootVC = rootViewController ?? self.rootViewController else {
            MSPLogger.shared.error(message: "[Adapter: Nova] show() called with no valid rootViewController or rewardedAdItem")
            return
        }
        MSPLogger.shared.info(
            message: "[Adapter: Nova] Showing rewarded ad. hasAdItem=true, reward=\(reward.map { "\($0.type):\($0.amount)" } ?? "nil")")
        rewardedAdItem.present(rootViewController: rootVC, reportHandling: reportHandling)
    }

    // MARK: - Lifecycle bridge (called by NovaAdapter delegate)

    func markDisplayed() {
        lifecycleController.markDisplayed()
    }

    func markClicked(clickMetadata: AdClickMetadata? = nil) {
        lifecycleController.markClicked(clickMetadata: clickMetadata)
    }

    func markDismissed() {
        lifecycleController.markDismissed()
    }

    func markRewardEarned() {
        lifecycleController.markRewardEarned()
    }

    // MARK: - isValid

    public override func isValid() -> Bool {
        rewardedAdItem != nil
    }
}

// MARK: - No-op report handling

/// Fallback used when the host app does not provide a rewarded report handler.
private struct NovaRewardedAdNoOpReportHandling: NovaFullScreenAdReportHandling {
    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext) {}
}
