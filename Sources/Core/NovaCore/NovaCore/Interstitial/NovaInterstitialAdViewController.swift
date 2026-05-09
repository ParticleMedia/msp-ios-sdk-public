//
//  NovaInterstitialAdViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

// MARK: - NovaInterstitialAdReportHandling

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit

public struct NovaAdReportContext {
    public let advertiser: String?
    public let headline: String?
    public let body: String?
    public let adId: String
    public let adSetId: String
    public let adRequestId: String
    public let encryptedToken: String
    public let extra: [String: Any]

    public init(
        advertiser: String?,
        headline: String?,
        body: String?,
        adId: String,
        adSetId: String,
        adRequestId: String,
        encryptedToken: String,
        extra: [String: Any] = [:]
    ) {
        self.advertiser = advertiser
        self.headline = headline
        self.body = body
        self.adId = adId
        self.adSetId = adSetId
        self.adRequestId = adRequestId
        self.encryptedToken = encryptedToken
        self.extra = extra
    }
}

extension NovaInterstitialAdItem {
    var novaAdReportContext: NovaAdReportContext {
        .init(
            advertiser: advertiser,
            headline: headline,
            body: body,
            adId: adId,
            adSetId: adSetId,
            adRequestId: requestId,
            encryptedToken: encryptedAdToken
        )
    }
}

/// Report-flow contract used by both interstitial and rewarded full-screen ads.
/// Rewarded ads pass a no-op conformer (PRD does not surface a report button on rewarded);
/// interstitial wires this through to the publisher's report sheet.
public protocol NovaFullScreenAdReportHandling {
    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext)

    // optional methods
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool
}

public extension NovaFullScreenAdReportHandling {
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool { false }
}

/// Backwards-compatible alias for callers that pre-date the rename. New code should use
/// `NovaFullScreenAdReportHandling`.
public typealias NovaInterstitialAdReportHandling = NovaFullScreenAdReportHandling

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
