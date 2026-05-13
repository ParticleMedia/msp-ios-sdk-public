//
//  DebugToast.swift
//  MSPDemoApp
//
//  Lightweight bottom-screen toast for QA / DemoApp callback visibility
//  (e.g. confirming JS bridge fired). Not for production SDK use.
//

import UIKit

extension UIViewController {
    /// Shows an auto-dismissing toast at the bottom of the screen. Safe to call from
    /// any thread — hops to main internally. Multiple calls stack vertically.
    func showDebugToast(_ message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.numberOfLines = 0
            label.textAlignment = .center

            let container = UIView()
            container.backgroundColor = UIColor.black.withAlphaComponent(0.85)
            container.layer.cornerRadius = 10
            container.layer.masksToBounds = true
            container.alpha = 0
            container.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            self.view.addSubview(container)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

                container.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                container.leadingAnchor.constraint(
                    greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(
                    lessThanOrEqualTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(
                    equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            ])

            UIView.animate(withDuration: 0.2) { container.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(
                    withDuration: 0.3,
                    animations: { container.alpha = 0 },
                    completion: { _ in container.removeFromSuperview() }
                )
            }
        }
    }
}
