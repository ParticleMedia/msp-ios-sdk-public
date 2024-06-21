//
//  CheckBoxButton.swift
//  NBDesignSystem
//
//  Created by Wei Wu (iOS) on 5/3/24.
//

import Foundation
import UIKit

public class CheckBoxButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setImage(UIImage(named: "checkbox_checked", in: Asset.getBundle(), compatibleWith: nil), for: .selected)
        self.setImage(UIImage(named: "checkbox_unchecked", in: Asset.getBundle(), compatibleWith: nil), for: .normal)
        self.addTarget(self, action: #selector(CheckBoxButton.buttonClicked(_:)), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func buttonClicked(_ sender: UIButton) {
        self.isSelected = !self.isSelected
    }
}
