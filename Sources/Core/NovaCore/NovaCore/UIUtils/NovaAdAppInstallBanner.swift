//
//  NovaAdAppInstallBanner.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/14.
//

import Foundation
import UIKit
@_implementationOnly import Kingfisher
@_implementationOnly import SnapKit

// MARK: - NovaAdAppInstallBanner

class NovaAdAppInstallBanner: UIView {
    // MARK: Lifecycle

    init(config: Config) {
        self.config = config
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    struct Config {
        let appInfo: NovaAdAppInfo
        let callToAction: String?

        init(appInfo: NovaAdAppInfo, callToAction: String?) {
            self.appInfo = appInfo
            self.callToAction = callToAction
        }
    }

    weak var delegate: NovaAdAppInstallBannerDelegate?

    func showWithAnimation() {
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }

    // MARK: Private

    private let config: Config

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 7.2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.adClickArea = .icon
        return imageView
    }()

    private lazy var headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = UIColor(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.White)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adClickArea = .headline
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.caption1
        label.textColor = UIColor(light: NovaColorPalettes.Gray.tint500, dark: NovaColorPalettes.White.withAlphaComponent(0.6))
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adClickArea = .body
        return label
    }()

    private lazy var ctaButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = NovaColorPalettes.Blue.tint500
        config.baseForegroundColor = .white
        config.attributedTitle = AttributedString("", attributes: AttributeContainer([
            .font: UIFont.Nova.subtitle1
        ]))
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let button = UIButton(configuration: config)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true

        button.addTarget(self, action: #selector(didTapBannerButton(_:)), for: .touchUpInside)
        button.adClickArea = .cta
        return button
    }()

    private func setupViews() {
        backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint800)

        let textStackView = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.alignment = .leading

        let mainStackView = UIStackView(arrangedSubviews: [iconImageView, textStackView, ctaButton])
        mainStackView.axis = .horizontal
        mainStackView.setCustomSpacing(12.0, after: iconImageView)
        mainStackView.setCustomSpacing(20.0, after: textStackView)
        mainStackView.alignment = .center

        addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(36)
        }

        ctaButton.snp.makeConstraints { make in
            make.width.equalTo(183)
            make.height.equalTo(36)
        }

        if let iconUrl = config.appInfo.appIconUrl {
            iconImageView.isHidden = false
            iconImageView.kf.setImage(with: iconUrl)
        } else {
            iconImageView.isHidden = true
        }

        headlineLabel.setOrHide(with: config.appInfo.appName)
        bodyLabel.setOrHide(with: config.appInfo.appDescription)
        ctaButton.setTitle(config.callToAction ?? "Install now", for: .normal)

        [iconImageView, headlineLabel, bodyLabel].forEach {
            $0.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapBanner(_:)))
            $0.addGestureRecognizer(tapGesture)
        }
    }

    @objc private func didTapBanner(_ sender: UITapGestureRecognizer) {
        guard let subview = sender.view else {
            return
        }
        delegate?.appInstallBannerDidTap(self, subview: subview)
    }

    @objc private func didTapBannerButton(_ button: UIButton) {
        delegate?.appInstallBannerDidTap(self, subview: button)
    }
}

// MARK: - NovaAdAppInstallBannerDelegate

protocol NovaAdAppInstallBannerDelegate: AnyObject {
    func appInstallBannerDidTap(_ banner: NovaAdAppInstallBanner, subview: UIView)
}

// MARK: - Helper Extension

fileprivate extension UILabel {
    func setOrHide(with text: String?) {
        if let text, !text.isEmpty {
            self.isHidden = false
            self.text = text
        } else {
            self.isHidden = true
        }
    }
}

