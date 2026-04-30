//
//  NovaAdTapToTryCircleAnimationView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 4/10/26.
//

import UIKit
@_implementationOnly import MSPSnapKit

public class NovaAdTapToTryCircleAnimationView: NovaCustomCTAAnimationView {

    // MARK: - Subviews

    private let iconView = UIImageView()

    // MARK: - Setup

    public override func setupSubviews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)

        iconView.image = UIImage.Nova.gameFilled?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .systemRed
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(32)
        }

        self.snp.makeConstraints { make in
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
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [0, 0.25, -0.25, 0.20, -0.20, 0.2, -0.2, 0.2, -0.2, 0, 0]
        rotation.keyTimes = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.0, 1.15, 1.15, 1.15, 1.15, 1.15, 1.15, 1.0, 1.0, 1.0]
        scale.keyTimes = [0, 0.1, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0]

        let group = CAAnimationGroup()
        group.animations = [rotation, scale]
        group.duration = 2.0
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        iconView.layer.add(group, forKey: "pulse")
    }

    public override func stopAnimating() {
        iconView.layer.removeAnimation(forKey: "pulse")
    }
}
