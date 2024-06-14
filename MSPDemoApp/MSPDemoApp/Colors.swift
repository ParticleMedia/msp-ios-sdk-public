//
//  Colors.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 6/13/24.
//

import Foundation
import UIKit


public extension UIColor {

    @objc convenience init(light: UIColor, dark: UIColor) {
        self.init(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light })
    }

    convenience init?(light: String, dark: String) {
        guard let lightColor = UIColor(hex: light), let darkColor = UIColor(hex: dark) else {
            return nil
        }

        self.init(light: lightColor, dark: darkColor)
    }

    convenience init?(red: Int, green: Int, blue: Int, alpha: CGFloat = 1) {
        guard red >= 0, red <= 255 else {
            return nil
        }

        guard green >= 0, green <= 255 else {
            return nil
        }

        guard blue >= 0, blue <= 255 else {
            return nil
        }

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
    }

    convenience init?(hex: String, alpha: CGFloat = 1) {
        var string = hex
        if string.hasPrefix("0x") {
            string.removeFirst(2)
        } else if string.hasPrefix("0X") {
            string.removeFirst(2)
        } else if string.hasPrefix("#") {
            string.removeFirst(1)
        }

        guard let hexValue = Int(string, radix: 16) else {
            assertionFailure("invalid color format for [\(hex)]")
            return nil
        }

        if string.count == 8 {
            let red = (hexValue >> 24) & 0xFF
            let green = (hexValue >> 16) & 0xFF
            let blue = (hexValue >> 8) & 0xFF
            let alphaValue = CGFloat(hexValue & 0xFF) / 255.0
            self.init(red: red, green: green, blue: blue, alpha: alphaValue)
        } else {
            let red = (hexValue >> 16) & 0xFF
            let green = (hexValue >> 8) & 0xFF
            let blue = hexValue & 0xFF
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    convenience init?(ARGB: String) {
        var string = ARGB
        if string.hasPrefix("0x") {
            string.removeFirst(2)
        } else if string.hasPrefix("0X") {
            string.removeFirst(2)
        } else if string.hasPrefix("#") {
            string.removeFirst(1)
        }

        guard let hexValue = Int(string, radix: 16) else {
            assertionFailure("invalid color format for [\(ARGB)]")
            return nil
        }
        let alphaValue = CGFloat((hexValue >> 24) & 0xFF) / 255.0
        let red = (hexValue >> 16) & 0xFF
        let green = (hexValue >> 8) & 0xFF
        let blue = hexValue & 0xFF
        self.init(red: red, green: green, blue: blue, alpha: alphaValue)
    }
    
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r,g,b,a)
        }
        return (0, 0, 0, 0)
    }

    // hue, saturation, brightness and alpha components from UIColor**
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return (hue, saturation, brightness, alpha)
        }
        return (0,0,0,0)
    }

    var htmlRGB: String {
        let rgbaCache = rgba
        return String(format: "#%02x%02x%02x", Int(round(rgbaCache.red * 255)), Int(round(rgbaCache.green * 255)), Int(round(rgbaCache.blue * 255)))
    }

    var htmlRGBA: String {
        let rgbaCache = rgba
        return String(format: "#%02x%02x%02x%02x", Int(round(rgbaCache.red * 255)), Int(round(rgbaCache.green * 255)), Int(round(rgbaCache.blue * 255)), Int(round(rgbaCache.alpha * 255)) )
    }
    
//    class var PrimaryText: UIColor {
//        return UIColor(light: Palettes.Gray.tint800, dark: Palettes.Gray.tint200)
//    }
//
//    class var SecondaryText: UIColor {
//        return UIColor(light: Palettes.Gray.tint500, dark: Palettes.Gray.tint400)
//    }
    
//    class var NBRed: UIColor {
//        return Palettes.App.tint400
//    }
    
    
}
