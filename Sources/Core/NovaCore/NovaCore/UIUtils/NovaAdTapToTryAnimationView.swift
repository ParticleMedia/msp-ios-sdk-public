//
//  NovaAdTapToTryAnimationView.swift
//  NovaCore
//
//  Pure UIView animation replacement for Lottie-based tap-to-try indicator.
//  Replicates the original animation: hand icon fade-in with rotation,
//  expanding circle ring, then fade-out — all in a 1.83s loop.
//

import UIKit

// MARK: - NovaAdTapToTryAnimationView

final class NovaAdTapToTryAnimationView: UIView {
    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    func play() {
        guard !isAnimating else { return }
        isAnimating = true
        startAnimation()
    }

    func stop() {
        isAnimating = false
        handImageView.layer.removeAllAnimations()
        ringLayer.removeAllAnimations()
        handImageView.alpha = 0
        ringLayer.opacity = 0
    }

    // MARK: Private

    private static let totalDuration: CFTimeInterval = 1.83 // 55 frames at 30fps

    private var isAnimating = false

    private lazy var handImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.Nova.gameFilled
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.alpha = 0
        return imageView
    }()

    private lazy var ringLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 2.7 // 9pt at 240→72 scale
        layer.opacity = 0
        return layer
    }()

    private func setupSubviews() {
        backgroundColor = .clear

        // Ring layer (behind hand)
        layer.addSublayer(ringLayer)

        // Hand icon
        addSubview(handImageView)

        // Drop shadow matching Lottie original
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Hand icon: ~60% of view size, offset slightly toward bottom-right (matching Lottie anchor)
        let handSize = min(bounds.width, bounds.height) * 0.55
        handImageView.frame = CGRect(
            x: center.x - handSize * 0.35,
            y: center.y - handSize * 0.25,
            width: handSize,
            height: handSize
        )

        // Ring path centered
        let ringRadius: CGFloat = min(bounds.width, bounds.height) * 0.35
        ringLayer.path = UIBezierPath(
            arcCenter: center,
            radius: ringRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
        ringLayer.frame = bounds
    }

    // MARK: - Animation

    private func startAnimation() {
        let total = Self.totalDuration

        // ── Hand icon animations ──
        // Fade in: 0→0.17s (frames 0-5)
        let handFadeIn = CABasicAnimation(keyPath: "opacity")
        handFadeIn.fromValue = 0
        handFadeIn.toValue = 1
        handFadeIn.beginTime = 0
        handFadeIn.duration = total * 5.0 / 55.0

        // Hold visible: 0.17→1.27s (frames 5-38)
        let handHold = CABasicAnimation(keyPath: "opacity")
        handHold.fromValue = 1
        handHold.toValue = 1
        handHold.beginTime = total * 5.0 / 55.0
        handHold.duration = total * 33.0 / 55.0

        // Fade out: 1.27→1.57s (frames 38-47)
        let handFadeOut = CABasicAnimation(keyPath: "opacity")
        handFadeOut.fromValue = 1
        handFadeOut.toValue = 0
        handFadeOut.beginTime = total * 38.0 / 55.0
        handFadeOut.duration = total * 9.0 / 55.0

        let handOpacity = CAAnimationGroup()
        handOpacity.animations = [handFadeIn, handHold, handFadeOut]
        handOpacity.duration = total
        handOpacity.repeatCount = .infinity
        handOpacity.isRemovedOnCompletion = false
        handOpacity.fillMode = .forwards

        // Rotation: -7° to -27° over frames 0-12
        let handRotation = CABasicAnimation(keyPath: "transform.rotation.z")
        handRotation.fromValue = -7.0 * .pi / 180.0
        handRotation.toValue = -27.0 * .pi / 180.0
        handRotation.beginTime = 0
        handRotation.duration = total * 12.0 / 55.0
        handRotation.timingFunction = CAMediaTimingFunction(controlPoints: 0.58, 1, 0.42, 0)

        let handRotGroup = CAAnimationGroup()
        handRotGroup.animations = [handRotation]
        handRotGroup.duration = total
        handRotGroup.repeatCount = .infinity
        handRotGroup.isRemovedOnCompletion = false
        handRotGroup.fillMode = .forwards

        handImageView.layer.add(handOpacity, forKey: "handOpacity")
        handImageView.layer.add(handRotGroup, forKey: "handRotation")

        // ── Ring animations ──
        // Scale: 0→2.29 over frames 17-37
        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 0
        ringScale.toValue = 2.29
        ringScale.beginTime = total * 17.0 / 55.0
        ringScale.duration = total * 20.0 / 55.0
        ringScale.timingFunction = CAMediaTimingFunction(controlPoints: 0.58, 1, 0.42, 0)

        // Opacity: 0→1 (frames 17-24), hold (24-32), 1→0 (frames 32-37)
        let ringFadeIn = CABasicAnimation(keyPath: "opacity")
        ringFadeIn.fromValue = 0
        ringFadeIn.toValue = 1
        ringFadeIn.beginTime = total * 17.0 / 55.0
        ringFadeIn.duration = total * 7.0 / 55.0

        let ringHold = CABasicAnimation(keyPath: "opacity")
        ringHold.fromValue = 1
        ringHold.toValue = 1
        ringHold.beginTime = total * 24.0 / 55.0
        ringHold.duration = total * 8.0 / 55.0

        let ringFadeOut = CABasicAnimation(keyPath: "opacity")
        ringFadeOut.fromValue = 1
        ringFadeOut.toValue = 0
        ringFadeOut.beginTime = total * 32.0 / 55.0
        ringFadeOut.duration = total * 5.0 / 55.0

        let ringOpacity = CAAnimationGroup()
        ringOpacity.animations = [ringFadeIn, ringHold, ringFadeOut]
        ringOpacity.duration = total
        ringOpacity.repeatCount = .infinity
        ringOpacity.isRemovedOnCompletion = false
        ringOpacity.fillMode = .forwards

        let ringScaleGroup = CAAnimationGroup()
        ringScaleGroup.animations = [ringScale]
        ringScaleGroup.duration = total
        ringScaleGroup.repeatCount = .infinity
        ringScaleGroup.isRemovedOnCompletion = false
        ringScaleGroup.fillMode = .forwards

        ringLayer.add(ringOpacity, forKey: "ringOpacity")
        ringLayer.add(ringScaleGroup, forKey: "ringScale")
    }
}
