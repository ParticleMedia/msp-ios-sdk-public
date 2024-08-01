//
//  UIView+Extensions.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation
import UIKit

public extension UIView {

    static func ignoreAutoresizing(_ views: [UIView]) {
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
    }
    static func ignoreAutoresizing(_ views: UIView...) { ignoreAutoresizing(views) }

    func addSubviews(_ views: [UIView]) { views.forEach(addSubview(_:)) }
    func addSubviews(_ views: UIView...) { addSubviews(views) }

    func addSubviewsAndIgnoreAutoResizing(_ views: [UIView]) {
        addSubviews(views)
        UIView.ignoreAutoresizing(views)
    }
    func addSubviewsAndIgnoreAutoResizing(_ views: UIView...) { addSubviewsAndIgnoreAutoResizing(views) }
}

// MARK: Standard Apple values
public extension UIView {
    static let minTapLength: CGFloat = 44
    var minTapLength: CGFloat { UIView.minTapLength }
}

extension UIView {
    public var nova_isFullyVisibleOnScreen: Bool {
        return novaisVisibleOnScreen(partially: false)
    }

    @objc public var nova_isPartiallyVisibleOnScreen: Bool {
        return novaisVisibleOnScreen(partially: true)
    }

    private func novaisVisibleOnScreen(partially: Bool) -> Bool {
        if isHidden || alpha == 0 || superview == nil || window == nil {
            return false
        }

        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return false
        }

        let viewFrame = convert(bounds, to: rootViewController.view)

        let topSafeArea = rootViewController.view.safeAreaInsets.top
        let bottomSafeArea = rootViewController.view.safeAreaInsets.bottom
        let rootViewBounds = CGRect(x: 0,
                                    y: topSafeArea,
                                    width: rootViewController.view.bounds.width,
                                    height: rootViewController.view.bounds.height - topSafeArea - bottomSafeArea)

        if partially {
            return rootViewBounds.intersects(viewFrame)
        } else {
            return rootViewBounds.contains(viewFrame)
        }
    }

    // Should log view impression
    public func novaisCheckedView() -> Bool {
        return novagetVisiblePercentage() >= 50
    }

    private func novagetVisiblePercentage() -> Double {
        if isHidden || alpha == 0 || superview == nil || window == nil {
            return 0
        }

        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return 0
        }

        let viewFrame = convert(bounds, to: rootViewController.view)

        let topSafeArea = rootViewController.view.safeAreaInsets.top
        let bottomSafeArea = rootViewController.view.safeAreaInsets.bottom
        let rootViewBounds = CGRect(x: 0,
                                    y: topSafeArea,
                                    width: rootViewController.view.bounds.width,
                                    height: rootViewController.view.bounds.height - topSafeArea - bottomSafeArea)

        let intersection = rootViewBounds.intersection(viewFrame)
        return 100 * intersection.width * intersection.height / viewFrame.width / viewFrame.height
    }
}

// MARK: - Shadow

extension UIView {
    public func novasetShadow(x: Double, y: Double, b: Double, s: Double, color: UIColor, alpha: Float) {
        let rect = bounds.insetBy(dx: -s, dy: -s)
        layer.shadowPath = UIBezierPath(rect: rect).cgPath
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = alpha
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowRadius = b
    }
}

extension UIView {
    public func novapinConstraints() -> [NSLayoutConstraint] {
        guard let parentView = superview else {
            return []
        }
        return [
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            topAnchor.constraint(equalTo: parentView.topAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ]
    }

    public func novapinToSuperView() {
        NSLayoutConstraint.activate(novapinConstraints())
    }
}
