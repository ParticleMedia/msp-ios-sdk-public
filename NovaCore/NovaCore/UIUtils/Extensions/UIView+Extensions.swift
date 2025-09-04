//
//  UIView+Extensions.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation
import UIKit

extension UIView {

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

// Clickable Area
enum ClickableAdArea: String {
    case icon
    case advertiser
    case sponsor
    case headline
    case body
    case cta
    case media
    case badge
    case shadow
    // engagement signal
    case like
    case comment
    case share
    // end card
    case advertiser_endcard
    case body_endcard
    case cta_endcard
    case icon_endcard
    case blank_endcard
    // playable ad
    case tap_to_try
    case playable
    // using to simulate a click action
    case auto_jump
    // immersive popover
    case cta_popover
}

extension UIView {
    private static var adClickAreaKey: UInt8 = 0
    var adClickArea: ClickableAdArea? {
        get {
            return objc_getAssociatedObject(self, &Self.adClickAreaKey) as? ClickableAdArea
        }
        set {
            objc_setAssociatedObject(self, &Self.adClickAreaKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// Visible on Screen
extension UIView {
    var frameInWindow: CGRect {
        convert(frame, to: window)
    }
    
    var onTop: Bool {
        guard let window else {
            return false
        }

        // Convert the center point of the view to the window's coordinate space
        let centerPointInWindow = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: window)

        // Check which view is at the center point
        if let hitView = window.hitTest(centerPointInWindow, with: nil) {
            // Check if the hit view is the view itself or a subview of it
            return hitView.isDescendant(of: self)
        }

        return false
    }

    var novaIsFullyVisibleOnScreen: Bool {
        return novaIsVisibleOnScreen(partially: false)
    }

    var novaIsPartiallyVisibleOnScreen: Bool {
        return novaIsVisibleOnScreen(partially: true)
    }

    private func novaIsVisibleOnScreen(partially: Bool) -> Bool {
        if isHidden  {
            return false
        }
        
        if alpha == 0 {
            return false
        }
        
        if superview == nil {
            return false
        }
        
        if window == nil {
            return false
        }

        guard let rootViewController = UIApplication.novaKeyRootViewController else {
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
}
