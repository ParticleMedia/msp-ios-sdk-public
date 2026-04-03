//
//  NovaTopRightClosable.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaTopRightClosable

import Foundation
import UIKit

protocol NovaTopRightClosable: AnyObject {
    var countdownTimer: Timer? { get set }
    var delayTimer: Timer? { get set }
    var countdownSecondRemaining: Int { get set }
    var delaySecondRemaining: Int? { get set }
    var topRightCloseButton: UIButton { get }
    var topRightCloseButtonArea: UIView { get }
    var darkColor: UIColor { get }
    var backgroundObserver: NSObjectProtocol? { get set }
    var foregroundObserver: NSObjectProtocol? { get set }
    func setupCountdownTimerIfNeeded()
    func enableCloseButtonIfNeeded()
    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView)
    func teardownCountdown()
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
            delaySecondRemaining > 0
        {
            topRightCloseButton.isHidden = true
            delayStartCountDown(delaySeconds: delaySecondRemaining)
        } else {
            topRightCloseButton.isHidden = false
            setupCountdownTimerIfNeeded()
        }
    }

    private func topRightCloseButtonStartCountDown(button: UIButton, clickableArea: UIView) {
        countdownTimer?.invalidate()
        removeAppLifecycleObservers()

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
                self?.removeAppLifecycleObservers()
                self?.enableTopRightCloseButton(button: button, clickableArea: clickableArea)
            }
        }

        RunLoop.main.add(countdownTimer!, forMode: .common)

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.countdownTimer?.invalidate()
            self?.countdownTimer = nil
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.countdownSecondRemaining > 0 else { return }
            self.topRightCloseButtonStartCountDown(button: self.topRightCloseButton, clickableArea: self.topRightCloseButtonArea)
        }
    }

    private func removeAppLifecycleObservers() {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
            foregroundObserver = nil
        }
    }

    private func delayStartCountDown(delaySeconds: Int) {
        delaySecondRemaining = delaySeconds
        delayTimer?.invalidate()
        removeAppLifecycleObservers()

        delayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let remaining = (self.delaySecondRemaining ?? 0) - 1
            self.delaySecondRemaining = remaining
            if remaining <= 0 {
                self.delayTimer?.invalidate()
                self.delayTimer = nil
                self.removeAppLifecycleObservers()
                self.setupCountdownTimerIfNeeded()
            }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.delayTimer?.invalidate()
            self?.delayTimer = nil
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let remaining = self.delaySecondRemaining, remaining > 0 else { return }
            self.delayStartCountDown(delaySeconds: remaining)
        }
    }

    func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        topRightCloseButton.isHidden = false
        clickableArea.isUserInteractionEnabled = true
        self.countdownTimer?.invalidate()
        button.setTitle(nil, for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(
            UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(
                UIColor(light: NovaColorPalettes.Gray.tint600, dark: darkColor), renderingMode: .alwaysOriginal),
            for: .normal)
    }

    func teardownCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        delayTimer?.invalidate()
        delayTimer = nil
        removeAppLifecycleObservers()
    }
}
