//
//  UIFont.swift
//  NBDesignSystem
//
//  Created by Wei Wu (iOS) on 11/21/23.
//

import Foundation
import UIKit
// https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?type=design&node-id=118-1818&mode=design&t=V4Ya56QB07TW2wVs-0
public extension UIFont {
    class NovaFont {
        public let display1 = UIFont.systemFont(ofSize: 24, weight: .black)
        public let display2 = UIFont.systemFont(ofSize: 16, weight: .black)
        public let headline1 = UIFont.systemFont(ofSize: 20, weight: .bold)
        public let headline2 = UIFont.systemFont(ofSize: 18, weight: .bold)
        public let headline3 = UIFont.systemFont(ofSize: 16, weight: .bold)
        public let body1 = UIFont.systemFont(ofSize: 16, weight: .regular)
        public let body2 = UIFont.systemFont(ofSize: 14, weight: .regular)
        public let bodyTablet = UIFont.systemFont(ofSize: 18, weight: .regular)
        public let subtitle1 = UIFont.systemFont(ofSize: 14, weight: .semibold)
        public let subtitle2 = UIFont.systemFont(ofSize: 14, weight: .bold)
        public let subtitle3 = UIFont.systemFont(ofSize: 13, weight: .bold)
        public let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
        public let caption2 = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        
        public let deprecated16Heavy = UIFont.systemFont(ofSize: 16, weight: .heavy)
        public let deprecated16Semibold = UIFont.systemFont(ofSize: 16, weight: .semibold)
        public let deprecated16Medium = UIFont.systemFont(ofSize: 16, weight: .medium)
        public let deprecated16Black = UIFont.systemFont(ofSize: 16, weight: .black)
        
        public let deprecated14Medium = UIFont.systemFont(ofSize: 14, weight: .medium)
        public let deprecated14Bold = UIFont.systemFont(ofSize: 14, weight: .bold)
        public let deprecated14Heavy = UIFont.systemFont(ofSize: 14, weight: .heavy)
        
        public let deprecated20Black = UIFont.systemFont(ofSize: 20, weight: .black)
        public let deprecated20Heavy = UIFont.systemFont(ofSize: 20, weight: .heavy)
        public let deprecated20Medium = UIFont.systemFont(ofSize: 20, weight: .medium)
        public let deprecated20Semibold = UIFont.systemFont(ofSize: 20, weight: .semibold)
        public let deprecated20W900 = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight(rawValue: 900))
        
        public let deprecated24Heavy = UIFont.systemFont(ofSize: 24, weight: .heavy)
        public let deprecated24W900 = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight(rawValue: 900))
        public let deprecated24Black = UIFont.systemFont(ofSize: 24, weight: .black)
        public let deprecated24Bold = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        public let deprecated10Regular = UIFont.systemFont(ofSize: 10, weight: .regular)
        public let deprecated10Medium = UIFont.systemFont(ofSize: 10, weight: .medium)
        
        public let deprecated12Medium = UIFont.systemFont(ofSize: 12, weight: .medium)
        public let deprecated12Bold = UIFont.systemFont(ofSize: 12, weight: .bold)
        
        public let deprecated9Regular = UIFont.systemFont(ofSize: 9, weight: .regular)
        
        public let deprecated15Regular = UIFont.systemFont(ofSize: 15, weight: .regular)
    }
    
    static let Nova = NovaFont()
}
