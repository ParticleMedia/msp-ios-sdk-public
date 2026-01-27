//
//  NovaAdTapToTryStaticView.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/12/19.
//

import Foundation
import UIKit
@_implementationOnly import MSPSnapKit

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

    private lazy var centerImageIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.Nova.gameFilled
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private func setupViews() {
        backgroundColor = NovaColorPalettes.Black.withAlphaComponent(0.4)
        addSubview(centerImageIcon)
        centerImageIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(40.0 / 56.0)
            make.width.equalToSuperview().multipliedBy(40.0 / 56.0)
        }

        layer.borderWidth = 1
        layer.borderColor = NovaColorPalettes.White.withAlphaComponent(0.6).cgColor
        adClickArea = .tap_to_try
    }
}

