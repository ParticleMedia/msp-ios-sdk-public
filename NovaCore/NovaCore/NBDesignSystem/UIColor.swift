//
//  UIColor.swift
//  NBDesignSystem
//
//  Created by Wei Wu (iOS) on 11/17/23.
//

import Foundation
import UIKit
public extension UIColor {
    class NovaUIColor {
        // https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?node-id=1%3A325&mode=dev
        
        // App 400 FF5A5A
        public let newsbreakRed = UIColor(named: "Newsbreak Red", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 800 242424 Gray 200 E3E3E3
        public let primaryText = UIColor(named: "Primary Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 500 656565 Gray 400 9B9B9B
        public let secondaryText = UIColor(named: "Secondary Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Black 000000 30% White 000000 30%
        public let disabledText = UIColor(named: "Disabled Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // White FFFFFF Gray 900 121212
        public let primarySurface = UIColor(named: "Primary Surface", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 050 FAFAFA Gray 800 242424
        public let secondarySurface = UIColor(named: "Secondary Surface", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 200 E3E3E3 Gray 800 242424
        public let divider = UIColor(named: "Divider", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Yellow 500 FF9900
        public let errorLevel1 = UIColor(named: "Error-Level 1", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Orange 500 F56A2E
        public let errorLevel2 = UIColor(named: "Error-Level 2", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // App 500 D34343
        public let errorLevel3 = UIColor(named: "Error-Level 3", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Green 500 099D5F
        public let success = UIColor(named: "Success", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Blue 200 67B2FB
        public let progress = UIColor(named: "Progress", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Blue 500 017EF9 5%
        public let unread = UIColor(named: "Unread", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Blue 500 017EF9 Blue 300 3498FA
        public let textButton = UIColor(named: "Text button", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Blue 500 017EF9 70% Blue 300 3498FA 70%
        public let textButtonPressed = UIColor(named: "Text button pressed", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 200 E3E3E3
        public let linkText = UIColor(named: "Link Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Black 000000 60%
        public let linkBannerBackground = UIColor(named: "Link Banner Background", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 500 656565
        public let tagText = UIColor(named: "Tag Text", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Blue 100 E6F2FE Blue 900 202F3E
        public let tagBackground = UIColor(named: "Tag Background", in: NovaAsset.getBundle(), compatibleWith: nil)!
        
        // Gray 100 F2F2F2 Gray 800 242424
        public let primaryDividerDeprecated = UIColor(named: "Primary Divider", in: NovaAsset.getBundle(), compatibleWith: nil)!
        // Gray 200 E3E3E3 Black 000000
        public let secondaryDividerDeprecated = UIColor(named: "Secondary Divider", in: NovaAsset.getBundle(), compatibleWith: nil)!
    }
    
    static let Nova = NovaUIColor()
}
