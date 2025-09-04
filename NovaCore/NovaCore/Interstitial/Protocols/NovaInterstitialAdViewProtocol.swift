//
//  NovaInterstitialAdViewProtocol.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - NovaInterstitialAdViewProtocol

protocol NovaInterstitialAdViewProtocol: UIView {
    func setupSubviews()
    func didAppear()
    func didDisappear()
    func willAppear()
    func willDisappear()
    func setupCountdownTimerIfNeeded()
    func enableTopRightCloseButtonIfNeeded()
}

// MARK: - Default Implementation

extension NovaInterstitialAdViewProtocol {
    func setupSubviews() {}
    func didAppear() {}
    func didDisappear() {}
    func willAppear() {}
    func willDisappear() {}
    func setupCountdownTimerIfNeeded() {}
    func enableTopRightCloseButtonIfNeeded() {}
}
