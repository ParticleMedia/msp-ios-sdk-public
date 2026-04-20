//
//  NovaCustomCTAAnimationView.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 4/7/26.
//

import UIKit

public class NovaCustomCTAAnimationView: UIView {
    
    public init() {
        super.init(frame: .zero)
        self.adClickArea = .tapToTry
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setupSubviews() {
    }

    public func startAnimating() {
    }

    public func stopAnimating() {
    }
}
