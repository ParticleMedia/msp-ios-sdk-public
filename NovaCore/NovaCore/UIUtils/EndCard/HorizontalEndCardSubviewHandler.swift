//
//  HorizontalEndCardSubviewHandler.swift
//  NBNovaAdComponents
//
//  Created by Shanyu Li on 2025/2/18.
//

import Foundation
import UIKit

final class HorizontalEndCardSubviewHandler {
    enum Constants {
        static let iconSize = 36.0
        static let stackViewVerticalSpacing = 12.0
    }
    private weak var delegate: (any NovaAdEndCardSubviewBehaviorDelegate)?

    private lazy var watchAgainIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .Nova.arrowClockwiseLine?.withTintColor(NovaColorPalettes.White)
        return imageView
    }()

    private lazy var watchAgainLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle2
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.text = NSLocalizedString("Watch Again", comment: "watch again")
        label.numberOfLines = 1
        return label
    }()

    private lazy var watchAgainStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [watchAgainIcon, watchAgainLabel])
        watchAgainIcon.snp.makeConstraints { make in
            make.height.width.equalTo(Constants.iconSize)
        }
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Constants.stackViewVerticalSpacing
        stackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapWatchAgainButton)))
        return stackView
    }()

    private lazy var ctaImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private lazy var ctaLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle2
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.numberOfLines = 1
        return label
    }()

    private lazy var ctaStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [ctaImageView, ctaLabel])
        ctaImageView.snp.makeConstraints { make in
            make.height.width.equalTo(Constants.iconSize)
        }
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Constants.stackViewVerticalSpacing
        stackView.adClickArea = .cta_endcard
        return stackView
    }()

    private lazy var allStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [watchAgainStackView, ctaStackView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 48
        return stackView
    }()

    init(delegate: any NovaAdEndCardSubviewBehaviorDelegate) {
        self.delegate = delegate
    }
}

private extension HorizontalEndCardSubviewHandler {
    @objc func didTapWatchAgainButton() {
        delegate?.didTapWatchAgainButton()
    }
}

extension HorizontalEndCardSubviewHandler: NovaAdEndCardSubviewHandling {
    func set(on parentView: UIView) {
        parentView.addSubview(allStackView)
        allStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.leading.greaterThanOrEqualToSuperview()
            make.trailing.bottom.lessThanOrEqualToSuperview()
        }
    }

    func config(with model: NovaAdEndCardViewModel) {
        let image: UIImage? = model.isAppInstall ? .Nova.ellipsisHorizontalCircleLine : .Nova.downloadLine
        ctaImageView.image = image?.withTintColor(NovaColorPalettes.White)
        ctaLabel.text = model.ctaText
    }

    func clickableViews() -> [UIView] {
        return [ctaStackView]
    }
}
