//
//  NovaInterstitialAdSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - NovaInterstitialAdSubviewHandler

protocol NovaInterstitialAdSubviewHandler {
    func setupSubviews(in containerView: UIView, showReportButton: Bool)
    func config()
    var clickableViews: [UIView] { get }
    
    // Optional methods
    func didAppear()
    func didDisappear()
    func willAppear()
    func willDisappear()
    func configPage(pageIndex: Int, htmlActionDelegate: NovaAdHtmlActionDelegate?, context: NovaInterstitialAdContext?)
}

// MARK: - Default Implementation

extension NovaInterstitialAdSubviewHandler {
    func didAppear() {}
    func didDisappear() {}
    func willAppear() {}
    func willDisappear() {}
    func configPage(pageIndex: Int, htmlActionDelegate: NovaAdHtmlActionDelegate?, context: NovaInterstitialAdContext?) {}
}
