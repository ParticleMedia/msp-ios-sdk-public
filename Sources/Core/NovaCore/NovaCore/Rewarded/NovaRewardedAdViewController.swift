//
//  NovaRewardedAdViewController.swift
//  NovaCore
//

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit

/// Full-screen view controller for rewarded ads.
/// Inherits common presentation, orientation locking, and impression logging from `NovaFullScreenAdViewController`.
///
/// Key differences from interstitial:
/// - Does NOT auto-dismiss on `willEnterForeground`.
/// - Forwards `didEarnReward()` from the JSBridge to `NovaRewardedAdDelegate`.
/// - Handles WebView process termination by dismissing without reward.
class NovaRewardedAdViewController: NovaFullScreenAdViewController {

    // MARK: - Init

    init(
        rewardedAd: NovaRewardedAdItem,
        reportHandling: any NovaFullScreenAdReportHandling,
        orientationMask: UIInterfaceOrientationMask? = nil
    ) {
        self.rewardedAd = rewardedAd
        self.reportHandling = reportHandling
        super.init(adItem: rewardedAd, orientationMask: orientationMask)
    }

    // MARK: - Private

    private let rewardedAd: NovaRewardedAdItem
    private let reportHandling: any NovaFullScreenAdReportHandling

    /// Lazily-built action helper that opens the landing page (Safari/in-app browser) and
    /// fires Nova-side click tracking when the user taps the CTA. Mirrors the wiring used
    /// by `NovaInterstitialAdNormalView`. Without this the H5 click only logs the click event
    /// but never navigates anywhere.
    private lazy var actionHelper: NovaActionHelper<NovaActionState.Init> = NovaActionHelper.build(
        with: .adInViewController(
            model: AdActionModel(
                tracingInfo: rewardedAd.actionTracingInfo,
                extraInfo: rewardedAd.actionExtraInfo,
                ctrType: rewardedAd.adCtrType
            ),
            viewController: Weak(self)
        )
    )

    private let presentStartTime: CFTimeInterval = CACurrentMediaTime()

    // MARK: - Overrides

    override func setupAdView() {
        guard case let .html(model) = rewardedAd.mediaContent.adMedia else {
            DebugLogger.data.error("NovaRewardedAdVC setupAdView: ad media is not .html, cannot display")
            return
        }
        let htmlView: NovaAdHtmlView
        if let cached = rewardedAd.cachedHtmlView {
            htmlView = cached
            // Match interstitial's `NovaInterstitialAdPageSubviewHandler.ensureHtmlView` —
            // cachedHtmlView is a "consume after taking" cache. Clear it so the ad item
            // does not keep a strong reference to the live WKWebView for its lifetime, and
            // so a subsequent `show()` rebuilds the WebView instead of reusing a stale one.
            rewardedAd.cachedHtmlView = nil
        } else {
            htmlView = NovaAdHtmlView(supportReportHandling: false)
        }
        htmlView.config(
            with: model.currentPage,
            htmlActionDelegate: self,
            tracingInfo: .init(adUnitId: rewardedAd.adUnitId, encryptedToken: rewardedAd.encryptedAdToken)
        )
        view.addSubview(htmlView)
        htmlView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        // Plumb the H5 view through the base class's `adView` so VC lifecycle hooks
        // (will/didAppear, will/didDisappear, willTransit) and the foreground /
        // background observers reach the rewarded H5. Default protocol impls are no-op,
        // so this changes architecture without changing current behavior; future H5
        // pause/resume work has a single anchor.
        self.adView = htmlView
    }

    override func didLogImpression() {
        rewardedAd.delegate?.rewardedAdDidDisplay(rewardedAd)
    }

    /// Rewarded ads do NOT auto-dismiss on foreground — override as no-op.
    @objc override func handleApplicationWillEnterForeground(_ notification: Notification) {
        // No-op: rewarded ads must not be dismissed on app foreground.
    }
}

// MARK: - NovaAdHtmlActionDelegate

extension NovaRewardedAdViewController: NovaAdHtmlActionDelegate {
    func didTapAdCtr(_ payload: NovaAdClickPayload) {
        DebugLogger.ui.info("NovaRewardedAdVC click detected, clickArea=\(String(describing: payload.area), privacy: .public), clickPosition=\(String(describing: payload.clickPosition), privacy: .public), extras=\(payload.extras, privacy: .public)")
        rewardedAd.delegate?.rewardedAdDidLogClick(
            rewardedAd,
            clickAreaName: payload.area.stringValue,
            clickPosition: payload.clickPosition
        )
        actionHelper = actionHelper
            .logNovaClickEvent(
                with: CACurrentMediaTime() - presentStartTime,
                in: payload.area,
                extras: payload.extras.isEmpty ? nil : payload.extras
            )
            .handleAdTap(in: nil, customUrl: payload.url)
    }

    func didTapAdReport() {}

    func didTapAdClose() {
        DebugLogger.ui.info("NovaRewardedAdVC close button tapped, dismissing")
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.rewardedAd.delegate?.rewardedAdDidDismiss(self.rewardedAd)
        }
    }

    func showSKOverlay(appStoreId: Int?) {}

    func didFailToLoadPage(errorType: String, errorDetail: String) {
        DebugLogger.data.error("Rewarded ad HTML page failed to load: errorType=\(errorType, privacy: .public), errorDetail=\(errorDetail, privacy: .public)")
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.rewardedAd.delegate?.rewardedAdDidDismiss(self.rewardedAd)
        }
    }

    func didEarnReward() {
        DebugLogger.ui.info("NovaRewardedAdVC reward earned from JSBridge")
        rewardedAd.delegate?.rewardedAdDidEarnReward(rewardedAd)
    }
}

// Note: WebView process termination is handled via `didFailToLoadPage(errorType:errorDetail:)`.
// `NovaAdHtmlView.webViewWebContentProcessDidTerminate` calls
// `htmlActionDelegate?.didFailToLoadPage(errorType: "Web Content Process Did Terminate", errorDetail: "")`,
// which routes here and dismisses without reward.
