//
//  UIFont.swift
//  NBDesignSystem
//
//  Created by Wei Wu (iOS) on 11/21/23.
//

import UIKit
// https://www.figma.com/file/QGyK88wpVY510IuIBoE5tX/🟡Foundation-(WIP)?type=design&node-id=118-1818&mode=design&t=V4Ya56QB07TW2wVs-0
extension UIFont {
    class NovaFont {
        let display1 = UIFont.systemFont(ofSize: 24, weight: .black)
        let display2 = UIFont.systemFont(ofSize: 16, weight: .black)
        let headline1 = UIFont.systemFont(ofSize: 20, weight: .bold)
        let headline2 = UIFont.systemFont(ofSize: 18, weight: .bold)
        let headline3 = UIFont.systemFont(ofSize: 16, weight: .bold)
        let body1 = UIFont.systemFont(ofSize: 16, weight: .regular)
        let body2 = UIFont.systemFont(ofSize: 14, weight: .regular)
        let bodyTablet = UIFont.systemFont(ofSize: 18, weight: .regular)
        let subtitle1 = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let subtitle2 = UIFont.systemFont(ofSize: 14, weight: .bold)
        let subtitle3 = UIFont.systemFont(ofSize: 13, weight: .bold)
        let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
        let caption2 = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        
        let deprecated16Heavy = UIFont.systemFont(ofSize: 16, weight: .heavy)
        let deprecated16Semibold = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let deprecated16Medium = UIFont.systemFont(ofSize: 16, weight: .medium)
        let deprecated16Black = UIFont.systemFont(ofSize: 16, weight: .black)
        
        let deprecated14Medium = UIFont.systemFont(ofSize: 14, weight: .medium)
        let deprecated14Bold = UIFont.systemFont(ofSize: 14, weight: .bold)
        let deprecated14Heavy = UIFont.systemFont(ofSize: 14, weight: .heavy)
        
        let deprecated20Black = UIFont.systemFont(ofSize: 20, weight: .black)
        let deprecated20Heavy = UIFont.systemFont(ofSize: 20, weight: .heavy)
        let deprecated20Medium = UIFont.systemFont(ofSize: 20, weight: .medium)
        let deprecated20Semibold = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let deprecated20W900 = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight(rawValue: 900))
        
        let deprecated24Heavy = UIFont.systemFont(ofSize: 24, weight: .heavy)
        let deprecated24W900 = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight(rawValue: 900))
        let deprecated24Black = UIFont.systemFont(ofSize: 24, weight: .black)
        let deprecated24Bold = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        let deprecated10Regular = UIFont.systemFont(ofSize: 10, weight: .regular)
        let deprecated10Medium = UIFont.systemFont(ofSize: 10, weight: .medium)
        
        let deprecated12Medium = UIFont.systemFont(ofSize: 12, weight: .medium)
        let deprecated12Bold = UIFont.systemFont(ofSize: 12, weight: .bold)
        
        let deprecated9Regular = UIFont.systemFont(ofSize: 9, weight: .regular)
        
        let deprecated15Regular = UIFont.systemFont(ofSize: 15, weight: .regular)
    }
    
    static let Nova = NovaFont()
}
