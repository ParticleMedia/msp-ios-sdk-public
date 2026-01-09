//
//  NovaAdPopOverView.swift
//  NBNovaAdComponents
//
//  Created by Shanyu Li on 2025/7/15.
//

import Foundation
import UIKit

class NovaAdPopOverView: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(popoverStack)
        popoverStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Constants.padding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.padding)
            make.bottom.equalToSuperview().offset(-Constants.popoverBottomPadding)
        }
        adClickArea = .cta_popover
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct ExtraLayoutConfig {
        let safeAreaInsets: UIEdgeInsets
        let exclusionRects: [CGRect]
    }

    // MARK: Public

    enum State {
        case hide
        case pop(sourceView: UIView, sourcePoint: CGPoint, extraLayoutConfig: ExtraLayoutConfig)
    }

    func config(with title: String) {
        label.text = title
    }

    func changeState(to state: State) {
        switch state {
        case .hide:
            removeFromSuperview()
        case let .pop(sourceView, sourcePoint, extraLayoutConfig):
            sourceView.addSubview(self)
            isHidden = false

            let insets = extraLayoutConfig.safeAreaInsets
            let minX = insets.left + Constants.padding
            let maxX = sourceView.frame.width - insets.right - Constants.padding - Constants.popoverWidth

            let leadingOffset: Double = if sourcePoint.x < minX {
                minX
            } else if sourcePoint.x > maxX {
                maxX
            } else {
                sourcePoint.x
            }

            let maxY = sourceView.frame.height - insets.bottom - Constants.popoverHeight
            let topOffset: Double = min(sourcePoint.y, maxY)

            snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(topOffset)
                make.leading.equalToSuperview().offset(leadingOffset)
            }
        }
    }

    // MARK: Internal

    enum Constants {
        static let popoverWidth: Double = 124
        static let popoverHeight: Double = 42
        static let popoverSpacing: Double = 4.0
        static let arrowSize: Double = 16
        static let popoverBottomPadding: Double = 12.0
        static let padding: Double = 8.0
    }

    // MARK: Private

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .Nova.popOver?.imageByResize(
            to: CGSize(width: Constants.popoverWidth, height: Constants.popoverHeight)
        )
        return imageView
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.Black.withAlphaComponent(0.85)
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView(image: .Nova.chevronRightLine?.withTintColor(NovaColorPalettes.Black))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var popoverStack = {
        let stackView = UIStackView(arrangedSubviews: [label, arrowImageView])
        arrowImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.arrowSize)
        }
        stackView.axis = .horizontal
        stackView.spacing = Constants.popoverSpacing
        stackView.alignment = .center
        return stackView
    }()
}
