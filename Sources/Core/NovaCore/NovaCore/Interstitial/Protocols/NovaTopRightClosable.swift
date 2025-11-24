//
//  NovaTopRightClosable.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - NovaTopRightClosable

protocol NovaTopRightClosable: AnyObject {
    var countdownTimer: Timer? { get set }
    var countdownSecondRemaining: Int { get }
    var topRightCloseButton: UIButton  { get }
    var topRightCloseButtonArea: UIView { get }
    var darkColor: UIColor { get }
    func setupCountdownTimerIfNeeded()
    func enableCloseButtonIfNeeded()
}

extension NovaTopRightClosable {
    func setupCountdownTimerIfNeeded() {
        if countdownSecondRemaining > 0 {
            topRightCloseButtonStartCountDown(button: topRightCloseButton, clickableArea: topRightCloseButtonArea, countdownSeconds: countdownSecondRemaining)
        } else {
            enableTopRightCloseButton(button: topRightCloseButton, clickableArea: topRightCloseButtonArea)
        }
    }
    
    func enableCloseButtonIfNeeded() {
        enableTopRightCloseButton(button: topRightCloseButton, clickableArea: topRightCloseButtonArea)
    }
    
    private func topRightCloseButtonStartCountDown(button: UIButton, clickableArea: UIView, countdownSeconds: Int) {
        var remainingSeconds = countdownSeconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                clickableArea.isUserInteractionEnabled = false
                button.setTitle("\(remainingSeconds)", for: .normal)
            } else {
                self.enableTopRightCloseButton(button: button, clickableArea: clickableArea)
            }
            remainingSeconds -= 1
        }
        countdownTimer?.fire()
    }
    
    private func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        clickableArea.isUserInteractionEnabled = true
        self.countdownTimer?.invalidate()
        button.setTitle(nil, for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: darkColor), renderingMode: .alwaysOriginal), for: .normal)
    }
}
