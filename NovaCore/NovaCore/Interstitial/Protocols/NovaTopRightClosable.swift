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
    var delayTimer: Timer? { get set }
    var countdownSecondRemaining: Int { get set }
    var delaySecondRemaining: Int? { get }
    var topRightCloseButton: UIButton  { get }
    var topRightCloseButtonArea: UIView { get }
    var darkColor: UIColor { get }
    func setupCountdownTimerIfNeeded()
    func enableCloseButtonIfNeeded()
    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView)
}

enum NovaTopRightCloseButtonStyle {
    case closeInHorizontal
    case closeInVertical
    case skipInHorizontal
    case skipInVertical
}

extension NovaTopRightClosable {
    func setupCountdownTimerIfNeeded() {
        if countdownSecondRemaining > 0 {
            topRightCloseButton.isHidden = false
            topRightCloseButtonStartCountDown(button: topRightCloseButton, clickableArea: topRightCloseButtonArea)
        } else {
            enableTopRightCloseButton(button: topRightCloseButton, clickableArea: topRightCloseButtonArea)
        }
    }
    
    func enableCloseButtonIfNeeded() {
        enableTopRightCloseButton(button: topRightCloseButton, clickableArea: topRightCloseButtonArea)
    }
    
    func setupDelayTimerIfNeeded() {
        if let delaySecondRemaining = delaySecondRemaining,
           delaySecondRemaining > 0 {
            topRightCloseButton.isHidden = true
            delayStartCountDown(delaySeconds: delaySecondRemaining)
        } else {
            setupCountdownTimerIfNeeded()
        }
    }
    
    private func topRightCloseButtonStartCountDown(button: UIButton, clickableArea: UIView) {
        countdownTimer?.invalidate()
        
            let endTime = Date().addingTimeInterval(TimeInterval(countdownSecondRemaining))

            // Immediately show first number
            clickableArea.isUserInteractionEnabled = false
            button.setTitle("\(countdownSecondRemaining)", for: .normal)

            countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
                let remaining = Int(endTime.timeIntervalSinceNow.rounded(.up))
                self?.countdownSecondRemaining = remaining
                // Timer still running
                if remaining > 0 {
                    button.setTitle("\(remaining)", for: .normal)
                } else {
                    timer.invalidate()
                    self?.enableTopRightCloseButton(button: button, clickableArea: clickableArea)
                }
            }

            RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    private func delayStartCountDown(delaySeconds: Int) {
        var remainingSeconds = delaySeconds
        delayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            remainingSeconds -= 1
            if remainingSeconds > 0 {
                
            } else {
                self.delayTimer?.invalidate()
                self.setupCountdownTimerIfNeeded()
            }
        }
    }
    
    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        clickableArea.isUserInteractionEnabled = true
        self.countdownTimer?.invalidate()
        button.setTitle(nil, for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: darkColor), renderingMode: .alwaysOriginal), for: .normal)
    }
}
