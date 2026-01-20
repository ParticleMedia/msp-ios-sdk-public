//
//  NovaAdPassThroughTapView.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/18.
//

import UIKit

class NovaAdPassThroughTapView: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    var passThroughTapHandler: (() -> Void)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // event can pass to underlay views
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            passThroughTapHandler?()
            return nil
        }
        return hitView
    }
}
