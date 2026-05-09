//
//  NovaRewardedAdItem.swift
//  NovaCore
//

import Foundation
import UIKit

/// Nova ad item for rewarded ads.
/// Inherits shared HTML rendering and presentation from `NovaFullScreenAdItem`.
/// Reward state tracking is delegated to `RewardedLifecycleController` at the adapter layer.
public final class NovaRewardedAdItem: NovaFullScreenAdItem {

    /// Weak delegate for rewarded-specific lifecycle events.
    public weak var delegate: NovaRewardedAdDelegate?

    // MARK: - Presentation

    /// Presents the rewarded ad full-screen.
    public func present(rootViewController: UIViewController, reportHandling: any NovaFullScreenAdReportHandling) {
        dispatchPrecondition(condition: .onQueue(.main))
        DebugLogger.ui.info("NovaRewardedAdItem presenting, adUnitId=\(self.adUnitId, privacy: .public), creativeType=\(String(describing: self.creativeType), privacy: .public)")
        let orientationMask = rootViewController.view.window?.windowScene?.interfaceOrientation.orientationMask
        let viewController = NovaRewardedAdViewController(
            rewardedAd: self,
            reportHandling: reportHandling,
            orientationMask: orientationMask
        )
        storeViewController(viewController)
        viewController.modalPresentationStyle = .fullScreen
        viewController.modalTransitionStyle = .crossDissolve
        rootViewController.present(viewController, animated: true)
    }
}
