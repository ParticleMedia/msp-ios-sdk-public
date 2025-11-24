//
//  NovaAdPlayableTopBar.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit

// MARK: - NovaAdPlayableTopBar

class NovaAdPlayableTopBar: UIView {
    // MARK: Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Internal
    var didTapClose: (() -> Void)?

    func configure(title: String) {
        titleLabel.text = title
    }
    
    // MARK: Private
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.9)
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        let image = UIImage.Nova.crossCircleFilled?.withTintColor(NovaColorPalettes.White, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
    }()
    
    private func setupUI() {
        backgroundColor = NovaColorPalettes.Gray.tint900
        
        addSubview(titleLabel)
        addSubview(closeButton)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-16)
        }
        
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(titleLabel.snp.centerY)
            make.width.height.equalTo(24)
        }
    }
    
    @objc private func didTapCloseButton() {
        didTapClose?()
    }
}
