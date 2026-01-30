//
//  NovaAdEndCard.swift
//  NBNovaAdComponents
//
//  Created by Shanyu Li on 2025/2/13.
//

import Foundation
import UIKit

protocol NovaAdEndCardDelegate: AnyObject {
    func endCardDidTapCloseButton()

    func endCardDidTapWatchAgainButton()
}

class NovaAdEndCard: UIView {
    enum Style {
        case horizontalDefault
        case verticalDefault
        case immersiveDefault
        case center
    }
    private var subviewHandler: (any NovaAdEndCardSubviewHandling)?
    private weak var delegate: (any NovaAdEndCardDelegate)?

    init(delegate: any NovaAdEndCardDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        backgroundColor = .black.withAlphaComponent(0.75)
        self.adClickArea = .blankEndcard
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func config(with viewModel: NovaAdEndCardViewModel) {
        subviewHandler =
            NovaAdEndCardSubviewHandlerCreator
            .create(with: viewModel.style, delegate: self)
        subviewHandler?.set(on: self)
        subviewHandler?.config(with: viewModel)
    }

    func clickableViews() -> [UIView] {
        (subviewHandler?.clickableViews() ?? []) + [self]
    }
}

extension NovaAdEndCard: NovaAdEndCardSubviewBehaviorDelegate {
    func didTapCloseButton() {
        delegate?.endCardDidTapCloseButton()
    }

    func didTapWatchAgainButton() {
        delegate?.endCardDidTapWatchAgainButton()
    }
}
