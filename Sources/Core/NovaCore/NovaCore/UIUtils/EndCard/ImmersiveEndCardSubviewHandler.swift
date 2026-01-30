//
//  ImmersiveEndCardSubviewHandler.swift
//  NBNovaAdComponents
//
//  Created by Shanyu Li on 2025/2/13.
//

import Foundation
import UIKit

final class ImmersiveEndCardSubviewHandler {
    enum Constants {
        static let iconCornerRadius = 8.0
        static let iconSize = 60.0

        static let ctaCornerRadius = 8.0
        static let ctaHeight = 36
    }
    private weak var delegate: (any NovaAdEndCardSubviewBehaviorDelegate)?

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = Constants.iconCornerRadius
        imageView.clipsToBounds = true
        imageView.adClickArea = .iconEndcard
        return imageView
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline1
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.adClickArea = .advertiserEndcard
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = NovaColorPalettes.Gray.tint200
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adClickArea = .bodyEndcard
        return label
    }()

    private lazy var ctaLabel: UILabel = {
        let ctaLabel = UILabel()
        ctaLabel.backgroundColor = NovaColorPalettes.textButton
        ctaLabel.textColor = NovaColorPalettes.buttonText
        ctaLabel.font = .Nova.headline3
        ctaLabel.textAlignment = .center
        ctaLabel.layer.cornerRadius = Constants.ctaCornerRadius
        ctaLabel.layer.masksToBounds = true
        ctaLabel.adClickArea = .ctaEndcard
        return ctaLabel
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Close", comment: "close"), for: .normal)
        button.titleLabel?.font = .Nova.subtitle1
        button.titleLabel?.textColor = NovaColorPalettes.White
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
    }()

    private lazy var subviewStackView: UIStackView = {
        let stackView = UIStackView(
            arrangedSubviews: [iconView, nameLabel, descriptionLabel, ctaLabel, closeButton]
        )
        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
        ctaLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.ctaHeight)
            make.horizontalEdges.equalToSuperview()
        }
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.setCustomSpacing(15, after: iconView)
        stackView.setCustomSpacing(7, after: nameLabel)
        stackView.setCustomSpacing(17, after: descriptionLabel)
        stackView.setCustomSpacing(24, after: ctaLabel)
        return stackView
    }()

    init(delegate: NovaAdEndCardSubviewBehaviorDelegate) {
        self.delegate = delegate
    }
}

private extension ImmersiveEndCardSubviewHandler {
    @objc func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }
}

extension ImmersiveEndCardSubviewHandler: NovaAdEndCardSubviewHandling {
    func set(on parentView: UIView) {
        parentView.addSubview(subviewStackView)

        subviewStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(46.0)
        }
    }

    @MainActor
    func config(with model: NovaAdEndCardViewModel) {
        if let appIconUrl = model.iconUrl {
            iconView.isHidden = false
            iconView.kf.setImage(with: appIconUrl)
        } else {
            iconView.isHidden = true
        }
        nameLabel.setTextOrHideIfNilOrEmpty(model.advertiser)
        descriptionLabel.setTextOrHideIfNilOrEmpty(model.description)
        ctaLabel.text = model.ctaText ?? "CTA"
    }

    func clickableViews() -> [UIView] {
        [iconView, nameLabel, descriptionLabel, ctaLabel]
    }
}
