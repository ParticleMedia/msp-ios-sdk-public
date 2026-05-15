//
//  NovaInterstitialAdViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit

// MARK: - NovaInterstitialAdViewController

class NovaInterstitialAdViewController: NovaFullScreenAdViewController {

    // MARK: - Init

    init(
        interstitialAd: NovaInterstitialAdItem,
        reportHandling: any NovaInterstitialAdReportHandling,
        orientationMask: UIInterfaceOrientationMask? = nil
    ) {
        self.interstitialAd = interstitialAd
        self.reportHandling = reportHandling
        super.init(adItem: interstitialAd, orientationMask: orientationMask)
    }

    // MARK: - Private

    private let interstitialAd: NovaInterstitialAdItem
    private let reportHandling: any NovaInterstitialAdReportHandling

    // MARK: - Overrides

    override func setupAdView() {
        let adView = NovaInterstitialAdViewFactory.createAdView(
            interstitialAd: interstitialAd,
            viewController: self,
            reportHandling: reportHandling
        )
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.adView = adView
    }

    override func didLogImpression() {
        if let tracingID = interstitialAd.adOpportunityID {
            // TODO: Implement tracing functionality when needed
            DebugLogger.data.info("Tracing impression for ID: \(tracingID, privacy: .public)")
        }
        interstitialAd.delegate?.interstitialAdDidDisplay(interstitialAd)
    }

    // MARK: - Auto-dismiss (two-phase: stage on willEnterForeground, execute on didBecomeActive)
    //
    // Mirrors develop PR #725. willEnterForeground fires before UIKit is fully active, so calling
    // `dismiss` directly there can race the runloop and silently no-op. Stage a pending request
    // here and flush it once didBecomeActive arrives.

    private var pendingAutoDismiss = false

    /// One-way latch — never reset. The VC is dismissed and deallocated after auto-dismiss completes,
    /// so re-entering this state cannot happen for the same VC instance.
    private var isAutoDismissing = false

    @objc override func handleApplicationWillEnterForeground(_ notification: Notification) {
        guard interstitialAd.shouldAutoDismiss else {
            DebugLogger.ui.info("[Interstitial] willEnterForeground — shouldAutoDismiss=false, skip")
            return
        }
        let _didAppear = didAppear
        let _isBeingDismissed = isBeingDismissed
        let _isAutoDismissing = isAutoDismissing
        let _inStack = presentingViewController != nil
        guard _didAppear, !_isBeingDismissed, !_isAutoDismissing, _inStack else {
            DebugLogger.ui.info(
                "[Interstitial] willEnterForeground ignored — not eligible (didAppear=\(_didAppear), isBeingDismissed=\(_isBeingDismissed), isAutoDismissing=\(_isAutoDismissing), inStack=\(_inStack))"
            )
            return
        }
        DebugLogger.ui.info("[Interstitial] willEnterForeground — marking pendingAutoDismiss")
        pendingAutoDismiss = true
    }

    @objc override func handleApplicationDidBecomeActive(_ notification: Notification) {
        if pendingAutoDismiss {
            performAutoDismissIfNeeded()
            return
        }
        super.handleApplicationDidBecomeActive(notification)
    }

    private func performAutoDismissIfNeeded() {
        guard !isAutoDismissing else {
            DebugLogger.ui.info("[Interstitial] pendingAutoDismiss ignored — auto-dismiss already in progress")
            return
        }
        guard let presenter = presentingViewController else {
            DebugLogger.ui.info("[Interstitial] pendingAutoDismiss cancelled — VC no longer in stack")
            return
        }
        DebugLogger.ui.info("[Interstitial] executing pending auto-dismiss")
        pendingAutoDismiss = false
        isAutoDismissing = true
        let ad = interstitialAd
        presenter.dismiss(animated: false) {
            DebugLogger.ui.info("[Interstitial] auto-dismiss completed, notifying delegate")
            ad.delegate?.interstitialAdDidDismiss(ad)
        }
    }
}

// MARK: - UIInterfaceOrientation helpers

internal extension UIInterfaceOrientation {
    var orientationMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}
