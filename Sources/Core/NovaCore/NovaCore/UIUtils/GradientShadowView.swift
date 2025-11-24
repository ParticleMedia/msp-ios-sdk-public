//
//  GradientShadowView.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - GradientShadowViewConfig

struct GradientShadowViewConfig {
    let colors: (UIColor, UIColor)
    let points: (CGPoint, CGPoint)
    
    init(colors: (UIColor, UIColor), points: (CGPoint, CGPoint)) {
        self.colors = colors
        self.points = points
    }
}

// MARK: - GradientShadowView

class GradientShadowView: UIView {
    
    // MARK: Lifecycle
    
    init(with config: GradientShadowViewConfig) {
        self.config = config
        super.init(frame: .zero)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    
    private let config: GradientShadowViewConfig
    
    private func setupGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            config.colors.0.cgColor,
            config.colors.1.cgColor
        ]
        gradientLayer.startPoint = config.points.0
        gradientLayer.endPoint = config.points.1
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradientLayer = layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = bounds
        }
    }
}
