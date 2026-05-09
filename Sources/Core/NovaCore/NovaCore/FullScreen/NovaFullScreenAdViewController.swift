//
//  NovaFullScreenAdViewController.swift
//  NovaCore
//

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit

/// Base view controller for full-screen Nova ads (interstitial and rewarded).
/// Handles common behavior: orientation locking, impression logging, ad view lifecycle.
/// Subclasses override `setupAdView()` to supply the concrete ad view,
/// and may override `handleApplicationWillEnterForeground(_:)` to control dismiss-on-foreground policy.
class NovaFullScreenAdViewController: UIViewController {

    // MARK: - Init

    init(adItem: NovaFullScreenAdItem, orientationMask: UIInterfaceOrientationMask? = nil) {
        self.adItem = adItem
        self.lockedOrientationMask = orientationMask
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Internal

    /// The ad item being displayed.
    let adItem: NovaFullScreenAdItem

    /// The displayed ad view (set by subclass in `setupAdView()`).
    var adView: NovaInterstitialAdViewProtocol?

    /// Whether the ad has appeared at least once (used to guard one-time impression logging).
    /// `internal private(set)` so the interstitial subclass can read it for its
    /// auto-dismiss eligibility check (mirrors develop PR #725).
    private(set) var didAppear: Bool = false

    /// Orientation captured at presentation time; used to lock iPad H5 ads.
    var lockedOrientationMask: UIInterfaceOrientationMask?

    /// Whether orientation lock is currently active (iPadOS 26+ API).
    private var isOrientationLockActive: Bool = false

    // MARK: - Status Bar / Orientation

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override var prefersStatusBarHidden: Bool {
        if case .html = adItem.creativeType { return true }
        return false
    }

    // iOS 15–25: system consults this to determine allowed orientations.
    // iOS 26+: still called but orientation lock is handled by prefersInterfaceOrientationLocked.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if case .html = adItem.creativeType, UIDevice.current.userInterfaceIdiom == .pad {
            if let locked = lockedOrientationMask { return locked }
            return viewIfLoaded?.window?.windowScene?.interfaceOrientation.orientationMask ?? .portrait
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
        }
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.interfaceOrientation.orientationMask ?? .portrait
    }

    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool { isOrientationLockActive }

    // iOS 15: primary rotation control.
    override var shouldAutorotate: Bool {
        if case .html = adItem.creativeType { return false }
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        DebugLogger.ui.info("[FullScreenAd] viewDidLoad — registering observers")
        view.backgroundColor = NovaColorPalettes.buttonText
        setupAdView()
        // Per develop PR #657, register the foreground / background observers once
        // in viewDidLoad rather than every viewDidAppear. The previous viewDidAppear
        // pattern would re-register on each re-appearance and could pile up duplicates.
        setupNotificationObservers()
    }

    deinit {
        DebugLogger.ui.info("[FullScreenAd] deinit — removing observers")
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if case .html = adItem.creativeType, UIDevice.current.userInterfaceIdiom == .pad,
           lockedOrientationMask == nil {
            lockedOrientationMask = view.window?.windowScene?.interfaceOrientation.orientationMask
            DebugLogger.ui.info("iPad H5 orientation captured in viewWillAppear: \(String(describing: self.lockedOrientationMask), privacy: .public)")
        }
        adView?.willAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Match develop's ordering: flip isVisible first so any willResignActive that
        // races viewDidAppear sees the new state.
        isVisible = true
        DebugLogger.ui.info("[FullScreenAd] viewDidAppear — isVisible=true")
        adView?.didAppear()

        if !didAppear {
            didAppear = true
            NovaAdMetricReporter.logAdImpression(
                thirdPartyImpressionTrackingUrls: adItem.thirdPartyImpressionTrackingUrls,
                encryptedAdToken: adItem.encryptedAdToken,
                adUnitId: adItem.adUnitId
            )
            didLogImpression()
        }

        activateOrientationLock()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Match develop: flip isVisible in willDisappear, not didDisappear, so any
        // willResignActive that fires between will/did doesn't redundantly call
        // adView.didDisappear() while the view is already on its way out.
        isVisible = false
        DebugLogger.ui.info("[FullScreenAd] viewWillDisappear — isVisible=false")
        deactivateOrientationLock()
        adView?.willDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        adView?.didDisappear()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if case .html = adItem.creativeType, UIDevice.current.userInterfaceIdiom == .pad {
            DebugLogger.ui.info("iPad H5 rotation detected (\(size.width, privacy: .public)x\(size.height, privacy: .public)), re-locking orientation")
            activateOrientationLock()
        }
        guard self.adView as? NovaInterstitialAdNormalView != nil,
              UIDevice.current.userInterfaceIdiom == .pad else { return }
        coordinator.animate(alongsideTransition: { [weak self] _ in
            // Reset constraints and aspect ratios in subview handlers (e.g. horizontal
            // mediaView height) before laying out. Pre-refactor this call lived in
            // NovaInterstitialAdViewController.viewWillTransition; without it the
            // iPad horizontal interstitial keeps its pre-rotation media area.
            self?.adView?.willTransit()
            self?.adView?.setNeedsLayout()
            self?.adView?.layoutIfNeeded()
        })
    }

    // MARK: - Subclass Hooks

    /// Called once on first `viewDidAppear`. Subclasses fire their format-specific delegate callback here.
    func didLogImpression() {}

    /// Called to set up the ad content view. Subclasses must override this to add their ad view.
    func setupAdView() {}

    /// Called when the app enters the foreground. Subclasses override to control dismiss-on-foreground policy.
    /// Rewarded ads should NOT dismiss — they override this as a no-op.
    @objc func handleApplicationWillEnterForeground(_ notification: Notification) {}

    @objc func handleApplicationWillResignActive(_ notification: Notification) {
        guard isVisible else {
            DebugLogger.ui.info("[FullScreenAd] willResignActive ignored — isVisible=false")
            return
        }
        DebugLogger.ui.info("[FullScreenAd] willResignActive — pausing ad")
        adView?.didDisappear()
    }

    /// Called when the app becomes active. Default behavior resumes ad playback when visible.
    /// Interstitial subclass overrides to also flush a pending auto-dismiss request that was
    /// staged in `willEnterForeground` — UIKit isn't fully active until this notification, so
    /// dismiss must wait for it (develop PR #725).
    @objc func handleApplicationDidBecomeActive(_ notification: Notification) {
        guard isVisible else {
            DebugLogger.ui.info("[FullScreenAd] didBecomeActive ignored — isVisible=false, no pending dismiss")
            return
        }
        DebugLogger.ui.info("[FullScreenAd] didBecomeActive — resuming ad")
        adView?.willAppear()
    }

    private var isVisible = false

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Orientation Lock

    private func activateOrientationLock() {
        guard case .html = adItem.creativeType, UIDevice.current.userInterfaceIdiom == .pad else { return }
        if #available(iOS 26.0, *) {
            isOrientationLockActive = true
            setNeedsUpdateOfPrefersInterfaceOrientationLocked()
            DebugLogger.ui.info("iPad H5 orientation locked via prefersInterfaceOrientationLocked (iOS 26+)")
        } else if #available(iOS 16.0, *) {
            warnIfFullScreenNotRequired()
            let target = lockedOrientationMask ?? .portrait
            DebugLogger.ui.info("iPad H5 requesting geometry lock to \(target.rawValue, privacy: .public) (iOS 16-25)")
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: target))
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func deactivateOrientationLock() {
        guard case .html = adItem.creativeType, UIDevice.current.userInterfaceIdiom == .pad else { return }
        if #available(iOS 26.0, *) {
            isOrientationLockActive = false
            setNeedsUpdateOfPrefersInterfaceOrientationLocked()
            DebugLogger.ui.info("iPad H5 orientation unlocked (iOS 26+)")
        } else if #available(iOS 16.0, *) {
            DebugLogger.ui.info("iPad H5 orientation unlocked, restoring .all")
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func warnIfFullScreenNotRequired() {
        guard !Self.didWarnFullScreen else { return }
        let requiresFullScreen = Bundle.main.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool ?? false
        if !requiresFullScreen {
            Self.didWarnFullScreen = true
            DebugLogger.ui.warning("UIRequiresFullScreen is not set to YES in the host app's Info.plist. iPad H5 ad orientation locking will not work without this setting.")
        }
    }

    private static var didWarnFullScreen = false
}
