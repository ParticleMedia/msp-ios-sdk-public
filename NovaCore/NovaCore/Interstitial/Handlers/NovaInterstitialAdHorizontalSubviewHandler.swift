//
//  NovaInterstitialAdHorizontalSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit

// MARK: - NovaInterstitialAdHorizontalSubviewHandler

// TODO: lsy, 我记得 nb 有一个将 title 和 body 拼接在一起的逻辑
class NovaInterstitialAdHorizontalSubviewHandler: NovaInterstitialAdSubviewHandler, NovaTopRightClosable {
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
        self.parentView = containerView
        
        containerView.addSubview(adTagLabel)
        containerView.addSubview(mediaView)
        containerView.addSubview(advertiserLabel)
        containerView.addSubview(feedbackButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(bodyLabel)
        containerView.addSubview(closeButton)
        containerView.addSubview(ctaButton)

        adTagLabel.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.equalTo(16)
        }

        let isIPadAndLandscapeMode = UIDevice.current.userInterfaceIdiom == .pad && (
            UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight
        )

        mediaView.snp.makeConstraints { make in
            make.top.equalTo(adTagLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.directionalHorizontalEdges.equalToSuperview().inset(16)
        }

        switch interstitialAd.mediaContent.renderRecommendation {
        case .aspectRatio(let ratio):
            mediaView.snp.makeConstraints { make in
                if isIPadAndLandscapeMode {
                    make.height.equalTo(containerView.snp.height).multipliedBy(CGFloat(1.0/3.0))
                } else {
                    make.height.equalTo(mediaView.snp.width).multipliedBy(CGFloat(1.0/ratio))
                }
            }
        case .aspectRatioAndOffset(let ratio, let offset):
            mediaView.snp.makeConstraints { make in
                make.height.equalTo(mediaView.snp.width).multipliedBy(CGFloat(1.0/ratio)).offset(offset)
            }
        case .minHeight(let minHeight):
            mediaView.snp.makeConstraints { make in
                make.height.equalTo(minHeight)
            }
        case .free, .none:
            mediaView.snp.makeConstraints { make in
                if isIPadAndLandscapeMode {
                    make.height.equalTo(containerView.snp.height).multipliedBy(CGFloat(1.0/3.0))
                } else {
                    make.height
                        .equalTo(mediaView.snp.width).multipliedBy(CGFloat(1.0 / AdsMediaConstants.defaultAspectRatio))
                }
            }
        }

        advertiserLabel.snp.makeConstraints { make in
            make.top.equalTo(mediaView.snp.bottom).offset(20)
            make.leading.equalTo(16)
            make.trailing.lessThanOrEqualTo(feedbackButton.snp.leading).offset(-16)
        }
        
        feedbackButton.snp.makeConstraints { make in
            make.centerY.equalTo(advertiserLabel)
            make.trailing.equalTo(-16)
            make.width.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(advertiserLabel.snp.bottom).offset(16)
            make.leading.equalTo(16)
            make.trailing.lessThanOrEqualTo(-16)
        }
        
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.equalTo(16)
            make.trailing.lessThanOrEqualTo(-16)
        }
        
