//
//  NovaSKOverlayController.swift
//  NovaCore
//
//  Shared controller for presenting/dismissing SKOverlay. Used by both
//  NovaInterstitialAdPageSubviewHandler (HTML-triggered) and NovaInterstitialAdSKOverlaySubviewHandler.
//  Delegate is passed in init and set on the overlay when calling Apple's API; each handler implements behavior as needed.
//

import Foundation
import StoreKit
import UIKit

/// Presents and dismisses SKOverlay. Does not implement SKOverlayDelegate; the delegate passed in init is set on the overlay when presenting.
final class NovaSKOverlayController {
    private weak var overlayDelegate: (any SKOverlayDelegate)?

    private var overlay: SKOverlay?
    private var skOverlayShowTimestamp: CFTimeInterval?
    private var encryptedAdToken: String
    private weak var currentScene: UIWindowScene?
    private(set) var isShowing: Bool = false

    /// - Parameter overlayDelegate: Set on the overlay when presenting; each subview handler can pass itself to handle callbacks differently.
    init(encryptedAdToken: String, overlayDelegate: (any SKOverlayDelegate)? = nil) {
        self.encryptedAdToken = encryptedAdToken
        self.overlayDelegate = overlayDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        dismiss()
        NotificationCenter.default.removeObserver(self)
    }

    /// Present overlay for the given app store ID. Scene is resolved at show time. Overlay's delegate is the one passed in init.
    /// - Parameter userDismissible: If true, the user can dismiss the overlay by gesture (e.g. when triggered from HTML). If false, only code can dismiss.
    func show(appStoreId: Int, scene: UIWindowScene?, userDismissible: Bool = false) {
        let scene = scene ?? UIApplication.novaCurrentWindowScene
        
        guard let scene, !isShowing else { return }
        currentScene = scene

        let config = SKOverlay.AppConfiguration(
            appIdentifier: "\(appStoreId)",
            position: .bottom
        )
        config.userDismissible = userDismissible
        let overlay = SKOverlay(configuration: config)
        overlay.delegate = overlayDelegate
        overlay.present(in: scene)
        isShowing = true
        self.overlay = overlay
    }

    func dismiss() {
        guard let scene = currentScene else { return }
        SKOverlay.dismiss(in: scene)
        isShowing = false
        overlay = nil
        currentScene = nil
    }
    
    func registerShowTime() {
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
}
