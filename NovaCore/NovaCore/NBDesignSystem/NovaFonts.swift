//
//  Fonts.swift
//  Pods
//
//  Created by Wei Wu on 6/7/23.
//

import Foundation
import SwiftUI

// https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?type=design&node-id=118-1818&mode=design&t=V4Ya56QB07TW2wVs-0
public extension Font {
    class NovaFont {
        public let display1 = Font.system(size: 24, weight: .black)
        public let display2 = Font.system(size: 16, weight: .black)
        public let headline1 = Font.system(size: 20, weight: .bold)
        public let headline2 = Font.system(size: 18, weight: .bold)
        public let headline3 = Font.system(size: 16, weight: .bold)
        public let body1 = Font.system(size: 16, weight: .regular)
        public let body2 = Font.system(size: 14, weight: .regular)
        public let bodyTablet = Font.system(size: 18, weight: .regular)
        public let subtitle1 = Font.system(size: 14, weight: .semibold)
        public let subtitle2 = Font.system(size: 14, weight: .bold)
        public let subtitle3 = Font.system(size: 13, weight: .bold)
        public let caption1 = Font.system(size: 12, weight: .regular)
        public let caption2 = Font.system(size: 11, weight: .regular)
    }
    
    static let Nova = NovaFont()
}
