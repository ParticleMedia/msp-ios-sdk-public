//
//  NovaInterstitialAdViewProtocol.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaInterstitialAdViewProtocol

import Foundation
import UIKit

protocol NovaInterstitialAdViewProtocol: UIView {
    func setupSubviews()
    func didAppear()
    func didDisappear()
    func willAppear()
    func willDisappear()
    func setupCountdownTimerIfNeeded()
    func enableTopRightCloseButtonIfNeeded()
    func willTransit()
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
    func willTransit() {}
}
