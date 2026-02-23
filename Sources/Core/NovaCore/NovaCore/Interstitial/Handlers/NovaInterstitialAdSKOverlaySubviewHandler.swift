//
//  NovaInterstitialAdSKOverlaySubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/8/08.
//

import Foundation
@_implementationOnly import MSPSnapKit
import StoreKit
import UIKit

class NovaInterstitialAdSKOverlaySubviewHandler: NSObject, NovaInterstitialAdSubviewHandler {
    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?
    private let appStoreId: Int
    private let thirdPartyTrackingURL: URL
    private lazy var skOverlayController = NovaSKOverlayController(encryptedAdToken: interstitialAd.encryptedAdToken, overlayDelegate: self)
    private var skOverlayShowTimestamp: CFTimeInterval?
    private var skOverlayNeedToBeShown: Bool = false
    private var adClickedWillOpenAppStoreObserver: NSObjectProtocol?
    private var adClickedDidReturnFromAppStoreObserver: NSObjectProtocol?

    private lazy var topGradientView: GradientShadowView = {
        let config = GradientShadowViewConfig(
            colors: (
                UIColor.black.withAlphaComponent(0.4),
                UIColor.clear
            ),
            points: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.0))
        )
        return GradientShadowView(with: config)
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage.Nova.crossCircleFilled?.withTintColor(
            NovaColorPalettes.White, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        button.accessibilityIdentifier = "close"
        return button
    }()

    private lazy var volumeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.background.backgroundInsets = NSDirectionalEdgeInsets(
            top: 4.0,
            leading: 4.0,
            bottom: 4.0,
            trailing: 4.0
        )
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(didTapVolumeButton), for: .touchUpInside)
        return button
    }()

    private lazy var adTagLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.text = "SPONSORED"
        label.textColor = NovaColorPalettes.White
        label.backgroundColor = NovaColorPalettes.White.withAlphaComponent(0.2)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 2.0
        label.layer.masksToBounds = true
        label.textInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

        return label
    }()

    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.adClickArea = .media
        return view
    }()

    private lazy var bottomShadow: GradientShadowView = {
        let config = GradientShadowViewConfig(
            colors: (
                UIColor.clear,
                UIColor.black.withAlphaComponent(0.85)
            ),
            points: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.0))
        )
        let view = GradientShadowView(with: config)
        view.adClickArea = .badge
        return view
    }()

    private lazy var bottomContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [volumeButton, adTagLabel])
        volumeButton.snp.makeConstraints { make in
            make.height.width.equalTo(Constants.volumeButtonSize)
        }
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8.0
        return stackView
    }()

    init(
        interstitialAd: NovaInterstitialAdItem,
        delegate: NovaInterstitialAdSubviewBehaviorDelegate,
        viewController: UIViewController?,
        appStoreId: Int,
        thirdPartyTrackingURL: URL
    ) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
        self.appStoreId = appStoreId
        self.thirdPartyTrackingURL = thirdPartyTrackingURL
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        adClickedWillOpenAppStoreObserver = NotificationCenter.default
            .addObserver(
                forName: .adClickedWillOpenAppStore,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.adClickedWillOpenAppStore()
            }

        adClickedDidReturnFromAppStoreObserver = NotificationCenter.default
            .addObserver(
                forName: .adClickedDidReturnFromAppStore,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.adClickedDidReturnFromAppStore()
            }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let adClickedWillOpenAppStoreObserver {
            NotificationCenter.default.removeObserver(adClickedWillOpenAppStoreObserver)
        }
        if let adClickedDidReturnFromAppStoreObserver {
            NotificationCenter.default.removeObserver(adClickedDidReturnFromAppStoreObserver)
        }
    }

    func setupSubviews(in containerView: UIView, showReportButton: Bool) {
        containerView.addSubview(mediaView)
        containerView.addSubview(topGradientView)
        containerView.addSubview(closeButton)
        containerView.addSubview(bottomShadow)
        containerView.addSubview(bottomContainerView)

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        topGradientView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(166.0)
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide).offset(Constants.subviewPadding)
            make.trailing.equalToSuperview().offset(-Constants.subviewPadding)
            make.height.width.equalTo(Constants.closeButtonSize)
        }

        bottomShadow.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            let screenWidth = UIScreen.main.bounds.width
            make.height.equalTo(screenWidth * 280 / 375)
        }

        bottomContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.subviewPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(Constants.subviewPadding)
            make.bottom.equalToSuperview().inset(Constants.progressBarBottomMargin + 8.0)
        }
    }

    func config() {
        // Configure media view
        interstitialAd.mediaContent.videoController?.style = .playButtonOnCenter(
            progressBarStyle: .hide, popupCTAStyle: .show())
        mediaView.config(
            with: interstitialAd.mediaContent,
            actionContext: .init(
                adActionTracingInfo: interstitialAd.actionTracingInfo,
                adActionExtraInfo: interstitialAd.actionExtraInfo,
                viewController: nil
            )
        )

        // Show/hide volume button based on media type
        if case .video = interstitialAd.mediaContent.adMedia {
            volumeButton.isHidden = false
            setupVolumeIcon(muted: interstitialAd.mediaContent.videoController?.muted ?? true)
        } else {
            volumeButton.isHidden = true
        }
    }

    var clickableViews: [UIView] {
        getClickableViewsFromConfiguration() ?? [bottomShadow, adTagLabel]
    }

    func willAppear() {
        interstitialAd.mediaContent.videoController?.play()
    }

    func didAppear() {
        showSkOverlay()
    }

    func didDisappear() {
        interstitialAd.mediaContent.videoController?.pause()
        skOverlayNeedToBeShown = false
        dismissSkOverlay()
    }

    func willDisappear() {
        skOverlayNeedToBeShown = false
        dismissSkOverlay()
    }

    // MARK: Private

    private enum Constants {
        static let closeButtonSize: Double = 32.0
        static let volumeButtonSize: Double = 32.0
        static let subviewPadding: Double = 17.0
        static let progressBarBottomMargin = 22.0 + 34.0  // UIDevice.bottomRoundAreaHeight equivalent
    }

    private func setupVolumeIcon(muted: Bool) {
        let volumeOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White)
        let volumeOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White)
        volumeButton.setImage(muted ? volumeOffImage : volumeOnImage, for: .normal)
    }

    private func showSkOverlay() {
        let scene = viewController?.view.window?.windowScene
        skOverlayController.show(appStoreId: appStoreId, scene: scene)
    }

    private func dismissSkOverlay() {
        skOverlayController.dismiss()
        skOverlayShowTimestamp = nil
    }

    @objc private func appDidEnterBackground() {
        guard skOverlayController.isShowing else { return }
        var durationInMs: Int?
        if let skOverlayShowTimestamp {
            let duration = CACurrentMediaTime() - skOverlayShowTimestamp
            if duration.isFinite, !duration.isNaN, let durationValue = (duration * 1000).safeToInt() {
                durationInMs = durationValue
            }
        }
        NovaAdMetricReporter.logDownloadBannerJumpOut(
            encryptedAdToken: interstitialAd.encryptedAdToken,
            durationInMs: durationInMs
        )
    }

    private func adClickedWillOpenAppStore() {
        guard skOverlayController.isShowing else {
            return
        }
        skOverlayNeedToBeShown = true
        dismissSkOverlay()
    }

    private func adClickedDidReturnFromAppStore() {
        guard skOverlayNeedToBeShown else {
            return
        }
        skOverlayNeedToBeShown = false

        // Only restore overlay when the interstitial is still on top.
        guard UIApplication.novaTopViewController is NovaInterstitialAdViewController else {
            return
        }
        showSkOverlay()
    }

    @objc private func didTapVolumeButton() {
        guard let muted = interstitialAd.mediaContent.videoController?.muted else {
            return
        }
        setupVolumeIcon(muted: !muted)
        interstitialAd.mediaContent.videoController?.muted = !muted
    }

    @objc private func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }
}

