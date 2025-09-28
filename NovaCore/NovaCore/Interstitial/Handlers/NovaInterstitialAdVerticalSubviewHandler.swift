//
//  NovaInterstitialAdVerticalSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit

// MARK: - NovaInterstitialAdVerticalSubviewHandler

class NovaInterstitialAdVerticalSubviewHandler: NovaInterstitialAdSubviewHandler, NovaTopRightClosable {
    // MARK: Lifecycle

    init(
        interstitialAd: NovaInterstitialAdItem,
        showTopRightCloseButton: Bool,
        delegate: NovaInterstitialAdSubviewBehaviorDelegate,
        viewController: UIViewController?
    ) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
        self.showTopRightCloseButton = showTopRightCloseButton
        self.countdownSecondRemaining = interstitialAd.closeCountDownTimeSeconds ?? 0
    }

    // MARK: Internal

    func setupSubviews(in containerView: UIView) {
        // TODO: - GPY need ipad layout
        self.parentView = containerView
        
        containerView.addSubview(mediaView)
        containerView.addSubview(bottomShadow)
        containerView.addSubview(closeButton)
        containerView.addSubview(ctaButton)
        containerView.addSubview(adTagLabel)
        containerView.addSubview(advertiserInfoStackView)
        containerView.addSubview(feedbackButton)
        containerView.addSubview(bodyLabel)
        containerView.addSubview(volumeButton)

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomShadow.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            let screenWidth = UIScreen.main.bounds.width
            make.height.equalTo(screenWidth * 280 / 375)
        }

        let totalButtonBottomMargin = LayoutMetrics.bottomButtonBottomMargin + LayoutMetrics.progressBarBottomMargin

        if showTopRightCloseButton {
            closeButton.isHidden = true
            ctaButton.snp.makeConstraints { make in
                make.leading.equalTo(containerView.snp.leading).offset(LayoutMetrics.horizontalMargin)
                make.trailing.equalTo(containerView.snp.trailing).offset(-LayoutMetrics.horizontalMargin)
                make.bottom.equalTo(containerView.snp.bottom).offset(-totalButtonBottomMargin)
                make.height.equalTo(LayoutMetrics.bottomButtonHeight)
                make.width.equalTo(LayoutMetrics.bottomButtonWidth)
            }
            containerView.addSubview(topRightCloseButtonArea)
            topRightCloseButtonArea.addSubview(topRightCloseButton)
            topRightCloseButtonArea.snp.makeConstraints { make in
                make.top.equalTo(containerView.safeAreaLayoutGuide.snp.top).offset(containerView.safeAreaInsets.top + 4)
                make.trailing.equalToSuperview().offset(-4)
                make.size.equalTo(48.0)
            }
            topRightCloseButton.snp.makeConstraints { make in
                make.size.equalTo(24.0)
                make.center.equalToSuperview()
            }
            
        } else {
            closeButton.snp.makeConstraints { make in
                make.leading.equalTo(containerView.snp.leading).offset(LayoutMetrics.horizontalMargin)
                make.bottom.equalTo(containerView.snp.bottom).offset(-totalButtonBottomMargin)
                make.height.equalTo(LayoutMetrics.bottomButtonHeight)
                make.trailing.equalTo(containerView.snp.centerX).offset(-8)
            }
            
            ctaButton.snp.makeConstraints { make in
                make.leading.equalTo(containerView.snp.centerX).offset(8)
                make.trailing.equalTo(containerView.snp.trailing).offset(-LayoutMetrics.horizontalMargin)
                make.bottom.equalTo(containerView.snp.bottom).offset(-totalButtonBottomMargin)
                make.height.equalTo(LayoutMetrics.bottomButtonHeight)
            }
        }

        adTagLabel.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.lessThanOrEqualTo(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(ctaButton.snp.top).offset(-16.0)
        }

        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.equalTo(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(adTagLabel.snp.top).offset(-8.0)
        }

        advertiserInfoStackView.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.trailing.lessThanOrEqualTo(feedbackButton.snp.leading).offset(-LayoutMetrics.horizontalMargin)
            make.bottom.equalTo(bodyLabel.snp.top).offset(-8.0)
        }

        feedbackButton.snp.makeConstraints { make in
            make.centerY.equalTo(advertiserInfoStackView)
            make.trailing.equalTo(-LayoutMetrics.horizontalMargin)
            make.width.height.equalTo(24)
        }

        volumeButton.snp.makeConstraints { make in
            make.leading.equalTo(LayoutMetrics.horizontalMargin)
            make.height.width.equalTo(LayoutMetrics.volumeButtonWidth)
            make.bottom.equalTo(advertiserInfoStackView.snp.top).offset(-LayoutMetrics.volumeButtonBottomMargin)
        }
    }

    func config() {
        // Configure advertiser info
        if let advertiserText = interstitialAd.advertiser {
            advertiserLabel.text = advertiserText
        }
        
        if let bodyText = interstitialAd.body {
            bodyLabel.text = bodyText
        }
        
        if let ctaText = interstitialAd.callToAction {
            ctaButton.setTitle(ctaText, for: .normal)
        }
        
        // Configure advertiser avatar
        if let iconURL = interstitialAd.iconURL {
            advertiserAvatar.isHidden = false
            advertiserAvatar.kf.setImage(with: iconURL)
        } else {
            advertiserAvatar.isHidden = true
        }
        
        closeButton.setTitle("Close", for: .normal)
        adTagLabel.setTitle("SPONSORED", for: .normal)
        
        // Configure media view
        interstitialAd.mediaContent.videoController?.style = .playButtonOnCenter(progressBarStyle: .hide, popupCTAStyle: .show)
        mediaView.config(
            with: interstitialAd.mediaContent,
            actionContext: .init(
                adActionTracingInfo: interstitialAd.actionTracingInfo,
                adActionExtraInfo: interstitialAd.actionExtraInfo,
                viewController: Weak(viewController)
            )
        )
        
        if case .video = interstitialAd.mediaContent.adMedia {
            volumeButton.isHidden = false
            setupVolumeIcon(muted: interstitialAd.mediaContent.videoController?.muted ?? true)
        } else {
            volumeButton.isHidden = true
        }
    }

    var clickableViews: [UIView] {
        getClickableViewsFromConfiguration() ?? [
            bottomShadow,
            ctaButton,
            adTagLabel,
            advertiserAvatar,
            advertiserLabel,
            bodyLabel
        ]
    }

    func didAppear() {
        interstitialAd.mediaContent.videoController?.play()
    }

    func didDisappear() {
        interstitialAd.mediaContent.videoController?.pause()
    }
    
    func willAppear() {
        guard showTopRightCloseButton else { return }
        setupCountdownTimerIfNeeded()
    }

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

    private lazy var advertiserAvatar: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = LayoutMetrics.avatarSize * 0.5
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = NovaColorPalettes.Gray.tint100.cgColor
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(LayoutMetrics.avatarSize)
        }
        imageView.adClickArea = .icon
        return imageView
    }()

    private lazy var advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline3
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.adClickArea = .advertiser
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.numberOfLines = 3
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.adClickArea = .body
        return label
    }()

    private lazy var adTagLabel: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = NovaColorPalettes.White
        configuration.background.backgroundColor = NovaColorPalettes.White.withAlphaComponent(0.2)
        configuration.background.cornerRadius = 2.0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2.0, leading: 6.0, bottom: 2.0, trailing: 6.0)
        configuration.title = "SPONSORED"
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 10, weight: .semibold)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.adClickArea = .badge
        return button
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.9), for: .normal)
        button.layer.cornerRadius = 8.0
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemGray3.cgColor
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        button.accessibilityIdentifier = "close"
        return button
    }()

    private lazy var ctaButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.backgroundColor = UIColor.systemBlue.cgColor
        button.layer.cornerRadius = 8.0
        button.adClickArea = .cta
        return button
    }()

    private lazy var bottomShadow: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = .Nova.bottomShadow
        imageView.adClickArea = .badge
        return imageView
    }()

    private lazy var advertiserInfoStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [advertiserAvatar, advertiserLabel])
        view.alignment = .center
        view.spacing = 6.0
        return view
    }()

    private lazy var feedbackButton: UIButton = {
        let button = UIButton()
        let image = UIImage.Nova.contextFilled?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor.white
        button.addTarget(self, action: #selector(didTapFeedbackButton), for: .touchUpInside)
        return button
    }()

    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.adClickArea = .media
        return view
    }()
    
    private(set) lazy var topRightCloseButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.setTitleColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: NovaColorPalettes.Gray.tint200), for: .normal)
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = 12
        button.layer.borderColor = UIColor(light: NovaColorPalettes.Gray.tint600, dark: NovaColorPalettes.Gray.tint200).cgColor
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private(set) lazy var topRightCloseButtonArea: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        return view
    }()

    private weak var parentView: UIView?
    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?
    
    var countdownTimer: Timer?
    let countdownSecondRemaining: Int
    private let showTopRightCloseButton: Bool

    private func setupVolumeIcon(muted: Bool) {
        let volumeOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White)
        let volumeOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White)
        volumeButton.setImage(muted ? volumeOffImage: volumeOnImage, for: .normal)
    }

    @objc private func didTapVolumeButton() {
        guard let muted = interstitialAd.mediaContent.videoController?.muted else {
            return
        }
        setupVolumeIcon(muted: !muted)
        interstitialAd.mediaContent.videoController?.muted.toggle()
    }

    @objc private func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }

    @objc private func didTapFeedbackButton() {
        delegate?.didTapFeedbackButton()
    }
}

extension NovaInterstitialAdVerticalSubviewHandler {
    static var bottomRoundAreaHeight: CGFloat {
        return UIApplication.novaHasTopSafeArea ? 34.0 : 0.0
    }
    
    enum LayoutMetrics {
        static let avatarSize = 24.0
        static let horizontalMargin = 16.0
        static let progressBarBottomMargin = 22.0 + bottomRoundAreaHeight
        static let bottomButtonBottomMargin = 24.0
        static let bottomButtonHeight = 48.0
        static let bottomButtonWidth = 156.0
        static let volumeButtonWidth = 24.0
        static let volumeButtonBottomMargin = 28.0
    }
}

extension NovaInterstitialAdVerticalSubviewHandler: NovaClickAreaConfigurable {
    var title: UILabel? { nil }

    var body: UILabel? { bodyLabel }

    var advertiser: UILabel? { advertiserLabel }

    var adTag: UILabel? { nil }

    var cta: UIButton? { ctaButton }

    var icon: UIImageView? { advertiserAvatar }

    var clickableComponents: [NovaClickableComponent]? { interstitialAd.clickableComponents }
}
