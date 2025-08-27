//
//  UIColor.swift
//  NBDesignSystem
//
//  Created by Wei Wu (iOS) on 11/17/23.
//

import Foundation
import UIKit
extension UIColor {
    class NovaUIColor {
        // https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?node-id=1%3A325&mode=dev

       // Gray 800 242424 Gray 200 E3E3E3
        let primaryText = UIColor(named: "Primary Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 200 E3E3E3 Black 000000
        let secondaryDivider = UIColor(named: "Secondary Divider", in: NovaAsset.getBundle(), compatibleWith: nil)!
    }
    
    static let Nova = NovaUIColor()
}
