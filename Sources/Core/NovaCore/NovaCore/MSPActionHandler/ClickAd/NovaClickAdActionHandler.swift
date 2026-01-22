//
//  NovaClickAdActionHandler.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/19/24.
//

import AVFoundation
import Foundation
import StoreKit
import UIKit

enum NovaAdLandingPageType: String {
    case safari
    case unified
}

// MARK: - NovaClickAdError

enum NovaClickAdError: LocalizedError {
    case invalidUrl(url: URL, adId: String?)
    case topViewControllerNotFound(adId: String?)
    case missingActionDataModel

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let url, let adId):
            return "Invalid URL: \(url) for adId: \(adId ?? "")"
        case .topViewControllerNotFound(let adId):
            return "Key view controller not found for adId: \(adId ?? "")"
        case .missingActionDataModel:
            return "Action Data model is missing"
        }
    }
}

// MARK: - NovaClickAdActionHandler

final class NovaClickAdActionHandler: NSObject, ActionHandling {
    // MARK: Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil)
    }

    // MARK: Internal

    func supportedActions() -> [String: Any.Type] {
        [
            NovaClickAdActionKey.launchBrowser.rawValue: NovaClickAdActionDataModel.self,
            NovaClickAdActionKey.launchWebView.rawValue: NovaClickAdActionDataModel.self,
            NovaClickAdActionKey.launchStore.rawValue: NovaClickAdActionDataModel.self,
            NovaClickAdActionKey.launchPlayable.rawValue: NovaClickAdActionDataModel.self,
        ]
    }

    func performAction(actionModel: ActionModel, customUrl: URL?) {
        guard let actionKey = NovaClickAdActionKey(rawValue: actionModel.actionKey) else { return }
        guard let actionDataModel = SafeAs(actionModel.actionDataModel, NovaClickAdActionDataModel.self) else {
            return
        }
        guard launchingTask == nil else {
            DebugLogger.ui.info("Action already in progress, ignoring key action: \(actionKey.rawValue)")
            return
        }

        self.actionDataModel = actionDataModel

        launchingTask = Task(priority: .high) {
            switch actionKey {
            case .launchBrowser:
                try await launchBrowser(with: customUrl ?? actionDataModel.ctrType.url)
                launchingTask = nil

            case .launchWebView:
                try await launchWebView(with: customUrl ?? actionDataModel.ctrType.url)
                launchingTask = nil

            case .launchStore:
                try await handleLaunchStoreAction(with: actionDataModel.ctrType)
                launchingTask = nil

            case .launchPlayable:
                try await handleLaunchPlayableAction(with: actionDataModel.ctrType)
                launchingTask = nil
            }
        }

        Task {
            do {
                try await launchingTask?.value
            } catch {
                DebugLogger.ui
                    .error("Failed to perform action: \(actionKey.rawValue) with error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Private

    private static let acceptedSchemes: [String] = ["http", "https", "newsbreak"]
    private var actionDataModel: NovaClickAdActionDataModel?
    private var webType: NovaAdLandingPageType?
    private var launchingTask: Task<Void, Error>?
    private var storeVCIsShowing = false
}

// MARK: - Private methods

@MainActor
private extension NovaClickAdActionHandler {
    func launchBrowser(with url: URL) throws {
        guard urlIsValid(url) else {
            throw NovaClickAdError.invalidUrl(url: url, adId: actionDataModel?.tracingInfo.adId)
        }

        webType = .safari
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func launchWebView(with url: URL) async throws {
        guard urlIsValid(url) else {
            throw NovaClickAdError.invalidUrl(url: url, adId: actionDataModel?.tracingInfo.adId)
        }
        guard let vc = UIApplication.novaTopViewController else {
            assertionFailure("top view controller not found")
            try launchBrowser(with: url)
            return
        }

        try await launchUnified(with: url, from: vc)

        self.webType = .unified
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(handleApplicationWillResignActive(_:)),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        await checkIfAliveAfter5s(webType: webType!)
    }

    func launchUnified(with url: URL, from vc: UIViewController) async throws {
        guard let actionDataModel else {
            assertionFailure("impossible: no click action data model")
            return
        }

        let detentStyle = await getLandingContext(of: actionDataModel)
        let webViewController: NovaAdLandingWebCoordinatorViewController = {
            let context = NovaAdsLandingWebContext(
                url: url,
                tracingInfo: actionDataModel.tracingInfo,
                extraInfo: AdWebExtraInfo(
                    adCtrType: actionDataModel.ctrType,
                    advertiser: actionDataModel.extraInfo.advertiser
                ),
                clickTime: actionDataModel.clickTime
            )
            return NovaAdLandingWebCoordinatorViewController(webContext: context, detentStyle: detentStyle)
        }()
        webViewController.present(from: vc)
    }

    func handleLaunchStoreAction(with ctrType: AdCtrType) async throws {
        if case .appInstall(model: let appInstallModel) = ctrType {
            try await launchStore(with: appInstallModel)
        } else {
            assertionFailure("Using a wrong action key for an ad without app store id")
            try await launchWebView(with: ctrType.url)
        }
    }

    func launchStore(with appInstallModel: AppInstallModel) async throws {
        guard let vc = UIApplication.novaTopViewController else {
            throw NovaClickAdError.topViewControllerNotFound(adId: actionDataModel?.tracingInfo.adId)
        }

        guard !storeVCIsShowing else {
            return
        }

        let storeViewController = SKStoreProductViewController()
        storeViewController.delegate = self
        let parameters = [SKStoreProductParameterITunesItemIdentifier: appInstallModel.storeId]
        do {
            let result = try await storeViewController.loadProduct(withParameters: parameters)
            if result {
                Task.detached(priority: .userInitiated) {
                    try await self.appInstallConversionTracking(to: appInstallModel.fallbackWebModel.url)
                }
                vc.present(storeViewController, animated: true) {
                    self.storeVCIsShowing = true
                }
            } else {
                try await launchWebView(with: appInstallModel.fallbackWebModel.url)
            }
        } catch {
            // skerror meaning https://adapty.io/blog/ios-skerrordomain-error-codes/
            DebugLogger.ui
                .info(
                    "Failed to load app store product with id: \(appInstallModel.storeId), reason: \(error.localizedDescription)"
                )
            try await launchWebView(with: appInstallModel.fallbackWebModel.url)
        }
    }

    func handleLaunchPlayableAction(with ctrType: AdCtrType) async throws {
        if case .playable(model: let playableModel) = ctrType {
            try await launchPlayable(with: playableModel)
        } else {
            assertionFailure("Using a wrong action key for an ad without app store id")
            try await launchWebView(with: ctrType.url)
        }
    }

    func launchPlayable(with playableModel: PlayableModel) async throws {
        guard urlIsValid(playableModel.playableUrl) else {
            throw NovaClickAdError.invalidUrl(url: playableModel.playableUrl, adId: actionDataModel?.tracingInfo.adId)
        }

        switch playableModel.playableArea {
        case .all:
            playableModel.hasBeenPlayed = true
            try presentPlayableVC(with: playableModel)
        case .media:
            switch actionDataModel?.clickPart.area {
            case .media, .tap_to_try, .auto_jump:
                playableModel.hasBeenPlayed = true
                try presentPlayableVC(with: playableModel)
            default:
                switch playableModel.launchAdType {
                case .appInstall(model: let appInstallModel):
                    try await launchStore(with: appInstallModel)
                case .openWeb(model: let openWebModel):
                    try await launchWebView(with: openWebModel.url)
                case .playable(model: let playableModel):
                    assertionFailure("impossible, launch ad type of playable should not be another playable")
                    try await launchWebView(with: playableModel.playableUrl)
                }
            }
        }
    }

    func presentPlayableVC(with playableModel: PlayableModel) throws {
        guard let actionDataModel else {
            throw NovaClickAdError.missingActionDataModel
        }
        guard let topVC = UIApplication.novaTopViewController else {
            throw NovaClickAdError.topViewControllerNotFound(adId: actionDataModel.tracingInfo.adId)
        }

        let appInstallBannerDisplayMode: NovaAdPlayableViewController.Config.AppInstallBannerDisplayMode = {
            if actionDataModel.extraInfo.playableConfig?.actionBarFormat == .bottom {
                return .bottom
            } else {
                return .disable
            }
        }()

        let config = NovaAdPlayableViewController.Config(
            playableConfigs: (
                model: playableModel,
                actionContext: .init(
                    adActionTracingInfo: actionDataModel.tracingInfo,
                    adActionExtraInfo: actionDataModel.extraInfo,
                    viewController: nil
                )
            ),
            advertiser: actionDataModel.extraInfo.advertiser,
            appInstallBannerDisplayMode: appInstallBannerDisplayMode
        )

        let vc = NovaAdPlayableViewController(with: config)

        vc.modalPresentationStyle = .fullScreen
        topVC.present(vc, animated: true)
    }
}

private extension NovaClickAdActionHandler {
    @objc func handleApplicationWillResignActive(_ aNoticiation: Notification) {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil)
        guard let actionDataModel, webType != nil else {
            assertionFailure("Invalid status, missing data model.")
            return
        }

        NovaAdMetricReporter
            .logWebEvent(.novaLandingPageResignActive, encryptedAdToken: actionDataModel.tracingInfo.encryptedAdToken)
        // NovaAdOpenLandingLogger.logResignActive(adId: model.adId,
        // requestId: model.requestId,
        // adUnitId: model.adUnitId,
        // startTime: model.clickTime,
        // webType: webType)
    }

    @MainActor
    func checkIfAliveAfter5s(webType: NovaAdLandingPageType) async {
        Task { [weak self] in
            try? await Task.sleep(seconds: 5.0)  // 5 seconds
            if let actionDataModel = self?.actionDataModel {
                NovaAdMetricReporter
                    .logWebEvent(
                        .novaLandingPageAliveAfter5s,
                        encryptedAdToken: actionDataModel.tracingInfo.encryptedAdToken
                    )
                // NovaAdOpenLandingLogger.logAliveAfter5Seconds(adId: model.adId,
                // requestId: model.requestId,
                // adUnitId: model.adUnitId,
                // startTime: model.clickTime,
                // webType: webType)
            } else {
                NovaAdMetricReporter
                    .logWebEvent(
                        .novaLandingPageRecycledAfter5s,
                        encryptedAdToken: self?.actionDataModel?.tracingInfo.encryptedAdToken ?? ""
                    )
                // NovaAdOpenLandingLogger.logRecycledAfter5Seconds(webType: webType)
            }
        }
    }
}

private extension NovaClickAdActionHandler {
    func urlIsValid(_ url: URL) -> Bool {
        if let scheme = url.scheme, Self.acceptedSchemes.contains(scheme) {
            return true
        } else {
            return false
        }
    }

    func appInstallConversionTracking(to thirdPartyUrl: URL) async throws {
        NovaTrackingUrlHelper.fire(url: thirdPartyUrl)
    }

    @MainActor
    func getLandingPageVideoHeight(of extraInfo: AdActionExtraInfo) async -> Double? {
        guard let videoMediaModel = extraInfo.videoMediaModel,
            videoMediaModel.videoInfo.isPlayOnLandingPage,
            let videoUrl = URL(string: videoMediaModel.videoInfo.videoUrlStr)
        else {
            return nil
        }
        guard let screenWidth = UIApplication.novaCurrentWindowScene?.screen.bounds.width else {
            return nil
        }

        let size = try? await AVURLAsset(url: videoUrl).load(.tracks).first?.load(.naturalSize)

        if let size, size.height >= size.width {
            return screenWidth
        } else {
            return screenWidth / AdsMediaConstants.defaultAspectRatio
        }
    }

    @MainActor
    func getLandingContext(
        of model: NovaClickAdActionDataModel
    ) async -> NovaAdLandingWebCoordinatorViewController.NestedVCDetentStyle {
        if model.clickPart.area == .media,
            let topVideoHeight = await getLandingPageVideoHeight(of: model.extraInfo),
            let landingPageMediaInitialFrame = model.clickPart.inWindowFrame,
            let screenHeight = UIApplication.novaCurrentWindowScene?.screen.bounds.height,
            let videoMediaModel = model.extraInfo.videoMediaModel
        {
            let context = NovaAdLandingWebCoordinatorViewController.LandingVideoContext(
                initialFrame: landingPageMediaInitialFrame,
                videoMediaModel: videoMediaModel,
                actionContext: .init(
                    adActionTracingInfo: model.tracingInfo,
                    adActionExtraInfo: model.extraInfo,
                    viewController: nil
                )
            )
            let vcHeight = screenHeight - UIApplication.novaSafeAreaInsets.top - topVideoHeight
            return .partOfScreen(height: vcHeight, landingVideoContext: context)
        } else {
            return .fullscreen
        }
    }
}

private extension NovaClickAdActionHandler {
    func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }
}

extension NovaClickAdActionHandler: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        Task { @MainActor in
            viewController.dismiss(animated: true) { [weak self] in
                self?.storeVCIsShowing = false
            }
        }
    }
}
