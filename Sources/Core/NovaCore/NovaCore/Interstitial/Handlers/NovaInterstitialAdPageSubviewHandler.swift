//
//  NovaInterstitialAdPageSubviewHandler.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//
import Foundation
@_implementationOnly import MSPSnapKit
import StoreKit
import UIKit
import WebKit

class NovaInterstitialAdPageSubviewHandler: NSObject, NovaInterstitialAdSubviewHandler, NovaTopRightClosable {
    var darkColor: UIColor { NovaColorPalettes.Gray.tint200 }

    enum LayoutMetrics {
        static let avatarSize = 24.0
        static let horizontalMargin = 16.0
        static let bottomButtonBottomMargin = 24.0
        static let bottomButtonHeight = 48.0
        static let bottomButtonWidth = 156.0
        static let volumeButtonWidth = 32.0
        static let volumeButtonBottomMargin = 28.0
    }

    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?
    private weak var containerView: UIView?
    var countdownTimer: Timer?
    var countdownSecondRemaining: Int
    var delayTimer: Timer?
    var delaySecondRemaining: Int?
    var backgroundObserver: NSObjectProtocol?
    var foregroundObserver: NSObjectProtocol?
    var useCustomClose: Bool
    private var htmlMediaModel: NovaAdHtmlMediaModel
    private var showReportButton: Bool = false

    var clickableViews: [UIView] = []

    private(set) lazy var topRightCloseButton: UIButton = {
        let button = UIButton()
        button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.cornerRadius = 8
        button.backgroundColor = NovaColorPalettes.Gray.tint600.withAlphaComponent(0.5)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.isUserInteractionEnabled = false
        return button
    }()

    private(set) lazy var topRightCloseButtonArea: UIView = {
        let view = UIView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        return view
    }()

    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.adClickArea = .media
        return view
    }()

    private var htmlView: NovaAdHtmlView?

    private lazy var skOverlayController: NovaSKOverlayController = {
        let thirdPartyTrackingURL = interstitialAd.thirdPartyClickTrackingUrls
            .first
            .flatMap(URL.init(string:))
        let controller = NovaSKOverlayController(
            encryptedAdToken: interstitialAd.encryptedAdToken,
            thirdPartyTrackingURL: thirdPartyTrackingURL,
            requiredTopViewControllerType: NovaInterstitialAdViewController.self
        )
        return controller
    }()

    init(
        interstitialAd: NovaInterstitialAdItem,
        delegate: NovaInterstitialAdSubviewBehaviorDelegate,
        viewController: UIViewController?,
        htmlMediaModel: NovaAdHtmlMediaModel
    ) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
        self.htmlMediaModel = htmlMediaModel
        self.countdownSecondRemaining = htmlMediaModel.currentPage.closeCountDownSeconds ?? 0
        self.delaySecondRemaining = htmlMediaModel.currentPage.closeDelaySeconds
        self.useCustomClose = htmlMediaModel.currentPage.useCustomClose
        super.init()
    }

    func setupSubviews(in containerView: UIView, showReportButton: Bool) {
        self.containerView = containerView
        self.showReportButton = showReportButton
        ensureHtmlView(in: containerView, showReportButton: showReportButton)
        setupTopRightClose()
    }

    func config() {
        renderCurrentPage()
    }

    @objc private func didTapCloseButton() {
        showNextPageIfNeededOrClose()
    }

    func willAppear() {
        if !useCustomClose {
            setupDelayTimerIfNeeded()
        }
    }

    func didAppear() {
        htmlView?.setAllMediaPlaybackSuspended(false, completionHandler: nil)
    }

    func willDisappear() {
        skOverlayController.dismiss()
        htmlView?.setAllMediaPlaybackSuspended(true, completionHandler: nil)
    }

    func didDisappear() {
        skOverlayController.dismiss()
        teardownCountdown()
    }

    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        topRightCloseButton.isUserInteractionEnabled = true
        topRightCloseButton.isHidden = false
        if htmlMediaModel.hasNextPage {
            configTopRightButtonForSkip()
        } else {
            configTopRightButtonForClose()
        }
    }

    func configTopRightButtonForSkip() {
        topRightCloseButton.setTitle(nil, for: .normal)

        topRightCloseButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white  // text + chevron should be white since bg is translucent
        config.attributedTitle = AttributedString("SKIP")
        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 4

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 12,
            bottom: 8,
            trailing: 10
        )
        topRightCloseButton.configuration = config
        topRightCloseButton.translatesAutoresizingMaskIntoConstraints = false
    }

    func configTopRightButtonForClose() {
        topRightCloseButton.setTitle(nil, for: .normal)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.baseForegroundColor = .white

        config.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6, leading: 6, bottom: 6, trailing: 6
        )

        topRightCloseButton.configuration = config
    }
}

