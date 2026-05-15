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

    /// Exactly-once guard for the Nova `AD_EVENT_REWARDED` event (spec FR-023).
    /// Set only after `NovaAdMetricReporter.logAdRewarded` successfully enqueues the
    /// URL — if URL construction fails, the flag stays `false` so the next H5
    /// `onAdRewarded()` invocation can retry. Strictly main-thread, no atomicity
    /// concerns. Independent of `RewardedLifecycleController`'s reward-callback
    /// dedup, which lives in MSPiOSCore and cannot reach `NovaAdMetricReporter`.
    private var hasFiredRewardedEvent = false

    /// Set as soon as a dismiss-trigger path runs (close-button tap, HTML load
    /// failure, WebView process termination). Used to gate the Nova
    /// `AD_EVENT_REWARDED` event so a late H5 `onAdRewarded()` arriving during
    /// the dismiss animation, or after it, is dropped — mirrors
    /// `RewardedLifecycleController`'s `hasDismissed` guard, which already
    /// drops the publisher reward callback in the same race.
    /// Without this, the VC would still emit the Nova event because dispatch
    /// happens *before* the delegate forward to the lifecycle controller.
    private var isDismissing = false

    /// Exactly-once guard for Nova `AD_EVENT_CLOSE`. Multiple dismiss-trigger paths can
    /// race (for example, close button followed by WebView process termination), but Nova
    /// should receive one close event per rewarded presentation.
    private var hasFiredCloseEvent = false

    // MARK: - Overrides

    override func setupAdView() {
        guard case let .html(model) = rewardedAd.mediaContent.adMedia else {
            DebugLogger.data.error("NovaRewardedAdVC setupAdView: ad media is not .html, cannot display. adUnitId=\(self.rewardedAd.adUnitId, privacy: .public)")
            return
        }
        let htmlView: NovaAdHtmlView
        if let cached = rewardedAd.cachedHtmlView {
            htmlView = cached
            DebugLogger.ui.info("NovaRewardedAdVC setupAdView: using preloaded WebView, adUnitId=\(self.rewardedAd.adUnitId, privacy: .public)")
            // Match interstitial's `NovaInterstitialAdPageSubviewHandler.ensureHtmlView` —
            // cachedHtmlView is a "consume after taking" cache. Clear it so the ad item
            // does not keep a strong reference to the live WKWebView for its lifetime, and
            // so a subsequent `show()` rebuilds the WebView instead of reusing a stale one.
            rewardedAd.cachedHtmlView = nil
        } else {
            DebugLogger.ui.info("NovaRewardedAdVC setupAdView: building fresh WebView (no preload), adUnitId=\(self.rewardedAd.adUnitId, privacy: .public)")
            // Fresh (non-preload) path: defer the feedback-icon decision to the
            // publisher-provided report handler, mirroring `NovaInterstitialAdPageSubviewHandler`.
            // Preload path is unaffected — its WebView is built earlier from
            // the `html_enable_feedback` server flag.
            let supportReportHandling = reportHandling.novaCanShowReportButton(
                with: rewardedAd.novaAdReportContext
            )
            htmlView = NovaAdHtmlView(supportReportHandling: supportReportHandling)
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

    func didTapAdReport() {
        dispatchPrecondition(condition: .onQueue(.main))
        DebugLogger.ui.info("NovaRewardedAdVC didTapAdReport — forwarding to report handler")
        reportHandling.novaStartReportFlow(
            from: self,
            context: rewardedAd.novaAdReportContext
        )
    }

    func didTapAdClose() {
        // Symmetric with `didEarnReward`'s guard: `isDismissing` is a non-atomic Bool
        // read in `didEarnReward`. Both dismiss-trigger paths currently fire on the
        // main thread (WKScriptMessageHandler / WKNavigationDelegate), but the guard
        // makes the threading contract explicit and surfaces any future caller that
        // breaks it.
        dispatchPrecondition(condition: .onQueue(.main))
        DebugLogger.ui.info("NovaRewardedAdVC close button tapped; logging AD_EVENT_CLOSE and dismissing")
        logCloseEvent(reason: .skipButton, error: nil, source: "close_button")
        isDismissing = true
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            DebugLogger.ui.info("NovaRewardedAdVC close dismiss completed; notifying rewarded delegate")
            self.rewardedAd.delegate?.rewardedAdDidDismiss(self.rewardedAd)
        }
    }

    func showSKOverlay(appStoreId: Int?) {}

    func didFailToLoadPage(errorType: String, errorDetail: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        DebugLogger.data.error("Rewarded ad HTML page failed to load: errorType=\(errorType, privacy: .public), errorDetail=\(errorDetail, privacy: .public)")
        let isActive = (UIApplication.shared.applicationState == .active
            && view.onTop
            && view.novaIsPartiallyVisibleOnScreen) ? 1 : 0
        let concatErrorMessage = "error:\(isActive):\(errorType):\(errorDetail)"
        let closeErrorReason = NovaAdLoadError(
            isActive: isActive,
            errorType: errorType,
            errorDetail: errorDetail
        )
        logCloseEvent(
            reason: .error(concatErrorMessage),
            error: closeErrorReason,
            source: "html_load_failure"
        )
        isDismissing = true
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            DebugLogger.ui.info("NovaRewardedAdVC failure dismiss completed; notifying rewarded delegate")
            self.rewardedAd.delegate?.rewardedAdDidDismiss(self.rewardedAd)
        }
    }

    func didEarnReward() {
        dispatchPrecondition(condition: .onQueue(.main))
        DebugLogger.ui.info("NovaRewardedAdVC didEarnReward from JSBridge, isDismissing=\(self.isDismissing, privacy: .public), hasFiredRewardedEvent=\(self.hasFiredRewardedEvent, privacy: .public)")

        // Nova `AD_EVENT_REWARDED` is the sole server-side reward event (FR-023).
        // It must fire exactly once per ad regardless of how many times H5 triggers
        // `novaNativeBridge.onAdRewarded()`. The publisher callback is separately
        // deduped by RewardedLifecycleController.markRewardEarned() and reached via
        // the delegate forward below.
        if isDismissing {
            // Late H5 `onAdRewarded` arrived during or after the dismiss animation.
            // Mirror the lifecycle controller's `hasDismissed` drop policy: discard
            // the Nova event too, so the two channels stay symmetric. We still call
            // the delegate so the lifecycle controller's own log surfaces this race.
            DebugLogger.ui.info("NovaRewardedAdVC late onAdRewarded after dismiss initiated; dropping AD_EVENT_REWARDED to match publisher-callback dedup")
        } else if hasFiredRewardedEvent {
            DebugLogger.ui.info("NovaRewardedAdVC duplicate onAdRewarded; AD_EVENT_REWARDED already fired, skipping Nova event")
        } else {
            let durationInMs = Int((CACurrentMediaTime() - presentStartTime) * 1000)
            let didEnqueue = NovaAdMetricReporter.logAdRewarded(
                encryptedAdToken: rewardedAd.encryptedAdToken,
                adUnitId: rewardedAd.adUnitId,
                durationInMs: durationInMs
            )
            if didEnqueue {
                hasFiredRewardedEvent = true
                DebugLogger.ui.info("NovaRewardedAdVC enqueued AD_EVENT_REWARDED, durationMs=\(durationInMs, privacy: .public), adUnitId=\(self.rewardedAd.adUnitId, privacy: .public)")
            } else {
                // URL build failed inside logAdRewarded; leave flag unset so the next H5
                // trigger (if any) can retry. Loud error so production telemetry surfaces it.
                DebugLogger.data.error("NovaRewardedAdVC failed to enqueue AD_EVENT_REWARDED (URL build failed); will retry on next onAdRewarded() if H5 retriggers. adUnitId=\(self.rewardedAd.adUnitId, privacy: .public)")
            }
        }

        rewardedAd.delegate?.rewardedAdDidEarnReward(rewardedAd)
    }
}

