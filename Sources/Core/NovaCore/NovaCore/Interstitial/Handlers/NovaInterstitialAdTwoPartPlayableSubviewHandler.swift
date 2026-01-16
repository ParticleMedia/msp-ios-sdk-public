//
//  NovaInterstitialAdTwoPartPlayableSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/8/08.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit
import WebKit

class NovaInterstitialAdTwoPartPlayableSubviewHandler: NovaInterstitialAdSubviewHandler {
    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?

    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.adClickArea = .media
        return view
    }()

    private lazy var topShadowView: GradientShadowView = {
        let config = GradientShadowViewConfig(
            colors: (
                UIColor.black.withAlphaComponent(0.4),
                UIColor.clear
            ),
            points: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.0))
        )
        return GradientShadowView(with: config)
    }()

    private lazy var volumeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(didTapVolumeButton), for: .touchUpInside)
        return button
    }()

    private lazy var toPlayableButton: UIButton = {
        let button = UIButton()
        let image = UIImage.Nova.chevronRightCircleFilled?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor.white
        button.addTarget(self, action: #selector(didTapToPlayable), for: .touchUpInside)
        return button
    }()

    private lazy var advertiserAvatar: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = Constants.avatarSize / 2
        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = NovaColorPalettes.Gray.tint200.cgColor
        imageView.clipsToBounds = true
        imageView.adClickArea = .icon
        return imageView
    }()

    private lazy var advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline3
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.25
        label.layer.shadowRadius = 10
        label.adClickArea = .advertiser
        return label
    }()

    private lazy var adTagLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.caption1
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.25
        label.layer.shadowRadius = 10
        label.text = String(format: Constants.adGuideTextFormat, 1)
        label.adClickArea = .badge
        return label
    }()

    private lazy var advertiserLabelStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [advertiserLabel, adTagLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.setCustomSpacing(2.0, after: advertiserLabel)
        return stackView
    }()

    private lazy var advertiserStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [advertiserAvatar, advertiserLabelStackView])
        advertiserAvatar.snp.makeConstraints { make in
            make.size.equalTo(Constants.avatarSize)
        }
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.setCustomSpacing(10.0, after: advertiserAvatar)
        return stackView
    }()

    private lazy var moreActionButton: UIButton = {
        let button = UIButton()
        button.contentMode = .scaleAspectFill
        let image = UIImage.Nova.ellipsisHorizontalOutline?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(didTapMoreButton), for: .touchUpInside)
        return button
    }()

    private lazy var bottomShadowView: UIView = {
        let view = UIView()
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        view.layer.addSublayer(gradientLayer)
        return view
    }()

    private lazy var playableTopBar: NovaAdPlayableTopBar = {
        let topBar = NovaAdPlayableTopBar()
        topBar.didTapClose = {
            self.delegate?.didTapCloseButton()
        }
        return topBar
    }()

    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint800)
        return view
    }()

    private lazy var playableView: NovaAdMediaView = .init()
    private var appInstallBanner: NovaAdAppInstallBanner?

    private weak var parentView: UIView?
    private var isInPlayableMode = false
    
    init(interstitialAd: NovaInterstitialAdItem, delegate: NovaInterstitialAdSubviewBehaviorDelegate, viewController: UIViewController?) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
    }

    func setupSubviews(in containerView: UIView, showReportButton: Bool) {
        self.parentView = containerView
        
        // Add first part views
        containerView.addSubview(mediaView)
        containerView.addSubview(topShadowView)
        containerView.addSubview(volumeButton)
        containerView.addSubview(toPlayableButton)
        containerView.addSubview(bottomShadowView)
        containerView.addSubview(advertiserStackView)
        if showReportButton {
            containerView.addSubview(moreActionButton)
        }

        // Add second part views (initially hidden)
        containerView.addSubview(playableTopBar)
        containerView.addSubview(playableView)

        setupFirstPartConstraints(in: containerView, showReportButton: showReportButton)
        setupSecondPartConstraints(in: containerView)
        
        // Initially show first part
        showFirstPart()
    }

    @MainActor
    func config() {
        // Configure advertiser info
        if let advertiserText = interstitialAd.advertiser {
            advertiserLabel.text = advertiserText
        }
        
        // Configure advertiser avatar
        if let iconURL = interstitialAd.iconURL {
            advertiserAvatar.isHidden = false
            advertiserAvatar.kf.setImage(with: iconURL)
        } else {
            advertiserAvatar.isHidden = true
        }

        setupVolumeIcon(muted: interstitialAd.mediaContent.videoController?.muted ?? true)

        // Configure media view
        interstitialAd.mediaContent.videoController?.style = .playButtonOnCenter(progressBarStyle: .hide, popupCTAStyle: .show())
        interstitialAd.mediaContent.videoController?.delegate = self
        interstitialAd.mediaContent.playableController?.renderOption = .imageOrVideo
        interstitialAd.mediaContent.elementLayout = .init(
            safeAreaInsets: .init(
                top: UIApplication.novaSafeAreaInsets.top + Constants.volumeIconTopPadding + Constants.volumeIconSize,
                left: 0,
                bottom: Constants.advertiserBottomPadding + 36, // 36 is advertiserStackView's height
                right: 0
            ),
            showTapToTry: false
        )
        mediaView.config(
            with: interstitialAd.mediaContent,
            actionContext: .init(
                adActionTracingInfo: interstitialAd.actionTracingInfo,
                adActionExtraInfo: interstitialAd.actionExtraInfo,
                viewController: Weak(viewController)
            )
        )
        
        // Configure playable top bar
        playableTopBar.configure(title: String(format: Constants.adGuideTextFormat, 2))
        
        // Configure playable content
        interstitialAd.mediaContent.playableController?.renderOption = .playable
        playableView
            .config(
                with: interstitialAd.mediaContent,
                actionContext: .init(
                    adActionTracingInfo: interstitialAd.actionTracingInfo,
                    adActionExtraInfo: interstitialAd.actionExtraInfo,
                    viewController: Weak(viewController)
                )
            )
    }

    var clickableViews: [UIView] { 
        getClickableViewsFromConfiguration() ?? [advertiserAvatar, advertiserLabel, adTagLabel]
    }
    
    func willAppear() {
        interstitialAd.mediaContent.videoController?.play()
    }
    
    func didDisappear() {
        interstitialAd.mediaContent.videoController?.pause()
    }

    // MARK: Private

    private enum Constants {
        static let avatarSize: Double = 36.0
        static let adGuideTextFormat: String = "Ad • Part %d/2"
        static let rightTopButtonSize: Double = 48.0
        static let volumeIconSize: Double = 32.0
        static let volumeIconTopPadding: Double = 20.0
        static let advertiserBottomPadding: Double = 40.0
    }

    private var firstPartViews: [UIView] {
        return [
            mediaView,
            topShadowView,
            volumeButton,
            toPlayableButton,
            bottomShadowView,
            advertiserStackView,
            moreActionButton
        ]
    }

    private var secondPartViews: [UIView] {
        var views: [UIView] = [
            playableTopBar,
            playableView
        ]
        if let appInstallBanner {
            views.append(contentsOf: [appInstallBanner, bottomBar])
        }
        return views
    }

    private func setupFirstPartConstraints(in containerView: UIView, showReportButton: Bool) {
        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        topShadowView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(166.0)
        }
        
        volumeButton.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide).offset(Constants.volumeIconTopPadding)
            make.leading.equalToSuperview().offset(20)
            make.width.height.equalTo(Constants.volumeIconSize)
        }
        
        toPlayableButton.snp.makeConstraints { make in
            make.centerY.equalTo(volumeButton)
            make.trailing.equalToSuperview().offset(-20)
            make.width.height.equalTo(32)
        }
        
        bottomShadowView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(100)
        }
        
        advertiserStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            if showReportButton {
                make.trailing.lessThanOrEqualTo(moreActionButton.snp.leading).offset(-20)
            } else {
                make.trailing.lessThanOrEqualToSuperview().offset(-20)
            }
            make.bottom.equalToSuperview().offset(-Constants.advertiserBottomPadding)
        }

        if showReportButton {
            moreActionButton.snp.makeConstraints { make in
                make.centerY.equalTo(advertiserStackView)
                make.trailing.equalToSuperview().offset(-20)
                make.width.height.equalTo(24)
            }
        }
    }

    private func setupSecondPartConstraints(in containerView: UIView) {
        playableTopBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.top).offset(40)
        }
        
        playableView.snp.makeConstraints { make in
            make.top.equalTo(playableTopBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func showFirstPart() {
        firstPartViews.forEach { $0.isHidden = false }
        secondPartViews.forEach { $0.isHidden = true }
        isInPlayableMode = false
    }

    private func showSecondPart(with reason: NovaAdMetricReporter.PlayableTapReason) {
        firstPartViews.forEach { $0.isHidden = true }
        interstitialAd.mediaContent.videoController?.stop()
        secondPartViews.forEach { $0.isHidden = false }
        isInPlayableMode = true
        NovaAdMetricReporter.logPlayableTapToTry(encryptedAdToken: interstitialAd.encryptedAdToken, reason: reason)
        setupAppInfoBannerIfNeeded()
    }

    @objc private func didTapVolumeButton() {
        guard let muted = interstitialAd.mediaContent.videoController?.muted else {
            return
        }

        setupVolumeIcon(muted: !muted)
        interstitialAd.mediaContent.videoController?.muted.toggle()
    }

    @objc private func didTapToPlayable() {
        showSecondPart(with: .click)
    }

    @objc private func didTapMoreButton() {
        delegate?.didTapFeedbackButton()
    }

    private func setupVolumeIcon(muted: Bool) {
        let volumeOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White)
        let volumeOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White)
        volumeButton.setImage(muted ? volumeOffImage : volumeOnImage, for: .normal)
        volumeButton.tintColor = UIColor.white
    }

    private func setupAppInfoBannerIfNeeded() {
        guard let playableActionModel else {
            return
        }

        guard case .appInstall = playableActionModel.launchAdType else {
            return
        }

        guard let playableConfig = interstitialAd.actionExtraInfo.playableConfig,
              playableConfig.actionBarFormat == .bottom,
              let appInfo = playableConfig.appInfo else {
            return
        }

        Task {
            do {
                let appInfo = try await appInfo.value()
                await MainActor.run {
                    let bannerConfig = NovaAdAppInstallBanner.Config(
                        appInfo: appInfo,
                        callToAction: playableConfig.callToAction
                    )
                    self.createAndShowBanner(with: bannerConfig)
                }
            } catch {
                DebugLogger.data.error("Load app info failed: \(error.localizedDescription)")
            }
        }
    }

    private var playableActionModel: PlayableModel? {
        switch interstitialAd.mediaContent.adMedia {
        case let .imagePlayable(_, playableMediaModel),
             let .videoPlayable(_, playableMediaModel):
            return playableMediaModel.playableActionModel
        default:
            return nil
        }
    }

    @MainActor
    private func createAndShowBanner(with bannerConfig: NovaAdAppInstallBanner.Config) {
        guard appInstallBanner == nil, let parentView else {
            return
        }

        let banner = NovaAdAppInstallBanner(config: bannerConfig)
        banner.delegate = self
        appInstallBanner = banner

        parentView.insertSubview(bottomBar, aboveSubview: playableView)
        parentView.insertSubview(banner, aboveSubview: playableView)

        bottomBar.snp.makeConstraints { make in
            make.bottom.directionalHorizontalEdges.equalToSuperview()
            make.height.equalTo(UIApplication.novaSafeAreaInsets.bottom + 22)
        }
        banner.snp.makeConstraints { make in
            make.directionalHorizontalEdges.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        playableView.snp.remakeConstraints { make in
            make.top.equalTo(playableTopBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(banner.snp.top)
        }

        banner.showWithAnimation()
    }
}

extension NovaInterstitialAdTwoPartPlayableSubviewHandler: NovaAdAppInstallBannerDelegate {
    func appInstallBannerDidTap(_ banner: NovaAdAppInstallBanner, subview: UIView) {
        let clickArea = subview.adClickArea ?? .cta
        delegate?.didTapCustomAdView(customUrl: nil, clickArea: clickArea)
    }
}

extension NovaInterstitialAdTwoPartPlayableSubviewHandler: NovaAdVideoViewDelegate {
    func videoViewDidPlayToEndTime() {
        showSecondPart(with: .auto)
    }
}

extension NovaInterstitialAdTwoPartPlayableSubviewHandler: NovaClickAreaConfigurable {
    var title: UILabel? { nil }

    var body: UILabel? { nil }

    var advertiser: UILabel? { advertiserLabel }

    var adTag: UILabel? { adTagLabel }

    var cta: UIButton? { nil }

    var icon: UIImageView? { advertiserAvatar }

    var clickableComponents: [NovaClickableComponent]? { interstitialAd.clickableComponents }
}