extension NovaInterstitialAdPageSubviewHandler: NovaAdHtmlActionDelegate {
    func didTapAdCtr(customUrl: URL?, clickArea: ClickableAdArea) {
        delegate?.didTapCustomAdView(customUrl: customUrl, clickArea: clickArea)
    }

    func didTapAdReport() {
        delegate?.didTapFeedbackButton()
    }

    func didTapAdClose() {
        showNextPageIfNeededOrClose()
    }

    func didFailToLoadPage(errorMessage: String?) {
        delegate?.didFailToLoad(errorMessage: errorMessage)
    }

    func showSKOverlay(appStoreId: Int?) {
        guard let appStoreId else { return }
        let scene = htmlView?.window?.windowScene
        skOverlayController.show(appStoreId: appStoreId, scene: scene, userDismissible: true)
    }
}

private extension NovaInterstitialAdPageSubviewHandler {
    func configurePage() {
        htmlView?
            .config(
                with: htmlMediaModel.currentPage,
                htmlActionDelegate: self,
                tracingInfo: .init(adUnitId: interstitialAd.adUnitId, encryptedToken: interstitialAd.encryptedAdToken)
            )
    }

    func showNextPageIfNeededOrClose() {
        do {
            skOverlayController.dismiss()
            try htmlMediaModel.toNextPage()
            renderCurrentPage()
        } catch {
            delegate?.didTapCloseButton()
        }
    }

    func ensureHtmlView(in containerView: UIView, showReportButton: Bool) {
        guard htmlView == nil else { return }
        let view: NovaAdHtmlView
        if let cachedHtmlView = self.interstitialAd.cachedHtmlView {
            view = cachedHtmlView
            self.interstitialAd.cachedHtmlView = nil
        } else {
            view = NovaAdHtmlView(supportReportHandling: showReportButton)
        }
        htmlView = view
        containerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupTopRightClose() {
        resetTimers()

        countdownSecondRemaining = htmlMediaModel.currentPage.closeCountDownSeconds ?? 0
        delaySecondRemaining = htmlMediaModel.currentPage.closeDelaySeconds
        useCustomClose = htmlMediaModel.currentPage.useCustomClose

        if useCustomClose {
            topRightCloseButton.isHidden = true
            topRightCloseButton.isUserInteractionEnabled = false
            topRightCloseButton.removeFromSuperview()
        } else if let containerView {
            if topRightCloseButton.superview == nil {
                containerView.addSubview(topRightCloseButton)
                topRightCloseButton.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(64)
                    make.trailing.equalToSuperview().offset(-16)
                    make.height.equalTo(32)
                    make.width.greaterThanOrEqualTo(32)
                }
            }
        }
    }

    func resetTimers() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        delayTimer?.invalidate()
        delayTimer = nil
    }

    func renderCurrentPage() {
        guard let containerView else {
            delegate?.didTapCloseButton()
            return
        }
        ensureHtmlView(in: containerView, showReportButton: showReportButton)
        htmlView?.pauseAllMediaPlayback()
        setupTopRightClose()
        configurePage()
        containerView.bringSubviewToFront(topRightCloseButton)
    }
}