// MARK: - SKOverlayDelegate

extension NovaInterstitialAdSKOverlaySubviewHandler: SKOverlayDelegate {
    func storeOverlayDidFailToLoad(_ overlay: SKOverlay, error: any Error) {
        DebugLogger.network.error("Failed to load SKOverlay: \(error.localizedDescription)")
    }

    func storeOverlayWillStartPresentation(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        transitionContext.addAnimation { [weak self] in
            self?.bottomContainerView.transform = CGAffineTransform(translationX: 0, y: -80)
        }
    }

    func storeOverlayDidFinishPresentation(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        DebugLogger.network.info("SKOverlay did show successfully")
        if skOverlayShowTimestamp == nil {
            skOverlayShowTimestamp = CACurrentMediaTime()
        }
        NovaTrackingUrlHelper.fire(url: self.thirdPartyTrackingURL)
        if !(UIApplication.novaTopViewController is NovaInterstitialAdViewController) {
            // If the top view controller is not InterstitialNovaAdViewController, we need to dismiss the SKOverlay
            // this could happen when skoverlay shows after interstitial ad is dismissed
            dismissSkOverlay()
        }
    }

    func storeOverlayWillStartDismissal(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        transitionContext.addAnimation { [weak self] in
            self?.bottomContainerView.transform = .identity
        }
    }
}

extension NovaInterstitialAdSKOverlaySubviewHandler: NovaClickAreaConfigurable {
    var title: UILabel? { nil }

    var body: UILabel? { nil }

    var advertiser: UILabel? { nil }

    var adTag: UILabel? { adTagLabel }

    var cta: UIButton? { nil }

    var icon: UIImageView? { nil }

    var clickableComponents: [NovaClickableComponent]? { interstitialAd.clickableComponents }
}
