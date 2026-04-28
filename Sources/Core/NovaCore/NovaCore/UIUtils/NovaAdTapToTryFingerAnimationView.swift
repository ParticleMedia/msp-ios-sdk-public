//
//  NovaAdTapToTryFingerAnimationView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 4/27/26.
//

import UIKit
@_implementationOnly import Kingfisher
@_implementationOnly import MSPSnapKit

public class NovaAdTapToTryFingerAnimationView: NovaCustomCTAAnimationView {

    // MARK: - Subviews

    private let iconView = AnimatedImageView()

    // MARK: - Setup

    public override func setupSubviews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)

        iconView.contentMode = .scaleAspectFit
        iconView.kf.setImage(with: NovaResource.getGIFResourceURL("_nova_playable_tap_to_try"))
        addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(32)
        }

        snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
    }

    // MARK: - Animation

    public override func startAnimating() {
        iconView.startAnimating()
    }

    public override func stopAnimating() {
        iconView.stopAnimating()
    }
}
