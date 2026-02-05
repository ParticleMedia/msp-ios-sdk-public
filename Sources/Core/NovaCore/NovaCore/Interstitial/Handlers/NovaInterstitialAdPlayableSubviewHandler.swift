//
//  NovaInterstitialAdPlayableSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/8/08.
//

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit
import WebKit

class NovaInterstitialAdPlayableSubviewHandler: NovaInterstitialAdSubviewHandler {
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

    private lazy var advertiserAvatar: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Constants.avatarSize * 0.5
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = NovaColorPalettes.Gray.tint200.cgColor
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

    private lazy var adTagLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.caption1
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.text = "Ad"
        label.adClickArea = .badge
        return label
    }()

    private lazy var advertiserLabelsStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [advertiserLabel, adTagLabel])
        view.axis = .vertical
        view.alignment = .leading
        view.spacing = 2.0
        return view
    }()

    private lazy var advertiserInfoStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [advertiserAvatar, advertiserLabelsStackView])
        advertiserAvatar.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.avatarSize)
        }
        view.axis = .horizontal
        view.alignment = .top
        view.spacing = 10.0
        return view
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

    private lazy var mediaView: NovaAdMediaView = .init()

    private weak var parentView: UIView?
    private let interstitialAd: NovaInterstitialAdItem


    private weak var delegate: NovaInterstitialAdSubviewBehaviorDelegate?

    init(interstitialAd: NovaInterstitialAdItem, delegate: NovaInterstitialAdSubviewBehaviorDelegate) {
        self.delegate = delegate
        self.interstitialAd = interstitialAd
    }

    func setupSubviews(in containerView: UIView, showReportButton: Bool) {
        self.parentView = containerView

        containerView.addSubview(mediaView)
        containerView.addSubview(topGradientView)
        containerView.addSubview(advertiserInfoStackView)
        containerView.addSubview(closeButton)

        topGradientView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(166.0)
        }

        mediaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        advertiserInfoStackView.snp.makeConstraints { make in
            make.top.equalTo(containerView.safeAreaLayoutGuide).offset(Constants.subviewPadding)
            make.leading.equalToSuperview().offset(Constants.subviewPadding)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(Constants.subviewPadding)
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Constants.subviewPadding)
            make.centerY.equalTo(advertiserInfoStackView)
            make.height.width.equalTo(Constants.closeButtonSize)
        }
    }

    @MainActor
    func config() {
        if let iconURL = interstitialAd.iconURL {
            advertiserAvatar.isHidden = false
            advertiserAvatar.kf.setImage(with: iconURL)
        } else {
            advertiserAvatar.isHidden = true
        }

        advertiserLabel.text = interstitialAd.advertiser
        adTagLabel.text = NSLocalizedString("Ad", comment: "ad")

        // Configure playable content
        interstitialAd.mediaContent.playableController?.renderOption = .playable
        interstitialAd.mediaContent.playableController?.delegate = self
        mediaView
            .config(
                with: interstitialAd.mediaContent,
                actionContext: .init(
                    adActionTracingInfo: interstitialAd.actionTracingInfo,
                    adActionExtraInfo: interstitialAd.actionExtraInfo,
                    viewController: nil
                )
            )
    }

    var clickableViews: [UIView] {
        getClickableViewsFromConfiguration() ?? []
    }

    // MARK: Private

    private enum Constants {
        static let avatarSize: Double = 36.0
        static let subviewPadding: Double = 20.0
        static let closeButtonSize: Double = 32.0
    }

    @objc private func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }
}

extension NovaInterstitialAdPlayableSubviewHandler: NovaClickAreaConfigurable {
    var title: UILabel? { nil }

    var body: UILabel? { nil }

    var advertiser: UILabel? { advertiserLabel }

    var adTag: UILabel? { adTagLabel }

    var cta: UIButton? { nil }

    var icon: UIImageView? { advertiserAvatar }

    var clickableComponents: [NovaClickableComponent]? { interstitialAd.clickableComponents }
}

extension NovaInterstitialAdPlayableSubviewHandler: NovaAdPlayableViewDelegate {
    func playableViewDidRequestClose() {
        delegate?.didTapCloseButton()
    }
}
