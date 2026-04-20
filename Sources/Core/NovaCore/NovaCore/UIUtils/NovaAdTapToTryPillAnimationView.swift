//
//  NovaAdTapToTryPillAnimationView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 4/7/26.
//
import UIKit
@_implementationOnly import MSPSnapKit

public class NovaAdTapToTryPillAnimationView: NovaCustomCTAAnimationView {
    
    private let iconView = UIImageView()
        private let titleView = ShimmerTextView(text: "Tap to try")
        private let arrowView = UIImageView()
        private let stackView = UIStackView()
    


    public override func setupSubviews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.60)
        layer.cornerRadius = 16
        clipsToBounds = true

        iconView.image = UIImage.Nova.gameFilled?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .systemRed
        iconView.contentMode = .scaleAspectFit

        arrowView.image = UIImage(systemName: "chevron.right")
        arrowView.tintColor = .white
        arrowView.contentMode = .scaleAspectFit

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8

        addSubview(stackView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleView)
        stackView.addArrangedSubview(arrowView)

        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        arrowView.setContentHuggingPriority(.required, for: .horizontal)
        arrowView.setContentCompressionResistancePriority(.required, for: .horizontal)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }

        arrowView.snp.makeConstraints { make in
            make.width.equalTo(10)
            make.height.equalTo(16)
        }

        self.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(138.5)
        }
    }
    
    public override func startAnimating() {
        titleView.startShimmer()
        startIconPulse(iconView)
    }

    public override func stopAnimating() {
        titleView.stopShimmer()
        iconView.layer.removeAnimation(forKey: "pulse")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
    func startIconPulse(_ iconView: UIView) {
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

}

class ShimmerTextView: UIView {

    private let dimLabel = UILabel()
    private let brightLabel = UILabel()
    private let maskGradient = CAGradientLayer()

    init(text: String) {
        super.init(frame: .zero)

        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        // Always-visible base: white 0.7
        dimLabel.text = text
        dimLabel.font = font
        dimLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        addSubview(dimLabel)
        dimLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Top layer: full white, masked to reveal dimLabel in the sweep zone
        brightLabel.text = text
        brightLabel.font = font
        brightLabel.textColor = .white
        addSubview(brightLabel)
        brightLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Mask: opaque everywhere except the narrow band → cut a hole for the sweep
        maskGradient.colors = [
            UIColor.white.cgColor,
            UIColor.clear.cgColor,
            UIColor.white.cgColor
        ]
        maskGradient.locations = [-0.8, -0.4, 0.0] as [NSNumber]
        maskGradient.startPoint = CGPoint(x: 0, y: 0.5)
        maskGradient.endPoint = CGPoint(x: 1, y: 0.5)
        brightLabel.layer.mask = maskGradient
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        dimLabel.intrinsicContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dimLabel.frame = bounds
        brightLabel.frame = bounds
        maskGradient.frame = bounds
    }

    func startShimmer() {
        maskGradient.removeAnimation(forKey: "shimmer")

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.8, -0.4, 0.0] as [NSNumber]
        animation.toValue = [1.0, 1.4, 1.8] as [NSNumber]
        animation.duration = 2.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        maskGradient.add(animation, forKey: "shimmer")
    }

    func stopShimmer() {
        maskGradient.removeAnimation(forKey: "shimmer")
    }
}
