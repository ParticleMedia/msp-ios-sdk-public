//
//  NovaInterstitialAdSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaInterstitialAdSubviewHandler

import Foundation
import UIKit

protocol NovaInterstitialAdSubviewHandler {
    func setupSubviews(in containerView: UIView, showReportButton: Bool)
    func config()
    var clickableViews: [UIView] { get }

    // Optional methods
    func didAppear()
    func didDisappear()
    func willAppear()
    func willDisappear()
    func willTransit(in containerView: UIView)
}

// MARK: - Default Implementation

extension NovaInterstitialAdSubviewHandler {
    func didAppear() {}
    func didDisappear() {}
    func willAppear() {}
    func willDisappear() {}
    func willTransit(in containerView: UIView) {}
}
