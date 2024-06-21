//
//  Colors.swift
//  Pods
//
//  Created by Wei Wu on 6/7/23.
//

import Foundation
import SwiftUI

public extension Color {
    class NBColor {
        // https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?node-id=1%3A325&mode=dev
        
        // App 400 FF5A5A
        public let newsbreakRed = Color("Newsbreak Red", bundle: Asset.getBundle())
        // Gray 800 242424 Gray 200 E3E3E3
        public let primaryText = Color("Primary Text", bundle: Asset.getBundle())
        // Gray 500 656565 Gray 400 9B9B9B
        public let secondaryText = Color("Secondary Text", bundle: Asset.getBundle())
        // Black 000000 30% White 000000 30%
        public let disabledText = Color("Disabled Text", bundle: Asset.getBundle())
        // White FFFFFF Gray 900 121212
        public let primarySurface = Color("Primary Surface", bundle: Asset.getBundle())
        // Gray 050 FAFAFA Gray 800 242424
        public let secondarySurface = Color("Secondary Surface", bundle: Asset.getBundle())
        // Gray 200 E3E3E3 Gray 800 242424
        public let divider = Color("Divider", bundle: Asset.getBundle())
        // Yellow 500 FF9900
        public let errorLevel1 = Color("Error-Level 1", bundle: Asset.getBundle())
        // Orange 500 F56A2E
        public let errorLevel2 = Color("Error-Level 2", bundle: Asset.getBundle())
        // App 500 D34343
        public let errorLevel3 = Color("Error-Level 3", bundle: Asset.getBundle())
        // Green 500 099D5F
        public let success = Color("Success", bundle: Asset.getBundle())
        // Blue 200 67B2FB
        public let progress = Color("Progress", bundle: Asset.getBundle())
        // Blue 500 017EF9 5%
        public let unread = Color("Unread", bundle: Asset.getBundle())
        // Blue 500 017EF9 Blue 300 3498FA
        public let textButton = Color("Text button", bundle: Asset.getBundle())
        // Blue 500 017EF9 70% Blue 300 3498FA 70%
        public let textButtonPressed = Color("Text button pressed", bundle: Asset.getBundle())
        // Gray 200 E3E3E3
        public let linkText = Color("Link Text", bundle: Asset.getBundle())
        // Black 000000 60%
        public let linkBannerBackground = Color("Link Banner Background", bundle: Asset.getBundle())
        // Gray 500 656565
        public let tagText = Color("Tag Text", bundle: Asset.getBundle())
        // Blue 100 E6F2FE Blue 900 202F3E
        public let tagBackground = Color("Tag Background", bundle: Asset.getBundle())
        
        // Gray 100 F2F2F2 Gray 800 242424
        public let primaryDividerDeprecated = Color("Primary Divider", bundle: Asset.getBundle())
        // Gray 200 E3E3E3 Black 000000
        public let secondaryDividerDeprecated = Color("Secondary Divider", bundle: Asset.getBundle())
    }
    
    static let NB = NBColor()
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
