//
//  NovaNativeAdMultipleImagesIndicator.swift
//  NBNovaAds
//
//  Created by Shanyu Li on 2024/8/5.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit

protocol NovaAdMultipleImagesIndicatorDelegate: AnyObject {
    func multipleImagesIndicator(_ imagesIndicator: NovaAdMultipleImagesIndicator, didTapIndex: Int)
}

struct MultipleImagesIndicatorConfig {
    let count: Int
    let progressColor: UIColor
    let trackColor: UIColor
    let cornerRadius: CGFloat?

    init(
        count: Int,
        progressColor: UIColor = NovaColorPalettes.Gray.tint100,
        trackColor: UIColor = NovaColorPalettes.Gray.tint400,
        cornerRadius: CGFloat? = nil
    ) {
        self.count = count
        self.progressColor = progressColor
        self.trackColor = trackColor
        self.cornerRadius = cornerRadius
    }
}

class NovaAdMultipleImagesIndicator: UIView {
    private lazy var indicatorView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 4.0
        view.distribution = .fillEqually
        view.alignment = .fill
        return view
    }()

    private var indicators: [UIProgressView] = []
    weak var delegate: NovaAdMultipleImagesIndicatorDelegate?
    private var config: MultipleImagesIndicatorConfig?

    init() {
        super.init(frame: .zero)

        addSubviews(indicatorView)
        indicatorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(with config: MultipleImagesIndicatorConfig) {
        self.config = config
        for _ in 0..<config.count {
            let progressView = UIProgressView()
            progressView.progressTintColor = config.progressColor
            progressView.trackTintColor = config.trackColor
            if let cornerRadius = config.cornerRadius {
                progressView.layer.cornerRadius = cornerRadius
                progressView.clipsToBounds = true
            }
            indicators.append(progressView)
            indicatorView.addArrangedSubview(progressView)
        }
        setIndicator(to: 0, progress: 0.0)
    }

    func setIndicator(to index: Int, progress: Float) {
        guard 0 <= index, index < indicators.count else {
            return
        }
        for (i, progressView) in indicators.enumerated() {
            if i < index {
                progressView.setProgress(1.0, animated: false)
            } else if i == index {
                progressView.setProgress(progress, animated: false)
            } else {
                progressView.setProgress(0, animated: false)
            }
        }
    }
}
