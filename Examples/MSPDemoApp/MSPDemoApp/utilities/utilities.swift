//
//  utilities.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 4/6/26.
//
import UIKit
import MSPSnapKit

public func showToast(_ message: String, from viewController: UIViewController) {
    let container = UIView()
    container.backgroundColor = UIColor.label.withAlphaComponent(0.8)
    container.layer.cornerRadius = 16
    container.clipsToBounds = true

    let label = UILabel()
    label.text = message
    label.textColor = .systemBackground
    label.font = .systemFont(ofSize: 14, weight: .medium)

    container.addSubview(label)
    label.snp.makeConstraints { make in
        make.top.bottom.equalToSuperview().inset(8)
        make.leading.trailing.equalToSuperview().inset(16)
    }
    
    let parentView: UIView
    if let presented = viewController.presentedViewController {
        parentView = presented.view
    } else {
        parentView = viewController.view
    }

    parentView.addSubview(container)
    container.snp.makeConstraints { make in
        make.centerX.equalToSuperview()
        make.bottom.equalTo(parentView.safeAreaLayoutGuide).offset(-32)
    }

    container.alpha = 0
    UIView.animate(withDuration: 0.2) {
        container.alpha = 1
    } completion: { _ in
        UIView.animate(withDuration: 0.3, delay: 1.2) {
            container.alpha = 0
        } completion: { _ in
            container.removeFromSuperview()
        }
    }
}
