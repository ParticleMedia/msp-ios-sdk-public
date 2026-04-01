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

public protocol NovaInterstitialAdReportHandling {
    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext)

    // optional methods
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool
}

public extension NovaInterstitialAdReportHandling {
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool { false }
}

// MARK: - NovaInterstitialAdViewController

class NovaInterstitialAdViewController: UIViewController {
    // MARK: Lifecycle

    init(interstitialAd: NovaInterstitialAdItem, reportHandling: (any NovaInterstitialAdReportHandling), orientationMask: UIInterfaceOrientationMask? = nil) {
        self.interstitialAd = interstitialAd
        self.reportHandling = reportHandling
        self.lockedOrientationMask = orientationMask

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }

    // iOS 15-25: system consults this to determine allowed orientations.
    // iOS 26+: still called but orientation lock is handled by prefersInterfaceOrientationLocked.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if case .html = interstitialAd.creativeType, UIDevice.current.userInterfaceIdiom == .pad {
            // Avoid accessing self.view — may trigger premature loadView() before viewDidLoad.
            // lockedOrientationMask is set in init, so the viewIfLoaded fallback rarely executes.
            if let locked = lockedOrientationMask {
                return locked
            }
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
    override var prefersInterfaceOrientationLocked: Bool {
        isOrientationLockActive
    }

    // iOS 15: primary rotation control. iOS 16+: deprecated but still consulted on iOS 15.
    override var shouldAutorotate: Bool {
        if case .html = self.interstitialAd.creativeType {
            // Disable rotation on H5 Ad.
            return false
        } else {
            // Allow rotation on iPad, disable on iPhone
            return UIDevice.current.userInterfaceIdiom == .pad
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = NovaColorPalettes.buttonText
        setupSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if case .html = interstitialAd.creativeType, UIDevice.current.userInterfaceIdiom == .pad,
           lockedOrientationMask == nil {
            lockedOrientationMask = view.window?.windowScene?.interfaceOrientation.orientationMask
            DebugLogger.ui.info("iPad H5 orientation captured in viewWillAppear: \(String(describing: self.lockedOrientationMask), privacy: .public)")
        }

        adView?.willAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        adView?.didAppear()

        if !didAppear {
            didAppear = true

            // Enhanced impression logging from NewsBreak
            NovaAdMetricReporter
                .logAdImpression(
                    thirdPartyImpressionTrackingUrls: interstitialAd.thirdPartyImpressionTrackingUrls,
                    encryptedAdToken: interstitialAd.encryptedAdToken,
                    adUnitId: interstitialAd.adUnitId
                )

            // Enhanced tracing from NewsBreak (simplified for NovaCore)
            if let tracingID = interstitialAd.adOpportunityID {
                // TODO: Implement tracing functionality when needed
                print("Tracing impression for ID: \(tracingID)")
            }

            interstitialAd.delegate?.interstitialAdDidDisplay(interstitialAd)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        activateOrientationLock()
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        deactivateOrientationLock()

        adView?.willDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // End playing - protocol method handles the specifics
        adView?.didDisappear()

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if case .html = interstitialAd.creativeType, UIDevice.current.userInterfaceIdiom == .pad {
            DebugLogger.ui.info("iPad H5 rotation detected (\(size.width, privacy: .public)x\(size.height, privacy: .public)), re-locking orientation")
            activateOrientationLock()
        }

        // TODO: lsy, check out if this logic works
        guard self.adView as? NovaInterstitialAdNormalView != nil,
              UIDevice.current.userInterfaceIdiom == .pad
        else {
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.adView?.setNeedsLayout()
            self?.adView?.layoutIfNeeded()
        })
    }

    // MARK: - Orientation Lock (version-branching encapsulated here)

    private func activateOrientationLock() {
        guard case .html = interstitialAd.creativeType,
              UIDevice.current.userInterfaceIdiom == .pad else { return }

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
        // iOS 15: shouldAutorotate + supportedInterfaceOrientations handle locking automatically.
    }

    private func deactivateOrientationLock() {
        guard case .html = interstitialAd.creativeType,
              UIDevice.current.userInterfaceIdiom == .pad else { return }

        if #available(iOS 26.0, *) {
            isOrientationLockActive = false
            setNeedsUpdateOfPrefersInterfaceOrientationLocked()
            DebugLogger.ui.info("iPad H5 orientation unlocked (iOS 26+)")
        } else if #available(iOS 16.0, *) {
            DebugLogger.ui.info("iPad H5 orientation unlocked, restoring .all")
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        // iOS 15: no explicit unlock needed — shouldAutorotate/supportedInterfaceOrientations
        // are tied to this VC's lifecycle and stop applying once the VC is dismissed.
    }

    /// Logs a warning once if the host app has not set `UIRequiresFullScreen = YES` in its Info.plist.
    /// Without this setting, iPad orientation locking via `requestGeometryUpdate` is silently ignored by the system.
    private func warnIfFullScreenNotRequired() {
        guard !Self.didWarnFullScreen else { return }
        let requiresFullScreen = Bundle.main.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool ?? false
        if !requiresFullScreen {
            Self.didWarnFullScreen = true
            DebugLogger.ui.warning("UIRequiresFullScreen is not set to YES in the host app's Info.plist. iPad H5 ad orientation locking will not work without this setting.")
        }
    }

    private static var didWarnFullScreen = false

    @objc func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        if (interstitialAd.shouldAutoDismiss) {
            dismiss(animated: false) {
                self.interstitialAd.delegate?.interstitialAdDidDismiss(self.interstitialAd)
            }
        }
    }
    
    @objc func handleApplicationWillResignActive(_ aNoticiation: Notification) {
        self.adView?.didDisappear()
    }
     
    @objc func handleApplicationDidBecomeActive(_ aNoticiation: Notification) {
        self.adView?.willAppear()
    }

    // MARK: Private

    private let interstitialAd: NovaInterstitialAdItem
    private let reportHandling: any NovaInterstitialAdReportHandling
    private var didAppear: Bool = false
    /// Orientation captured in viewWillAppear; used to lock iPad H5 ads to presentation orientation.
    private var lockedOrientationMask: UIInterfaceOrientationMask?

    /// Whether orientation should be locked (iPadOS 26+ API).
    private var isOrientationLockActive: Bool = false

    private var adView: NovaInterstitialAdViewProtocol?

    override var prefersStatusBarHidden: Bool {
        if case .html = self.interstitialAd.creativeType {
            return true
        }
        return false
    }
}

// MARK: - Private Extension

private extension NovaInterstitialAdViewController {
    private func setupSubviews() {
        let adView = NovaInterstitialAdViewFactory.createAdView(
            interstitialAd: interstitialAd,
            viewController: self,
            reportHandling: reportHandling
        )

        // Add the view to the view hierarchy
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.adView = adView
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
