//
//  UILabel+Extension.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/19.
//

import UIKit

extension UILabel {
    func setTextOrHideIfNilOrEmpty(_ text: String?) {
        if let text, !text.isEmpty {
            isHidden = false
            self.text = text
        } else {
            isHidden = true
        }
    }
}