        if showTopRightCloseButton {
            ctaButton.snp.makeConstraints { make in
                make.top.equalTo(bodyLabel.snp.bottom).offset(72)
                make.leading.equalToSuperview().offset(16)
                make.height.equalTo(40)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.lessThanOrEqualToSuperview().offset(-24)
            }

            containerView.addSubview(topRightCloseButtonArea)
            topRightCloseButtonArea.addSubview(topRightCloseButton)
            topRightCloseButtonArea.snp.makeConstraints { make in
                make.centerY.equalTo(adTagLabel.snp.centerY)
                make.trailing.equalToSuperview().offset(-4)
                make.size.equalTo(48)
            }
            topRightCloseButton.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(24)
            }
        } else {
            closeButton.snp.makeConstraints { make in
                make.top.equalTo(bodyLabel.snp.bottom).offset(72)
                make.height.equalTo(40)
                make.leading.equalTo(mediaView.snp.leading)
                make.trailing.equalTo(containerView.snp.centerX).offset(-8)
                make.bottom.lessThanOrEqualToSuperview().offset(-24)
            }

            ctaButton.snp.makeConstraints { make in
                make.top.equalTo(closeButton.snp.top)
                make.leading.equalTo(containerView.snp.centerX).offset(8)
                make.height.equalTo(40)
                make.trailing.equalTo(mediaView.snp.trailing)
                make.bottom.lessThanOrEqualToSuperview().offset(-24)
            }
        }
    }

    func config() {
        mediaView.config(
            with: interstitialAd.mediaContent,
            actionContext: .init(
                adActionTracingInfo: interstitialAd.actionTracingInfo,
                adActionExtraInfo: interstitialAd.actionExtraInfo,
                viewController: Weak(viewController)
            )
        )
        
        advertiserLabel.text = interstitialAd.advertiser
        titleLabel.text = interstitialAd.headline
        bodyLabel.text = interstitialAd.body
        ctaButton
            .setTitle(
                interstitialAd.callToAction?.isEmpty == false ? interstitialAd.callToAction : "Learn More",
                for: .normal
            )
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
    }

    var clickableViews: [UIView] {
        return getClickableViewsFromConfiguration() ?? [advertiserLabel, titleLabel, bodyLabel, ctaButton]
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

    // MARK: Private

    private enum Constants {
        static let closeButtonSize: Double = 48
    }

    private(set) lazy var adTagLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.6), dark: NovaColorPalettes.White.withAlphaComponent(0.6))
        label.numberOfLines = 1
        label.text = NSLocalizedString("Advertisement ", comment: "")
        label.adClickArea = .badge
        return label
    }()

    private lazy var mediaView: NovaAdMediaView = {
        let view = NovaAdMediaView()
        view.isUserInteractionEnabled = true
        view.adClickArea = .media
        return view
    }()

    private lazy var advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body1
        label.textColor = UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.6), dark: NovaColorPalettes.White.withAlphaComponent(0.6))
        label.numberOfLines = 1
        label.adClickArea = .advertiser
        return label
    }()

    private lazy var feedbackButton: UIButton = {
        let button = UIButton()
        let image = UIImage.Nova.contextFilled?.withTintColor(UIColor(light: NovaColorPalettes.Gray.tint500, dark: NovaColorPalettes.Gray.tint200), renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(didTapFeedbackButton), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline1
        label.textColor = UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.85), dark: NovaColorPalettes.White.withAlphaComponent(0.9))
        label.numberOfLines = 4
        label.lineBreakMode = .byWordWrapping
        label.adClickArea = .headline
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body1
        label.textColor = UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.6), dark: NovaColorPalettes.White.withAlphaComponent(0.6))
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 3
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        label.adClickArea = .body
        return label
    }()

    private lazy var ctaButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = NovaColorPalettes.Blue.tint500
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .Nova.subtitle1
        button.setTitleColor(NovaColorPalettes.White, for: .normal)
        button.adClickArea = .cta
        return button
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.layer.borderWidth = 1
        button.layer.borderColor = NovaColorPalettes.Gray.tint300.cgColor
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .Nova.subtitle1
        button.setTitleColor(UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.85), dark: NovaColorPalettes.White.withAlphaComponent(0.9)), for: .normal)
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
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
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        view.isUserInteractionEnabled = false
        return view
    }()

    private weak var parentView: UIView?
    private let interstitialAd: NovaInterstitialAdItem
    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?
    private weak var viewController: UIViewController?
    
    var countdownTimer: Timer?
    let countdownSecondRemaining: Int
    private let showTopRightCloseButton: Bool

    @objc private func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }

    @objc private func didTapFeedbackButton() {
        // TODO: lsy, feed back logic not implemented
        delegate?.didTapFeedbackButton()
    }
}

extension NovaInterstitialAdHorizontalSubviewHandler: NovaClickAreaConfigurable {
    var title: UILabel? { titleLabel }

    var body: UILabel? { bodyLabel }

    var advertiser: UILabel? { advertiserLabel }

    var adTag: UILabel? { adTagLabel }

    var cta: UIButton? { ctaButton }

    var icon: UIImageView? { nil }

    var clickableComponents: [NovaClickableComponent]? { interstitialAd.clickableComponents }
}
