//
//  Fonts.swift
//  Pods
//
//  Created by Wei Wu on 6/7/23.
//

import SwiftUI

// https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?type=design&node-id=118-1818&mode=design&t=V4Ya56QB07TW2wVs-0
extension Font {
    class NovaFont {
        let display1 = Font.system(size: 24, weight: .black)
        let display2 = Font.system(size: 16, weight: .black)
        let headline1 = Font.system(size: 20, weight: .bold)
        let headline2 = Font.system(size: 18, weight: .bold)
        let headline3 = Font.system(size: 16, weight: .bold)
        let body1 = Font.system(size: 16, weight: .regular)
        let body2 = Font.system(size: 14, weight: .regular)
        let bodyTablet = Font.system(size: 18, weight: .regular)
        let subtitle1 = Font.system(size: 14, weight: .semibold)
        let subtitle2 = Font.system(size: 14, weight: .bold)
        let subtitle3 = Font.system(size: 13, weight: .bold)
        let caption1 = Font.system(size: 12, weight: .regular)
        let caption2 = Font.system(size: 11, weight: .regular)
    }
    
    static let Nova = NovaFont()
}