private extension NovaRewardedAdViewController {
    func logCloseEvent(reason: NovaAdSkipReason, error: NovaAdLoadError?, source: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !hasFiredCloseEvent else {
            DebugLogger.ui.info("NovaRewardedAdVC skipping duplicate AD_EVENT_CLOSE, source=\(source, privacy: .public)")
            return
        }

        let durationInMs = ((CACurrentMediaTime() - presentStartTime) * 1000).safeToInt()
        DebugLogger.ui.info("NovaRewardedAdVC enqueue AD_EVENT_CLOSE, source=\(source, privacy: .public), reason=\(reason.stringValue, privacy: .public), durationMs=\(String(describing: durationInMs), privacy: .public)")
        let didEnqueue = NovaAdMetricReporter.logAdClose(
            reason: reason,
            encryptedAdToken: rewardedAd.encryptedAdToken,
            durationInMs: durationInMs,
            error: error
        )
        if didEnqueue {
            hasFiredCloseEvent = true
            DebugLogger.ui.info("NovaRewardedAdVC enqueued AD_EVENT_CLOSE, source=\(source, privacy: .public)")
        } else {
            DebugLogger.data.error("NovaRewardedAdVC failed to enqueue AD_EVENT_CLOSE; will retry on next close path if any. source=\(source, privacy: .public)")
        }
    }
}

// Note: WebView process termination is handled via `didFailToLoadPage(errorType:errorDetail:)`.
// `NovaAdHtmlView.webViewWebContentProcessDidTerminate` calls
// `htmlActionDelegate?.didFailToLoadPage(errorType: "Web Content Process Did Terminate", errorDetail: "")`,
// which routes here and dismisses without reward.
