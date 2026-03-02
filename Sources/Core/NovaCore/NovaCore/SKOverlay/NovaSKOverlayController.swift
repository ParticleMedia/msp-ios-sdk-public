//
//  NovaSKOverlayController.swift
//  NovaCore
//
//  Shared controller for presenting/dismissing SKOverlay.
//

import Foundation
import StoreKit
import UIKit

public final class NovaSKOverlayController: NSObject {
    private weak var forwardedOverlayDelegate: (any SKOverlayDelegate)?

    private var overlay: SKOverlay?
    private var skOverlayShowTimestamp: CFTimeInterval?
    private let encryptedAdToken: String
    private let thirdPartyTrackingURL: URL?
    private let monitorAppStoreLifecycle: Bool
    private let requiredTopViewControllerType: UIViewController.Type?
    private var appStoreObservers: [NSObjectProtocol] = []
    private var shouldRestoreAfterAppStoreReturn = false
    private var lastShowContext: (appStoreId: Int, position: SKOverlay.Position, userDismissible: Bool)?
    private var hasTrackedThirdParty = false
    private weak var currentScene: UIWindowScene?
    private weak var lastResolvedScene: UIWindowScene?
    public private(set) var isShowing: Bool = false

    /// - Parameter overlayDelegate: Set on the overlay when presenting; each subview handler can pass itself to handle callbacks differently.
    public init(
        encryptedAdToken: String,
        overlayDelegate: (any SKOverlayDelegate)? = nil,
        thirdPartyTrackingURL: URL? = nil,
        monitorAppStoreLifecycle: Bool = true,
        requiredTopViewControllerType: UIViewController.Type? = nil
    ) {
        self.forwardedOverlayDelegate = overlayDelegate
        self.encryptedAdToken = encryptedAdToken
        self.thirdPartyTrackingURL = thirdPartyTrackingURL
        self.monitorAppStoreLifecycle = monitorAppStoreLifecycle
        self.requiredTopViewControllerType = requiredTopViewControllerType
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        if monitorAppStoreLifecycle {
            let willOpenObserver = NotificationCenter.default.addObserver(
                forName: .adClickedWillOpenAppStore,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.adClickedWillOpenAppStore()
            }
            let didReturnObserver = NotificationCenter.default.addObserver(
                forName: .adClickedDidReturnFromAppStore,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.adClickedDidReturnFromAppStore()
            }
            appStoreObservers = [willOpenObserver, didReturnObserver]
        }
    }

    public func setOverlayDelegate(_ overlayDelegate: (any SKOverlayDelegate)?) {
        forwardedOverlayDelegate = overlayDelegate
    }

    deinit {
        dismiss()
        appStoreObservers.forEach { NotificationCenter.default.removeObserver($0) }
        NotificationCenter.default.removeObserver(self)
    }

    /// Present overlay for the given app store ID. Scene is resolved at show time. Overlay's delegate is the one passed in init.
    /// - Parameter userDismissible: If true, the user can dismiss the overlay by gesture (e.g. when triggered from HTML). If false, only code can dismiss.
    public func show(
        appStoreId: Int,
        scene: UIWindowScene?,
        position: SKOverlay.Position = .bottom,
        userDismissible: Bool = false
    ) {
        let scene = scene ?? UIApplication.novaCurrentWindowScene

        guard let scene, !isShowing else { return }
        currentScene = scene
        lastResolvedScene = scene
        lastShowContext = (appStoreId: appStoreId, position: position, userDismissible: userDismissible)
        shouldRestoreAfterAppStoreReturn = false

        let config = SKOverlay.AppConfiguration(
            appIdentifier: "\(appStoreId)",
            position: position
        )
        config.userDismissible = userDismissible
        let overlay = SKOverlay(configuration: config)
        overlay.delegate = self
        overlay.present(in: scene)
        isShowing = true
        self.overlay = overlay
    }

    public func dismiss() {
        guard let scene = currentScene else { return }
        SKOverlay.dismiss(in: scene)
        isShowing = false
        overlay = nil
        currentScene = nil
    }

    public func registerShowTime() {
        if skOverlayShowTimestamp == nil {
            skOverlayShowTimestamp = CACurrentMediaTime()
        }
    }

    @objc func appDidEnterBackground() {
        guard isShowing else { return }
        var durationInMs: Int?
        if let skOverlayShowTimestamp {
            let duration = CACurrentMediaTime() - skOverlayShowTimestamp
            if duration.isFinite, !duration.isNaN, let durationValue = (duration * 1000).safeToInt() {
                durationInMs = durationValue
            }
        }
        NovaAdMetricReporter.logDownloadBannerJumpOut(
            encryptedAdToken: encryptedAdToken,
            durationInMs: durationInMs
        )
    }

    private func adClickedWillOpenAppStore() {
        guard monitorAppStoreLifecycle, isShowing else { return }
        shouldRestoreAfterAppStoreReturn = true
        dismiss()
    }

    private func adClickedDidReturnFromAppStore() {
        guard monitorAppStoreLifecycle, shouldRestoreAfterAppStoreReturn, !isShowing, let lastShowContext else {
            return
        }
        shouldRestoreAfterAppStoreReturn = false
        show(
            appStoreId: lastShowContext.appStoreId,
            scene: lastResolvedScene ?? UIApplication.novaCurrentWindowScene,
            position: lastShowContext.position,
            userDismissible: lastShowContext.userDismissible
        )
    }
}

extension NovaSKOverlayController: SKOverlayDelegate {
    public func storeOverlayDidFailToLoad(_ overlay: SKOverlay, error: any Error) {
        DebugLogger.network.error("Failed to load SKOverlay: \(error.localizedDescription)")
        forwardedOverlayDelegate?.storeOverlayDidFailToLoad?(overlay, error: error)
    }

    public func storeOverlayWillStartPresentation(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext)
    {
        forwardedOverlayDelegate?.storeOverlayWillStartPresentation?(overlay, transitionContext: transitionContext)
    }

    public func storeOverlayDidFinishPresentation(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext)
    {
        registerShowTime()
        if !hasTrackedThirdParty, let thirdPartyTrackingURL {
            hasTrackedThirdParty = true
            NovaTrackingUrlHelper.fire(url: thirdPartyTrackingURL)
        }
        if let requiredTopViewControllerType {
            let topVC = UIApplication.novaTopViewController
            if topVC?.isKind(of: requiredTopViewControllerType) != true {
                dismiss()
            }
        }
        DebugLogger.network.info("SKOverlay did show successfully")
        forwardedOverlayDelegate?.storeOverlayDidFinishPresentation?(overlay, transitionContext: transitionContext)
    }

    public func storeOverlayWillStartDismissal(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        forwardedOverlayDelegate?.storeOverlayWillStartDismissal?(overlay, transitionContext: transitionContext)
    }

    public func storeOverlayDidFinishDismissal(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        forwardedOverlayDelegate?.storeOverlayDidFinishDismissal?(overlay, transitionContext: transitionContext)
    }
}
