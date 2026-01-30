//
//  CenterEndCardSubviewHandler.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/19.
//

// MARK: - CenterEndCardSubviewHandler

import UIKit

final class CenterEndCardSubviewHandler {
    // MARK: Lifecycle

    init(delegate: any NovaAdEndCardSubviewBehaviorDelegate) {
        self.delegate = delegate
    }

    // MARK: Internal

    enum Constants {
        static let closeButtonSize = 48.0
    }

    // MARK: Private

    private class CenterWhiteCard: UIView {
        // MARK: Lifecycle

        fileprivate init(delegate: (any NovaAdEndCardSubviewBehaviorDelegate)?) {
            self.delegate = delegate
            super.init(frame: .zero)
            setupSubviews()
            adClickArea = .blankEndcard
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        fileprivate var tappableViews: [UIView] {
            [advertiserAvatar, ctaButton, self]
        }

        fileprivate func config(with model: NovaAdEndCardViewModel) {
            if let iconUrl = model.iconUrl {
                advertiserAvatar.kf.setImage(with: iconUrl)
                advertiserAvatar.isHidden = false
            } else {
                advertiserAvatar.isHidden = true
            }
            advertiserLabel.text = model.advertiser
            titleLabel.text = model.description
            bodyLabel.text = model.body
            ctaButton.setTitle(model.ctaText, for: .normal)
        }

        // MARK: Private

        private enum Constants {
            static let avatarSize = 60.0
        }

        private let advertiserAvatar: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = Constants.avatarSize * 0.5
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = NovaColorPalettes.Gray.tint100.cgColor

            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(Constants.avatarSize)
            }
            imageView.adClickArea = .iconEndcard
            return imageView
        }()

        private let advertiserLabel: UILabel = {
            let label = UILabel()
            label.font = .Nova.headline2
            label.textColor = NovaColorPalettes.Black
            label.numberOfLines = 1
            label.adClickArea = .advertiserEndcard
            label.isUserInteractionEnabled = true
            label.textAlignment = .center
            return label
        }()

        private let titleLabel: UILabel = {
            let label = UILabel()
            label.font = .Nova.subtitle1
            label.textColor = NovaColorPalettes.Black
            label.numberOfLines = 2
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.adClickArea = .bodyEndcard
            label.isUserInteractionEnabled = true
            label.textAlignment = .center
            return label
        }()

        private let bodyLabel: UILabel = {
            let label = UILabel()
            label.font = .Nova.body1
            label.textColor = NovaColorPalettes.Gray.tint500
            label.numberOfLines = 3
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.adClickArea = .bodyEndcard
            label.isUserInteractionEnabled = true
            label.textAlignment = .center
            return label
        }()

        private let ctaButton: UIButton = {
            let button = UIButton(type: .system)

            button.titleLabel?.font = .Nova.body1
            button.setTitleColor(NovaColorPalettes.White, for: .normal)

            button.layer.backgroundColor = NovaColorPalettes.Blue.tint500.cgColor
            button.layer.borderColor =
                UIColor(
                    light: NovaColorPalettes.Black.withAlphaComponent(0.6),
                    dark: NovaColorPalettes.Gray.tint200
                ).cgColor
            button.layer.cornerRadius = 8.0

            button.adClickArea = .ctaEndcard

            return button
        }()

        private weak var delegate: (any NovaAdEndCardSubviewBehaviorDelegate)?

        private func setupSubviews() {
            layer.cornerRadius = 24
            backgroundColor = NovaColorPalettes.White

            addSubviews(advertiserLabel, titleLabel, bodyLabel, ctaButton, advertiserAvatar)

            advertiserLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(36)
                make.left.right.equalToSuperview().inset(24)
            }

            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(advertiserLabel.snp.bottom).offset(24)
                make.left.right.equalToSuperview().inset(24)
            }

            bodyLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(16)
                make.left.right.equalToSuperview().inset(24)
            }

            ctaButton.snp.makeConstraints { make in
                make.top.equalTo(bodyLabel.snp.bottom).offset(24)
                make.left.right.equalToSuperview().inset(12)
                make.bottom.equalToSuperview().offset(-36)
            }

            advertiserAvatar.snp.makeConstraints { make in
                make.centerY.equalTo(self.snp.top).offset(-6)
                make.centerX.equalToSuperview()
            }
        }
    }

    private lazy var centerCard: CenterWhiteCard = .init(delegate: delegate)

    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button
            .setImage(
                .Nova.crossCircleLine?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysTemplate),
                for: .normal
            )
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
    }()

    private weak var delegate: (any NovaAdEndCardSubviewBehaviorDelegate)?
}

private extension CenterEndCardSubviewHandler {
    @objc func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }
}

extension CenterEndCardSubviewHandler: NovaAdEndCardSubviewHandling {
    func set(on parentView: UIView) {
        parentView.addSubviews(closeButton, centerCard)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(parentView.safeAreaLayoutGuide.snp.top).offset(4).priority(.high)
            make.top.equalTo(parentView.snp.top).offset(4).priority(.low)
            make.trailing.equalToSuperview().offset(-4)
            make.size.equalTo(Constants.closeButtonSize)
        }
        centerCard.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    func config(with model: NovaAdEndCardViewModel) {
        centerCard.config(with: model)
    }

    func clickableViews() -> [UIView] {
        centerCard.tappableViews
    }
}
