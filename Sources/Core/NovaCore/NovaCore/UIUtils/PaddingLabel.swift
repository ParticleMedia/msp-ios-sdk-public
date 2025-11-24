//
//  PaddingLabel.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/9/2.
//

import UIKit

class PaddedLabel: UILabel {

    var textInsets = UIEdgeInsets.zero {
        didSet {
            setNeedsDisplay()
        }
    }

    override func drawText(in rect: CGRect) {
        let insetRect = rect.inset(by: textInsets)
        super.drawText(in: insetRect)
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let adjustedSize = CGSize(width: size.width - textInsets.left - textInsets.right,
                                  height: size.height - textInsets.top - textInsets.bottom)
        let superSize = super.sizeThatFits(adjustedSize)
        return CGSize(width: superSize.width + textInsets.left + textInsets.right,
                      height: superSize.height + textInsets.top + textInsets.bottom)
    }
}

