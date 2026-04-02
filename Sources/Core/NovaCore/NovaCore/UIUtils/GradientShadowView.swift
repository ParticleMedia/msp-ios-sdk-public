//
//  GradientShadowView.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import UIKit

public struct GradientShadowViewConfig {
    let (startColor, endColor): (UIColor, UIColor)
    let (startPosition, endPosition): (CGPoint, CGPoint)
    let shadowColor: UIColor
    let shadowOpacity: Float
    let shadowOffset: CGSize
    let shadowRadius: CGFloat

    public init(
        colors: (UIColor, UIColor),
        points: (CGPoint, CGPoint),
        shadowColor: UIColor = .clear,
        shadowOpacity: Float = 0,
        shadowOffset: CGSize = .zero,
        shadowRadius: CGFloat = 0
    ) {
        self.startColor = colors.0
        self.endColor = colors.1
        self.startPosition = points.0
        self.endPosition = points.1
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowOffset = shadowOffset
        self.shadowRadius = shadowRadius
    }
}

public class GradientShadowView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let config: GradientShadowViewConfig

    public init(with config: GradientShadowViewConfig) {
        self.config = config
        super.init(frame: .zero)
        setupGradient()
        setupShadow()
        self.isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGradient() {
        gradientLayer.colors = [
            config.startColor.cgColor,
            config.endColor.cgColor
        ]
        gradientLayer.startPoint = config.startPosition
        gradientLayer.endPoint = config.endPosition
        layer.addSublayer(gradientLayer)
    }

    private func setupShadow() {
        layer.shadowColor = config.shadowColor.cgColor
        layer.shadowOpacity = config.shadowOpacity
        layer.shadowOffset = config.shadowOffset
        layer.shadowRadius = config.shadowRadius
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
