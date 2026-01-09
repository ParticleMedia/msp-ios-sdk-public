//
//  NovaAdTapToTryStaticView.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/12/19.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit

// MARK: - NovaAdTapToTryStaticView

class NovaAdTapToTryStaticView: UIView {
    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private lazy var leftIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.Nova.gameFilled
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap to Try"
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.White
        return label
    }()

    private lazy var rightIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.Nova.chevronRightLine?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = NovaColorPalettes.White
        return imageView
    }()

    private lazy var containerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [leftIconImageView, textLabel, rightIconImageView])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()

    private func setupViews() {
        isUserInteractionEnabled = false
        backgroundColor = NovaColorPalettes.Black.withAlphaComponent(0.4)
        addSubview(containerStackView)
        containerStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        leftIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }

        rightIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }

        adClickArea = .tap_to_try
        layer.cornerRadius = 16.0
        layer.masksToBounds = true
    }
}

