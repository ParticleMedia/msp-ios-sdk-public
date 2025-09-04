//
//  NovaInterstitialAdTwoPartPlayableSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/8/08.
//

import Foundation
import UIKit
import SnapKit
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
        let image = UIImage.Nova.contextFilled?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysOriginal)
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

    private lazy var playableView: NovaAdMediaView = .init()

    private weak var parentView: UIView?
    private var isInPlayableMode = false
    
    init(interstitialAd: NovaInterstitialAdItem, delegate: NovaInterstitialAdSubviewBehaviorDelegate, viewController: UIViewController?) {
        self.interstitialAd = interstitialAd
        self.delegate = delegate
        self.viewController = viewController
    }

    func setupSubviews(in containerView: UIView) {
        self.parentView = containerView
        
        // Add first part views
        containerView.addSubview(mediaView)
        containerView.addSubview(topShadowView)
        containerView.addSubview(volumeButton)
        containerView.addSubview(toPlayableButton)
        containerView.addSubview(bottomShadowView)
        containerView.addSubview(advertiserStackView)
        containerView.addSubview(moreActionButton)
        
        // Add second part views (initially hidden)
        containerView.addSubview(playableTopBar)
        containerView.addSubview(playableView)

        setupFirstPartConstraints(in: containerView)
        setupSecondPartConstraints(in: containerView)
        
        // Initially show first part
        showFirstPart()
    }

    func config() {
        // Configure advertiser info
        if let advertiserText = interstitialAd.advertiser {
            advertiserLabel.text = advertiserText
        }
        
        // Configure advertiser avatar
        if let iconUrlStr = interstitialAd.iconUrlStr, let iconUrl = URL(string: iconUrlStr) {
            advertiserAvatar.isHidden = false
            advertiserAvatar.kf.setImage(with: iconUrl)
        } else {
            advertiserAvatar.isHidden = true
        }

        setupVolumeIcon(muted: interstitialAd.mediaContent.videoController?.muted ?? true)

        // Configure media view
        interstitialAd.mediaContent.videoController?.style = .playButtonOnCenter(progressBarStyle: .hide)
        interstitialAd.mediaContent.playableController?.renderOption = .imageOrVideo
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
        getClickableViewsFromConfiguration() ?? [advertiserStackView]
    }
    
    func didAppear() {
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
        return [
            playableTopBar,
            playableView
        ]
    }

    private func setupFirstPartConstraints(in containerView: UIView) {
        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        topShadowView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(166.0)
        }
        
        volumeButton.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.width.height.equalTo(32)
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
            make.trailing.lessThanOrEqualTo(moreActionButton.snp.leading).offset(-20)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        moreActionButton.snp.makeConstraints { make in
            make.centerY.equalTo(advertiserStackView)
            make.trailing.equalToSuperview().offset(-20)
            make.width.height.equalTo(24)
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

    private func showSecondPart() {
        firstPartViews.forEach { $0.isHidden = true }
        interstitialAd.mediaContent.videoController?.stop()
        secondPartViews.forEach { $0.isHidden = false }
        isInPlayableMode = true
    }

    @objc private func didTapVolumeButton() {
        guard let muted = interstitialAd.mediaContent.videoController?.muted else {
            return
        }

        setupVolumeIcon(muted: !muted)
        interstitialAd.mediaContent.videoController?.muted.toggle()
    }

    @objc private func didTapToPlayable() {
        showSecondPart()
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

