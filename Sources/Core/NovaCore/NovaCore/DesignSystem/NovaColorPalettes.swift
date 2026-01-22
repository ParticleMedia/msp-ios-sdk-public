// MARK: - NovaColorPalettes

/// Standard color palettes are defined at
/// https://www.figma.com/file/az2QtfMgOx1SK2q78WVu71/Design-System---Foundations?node-id=311%3A1224
///
import UIKit

class NovaColorPalettes: NSObject {
    // MARK: Lifecycle

    private init(
        tint50: UIColor,
        tint100: UIColor,
        tint200: UIColor,
        tint300: UIColor,
        tint400: UIColor,
        tint500: UIColor,
        tint600: UIColor,
        tint700: UIColor,
        tint800: UIColor,
        tint900: UIColor,
        tint950: UIColor? = nil
    ) {
        self.tint50 = tint50
        self.tint100 = tint100
        self.tint200 = tint200
        self.tint300 = tint300
        self.tint400 = tint400
        self.tint500 = tint500
        self.tint600 = tint600
        self.tint700 = tint700
        self.tint800 = tint800
        self.tint900 = tint900
        self.tint950 = tint950

        super.init()
    }

    // MARK: Internal

    // Light/Dark Helpers

    // Gray 800 242424 Gray 200 E3E3E3
    static let primaryText: UIColor = .init(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.Gray.tint200)
    // Gray 200 E3E3E3 Black 000000
    static let secondaryDivider: UIColor = .init(light: NovaColorPalettes.Gray.tint300, dark: NovaColorPalettes.Black)
    // Blue 500 017EF9 Blue 300 3498FA
    static let textButton: UIColor = .init(light: NovaColorPalettes.Blue.tint500, dark: NovaColorPalettes.Blue.tint300)
    // White FFFFFF Black 000000
    static let buttonText: UIColor = .init(light: NovaColorPalettes.White, dark: NovaColorPalettes.Black)
    // Black 000000 White FFFFFF
    static let buttonBackground: UIColor = .init(light: NovaColorPalettes.Black, dark: NovaColorPalettes.White)

    static let Black: UIColor = .init(hex: "000000")!

    static let White: UIColor = .init(hex: "FFFFFF")!

    static let Gray: NovaColorPalettes = .init(
        tint50: UIColor(hex: "FAFAFA")!,
        tint100: UIColor(hex: "F2F2F2")!,
        tint200: UIColor(hex: "E3E3E3")!,
        tint300: UIColor(hex: "BDBDBD")!,
        tint400: UIColor(hex: "9B9B9B")!,
        tint500: UIColor(hex: "656565")!,
        tint600: UIColor(hex: "444444")!,
        tint700: UIColor(hex: "282828")!,
        tint800: UIColor(hex: "242424")!,
        tint900: UIColor(hex: "121212")!)

    static let App: NovaColorPalettes = .init(
        tint50: UIColor(hex: "FFEFEF")!,
        tint100: UIColor(hex: "FFCECE")!,
        tint200: UIColor(hex: "FF9C9C")!,
        tint300: UIColor(hex: "FF7B7B")!,
        tint400: UIColor(hex: "FF5A5A")!,
        tint500: UIColor(hex: "D34343")!,
        tint600: UIColor(hex: "A93636")!,
        tint700: UIColor(hex: "7F2828")!,
        tint800: UIColor(hex: "541B1B")!,
        tint900: UIColor(hex: "2A0D0D")!)

    static let Blue: NovaColorPalettes = .init(
        tint50: UIColor(hex: "E6F2FE")!,
        tint100: UIColor(hex: "99CBFD")!,
        tint200: UIColor(hex: "67B2FB")!,
        tint300: UIColor(hex: "3498FA")!,
        tint400: UIColor(hex: "158BFF")!,
        tint500: UIColor(hex: "017EF9")!,
        tint600: UIColor(hex: "0165C7")!,
        tint700: UIColor(hex: "014C95")!,
        tint800: UIColor(hex: "003264")!,
        tint900: UIColor(hex: "001932")!,
        tint950: UIColor(hex: "202F3E")!)

    static let Green: NovaColorPalettes = .init(
        tint50: UIColor(hex: "E6F5EF")!,
        tint100: UIColor(hex: "9DD8BF")!,
        tint200: UIColor(hex: "6BC49F")!,
        tint300: UIColor(hex: "3AB17F")!,
        tint400: UIColor(hex: "08A664")!,
        tint500: UIColor(hex: "099D5F")!,
        tint600: UIColor(hex: "077E4C")!,
        tint700: UIColor(hex: "055E39")!,
        tint800: UIColor(hex: "043F26")!,
        tint900: UIColor(hex: "021F13")!)

    static let Orange: NovaColorPalettes = .init(
        tint50: UIColor(hex: "FEF0EA")!,
        tint100: UIColor(hex: "FBC3AB")!,
        tint200: UIColor(hex: "F9A682")!,
        tint300: UIColor(hex: "F78858")!,
        tint400: UIColor(hex: "FF6C2D")!,
        tint500: UIColor(hex: "F56A2E")!,
        tint600: UIColor(hex: "C45525")!,
        tint700: UIColor(hex: "99431D")!,
        tint800: UIColor(hex: "622A12")!,
        tint900: UIColor(hex: "311509")!)

    static let Yellow: NovaColorPalettes = .init(
        tint50: UIColor(hex: "FFF5E8")!,
        tint100: UIColor(hex: "FFD699")!,
        tint200: UIColor(hex: "FFC266")!,
        tint300: UIColor(hex: "FFAD33")!,
        tint400: UIColor(hex: "FF9D0A")!,
        tint500: UIColor(hex: "FF9900")!,
        tint600: UIColor(hex: "CC7A00")!,
        tint700: UIColor(hex: "995C00")!,
        tint800: UIColor(hex: "663D00")!,
        tint900: UIColor(hex: "331F00")!)

    static let Magenta: NovaColorPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "C75EB6")!,
        tint400: UIColor(hex: "B93AA4")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Purple: NovaColorPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "8A70BB")!,
        tint400: UIColor(hex: "7251B1")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Skyblue: NovaColorPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "57A5D2")!,
        tint400: UIColor(hex: "3291C8")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Sapphire: NovaColorPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "4760BA")!,
        tint400: UIColor(hex: "1E3DAB")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    let tint50: UIColor
    let tint100: UIColor
    let tint200: UIColor
    let tint300: UIColor
    let tint400: UIColor
    let tint500: UIColor
    let tint600: UIColor
    let tint700: UIColor
    let tint800: UIColor
    let tint900: UIColor
    let tint950: UIColor?
}

// MARK: - NovaPalettes

class NovaPalettes: NSObject {
    // MARK: Lifecycle

    private init(
        tint50: UIColor,
        tint100: UIColor,
        tint200: UIColor,
        tint300: UIColor,
        tint400: UIColor,
        tint500: UIColor,
        tint600: UIColor,
        tint700: UIColor,
        tint800: UIColor,
        tint900: UIColor,
        tint950: UIColor? = nil
    ) {
        self.tint50 = tint50
        self.tint100 = tint100
        self.tint200 = tint200
        self.tint300 = tint300
        self.tint400 = tint400
        self.tint500 = tint500
        self.tint600 = tint600
        self.tint700 = tint700
        self.tint800 = tint800
        self.tint900 = tint900
        self.tint950 = tint950

        super.init()
    }

    // MARK: Internal

    static let Black: UIColor = .init(hex: "000000")!

    static let White: UIColor = .init(hex: "FFFFFF")!

    static let LocalGPT = UIColor(hex: "CCFD7C")!.withAlphaComponent(0.75)
    static let LocalGPTDark: UIColor = .init(hex: "072121")!
    static let localGPTBackground = UIColor(hex: "CCFD7C")!.withAlphaComponent(0.1)
    static let localGPTDarkBackground: UIColor = .init(hex: "161B1F")!

    static let Gray: NovaPalettes = .init(
        tint50: UIColor(hex: "FAFAFA")!,
        tint100: UIColor(hex: "F2F2F2")!,
        tint200: UIColor(hex: "E3E3E3")!,
        tint300: UIColor(hex: "BDBDBD")!,
        tint400: UIColor(hex: "9B9B9B")!,
        tint500: UIColor(hex: "656565")!,
        tint600: UIColor(hex: "444444")!,
        tint700: UIColor(hex: "282828")!,
        tint800: UIColor(hex: "  ")!,
        tint900: UIColor(hex: "121212")!)

    static let App: NovaPalettes = .init(
        tint50: UIColor(hex: "FFEFEF")!,
        tint100: UIColor(hex: "FFCECE")!,
        tint200: UIColor(hex: "FF9C9C")!,
        tint300: UIColor(hex: "FF7B7B")!,
        tint400: UIColor(hex: "FF5A5A")!,
        tint500: UIColor(hex: "D34343")!,
        tint600: UIColor(hex: "A93636")!,
        tint700: UIColor(hex: "7F2828")!,
        tint800: UIColor(hex: "541B1B")!,
        tint900: UIColor(hex: "2A0D0D")!)

    static let Blue: NovaPalettes = .init(
        tint50: UIColor(hex: "E6F2FE")!,
        tint100: UIColor(hex: "99CBFD")!,
        tint200: UIColor(hex: "67B2FB")!,
        tint300: UIColor(hex: "3498FA")!,
        tint400: UIColor(hex: "158BFF")!,
        tint500: UIColor(hex: "017EF9")!,
        tint600: UIColor(hex: "0165C7")!,
        tint700: UIColor(hex: "014C95")!,
        tint800: UIColor(hex: "003264")!,
        tint900: UIColor(hex: "001932")!,
        tint950: UIColor(hex: "202F3E")!)

    static let Green: NovaPalettes = .init(
        tint50: UIColor(hex: "E6F5EF")!,
        tint100: UIColor(hex: "9DD8BF")!,
        tint200: UIColor(hex: "6BC49F")!,
        tint300: UIColor(hex: "3AB17F")!,
        tint400: UIColor(hex: "08A664")!,
        tint500: UIColor(hex: "099D5F")!,
        tint600: UIColor(hex: "077E4C")!,
        tint700: UIColor(hex: "055E39")!,
        tint800: UIColor(hex: "043F26")!,
        tint900: UIColor(hex: "021F13")!)

    static let Orange: NovaPalettes = .init(
        tint50: UIColor(hex: "FEF0EA")!,
        tint100: UIColor(hex: "FBC3AB")!,
        tint200: UIColor(hex: "F9A682")!,
        tint300: UIColor(hex: "F78858")!,
        tint400: UIColor(hex: "FF6C2D")!,
        tint500: UIColor(hex: "F56A2E")!,
        tint600: UIColor(hex: "C45525")!,
        tint700: UIColor(hex: "99431D")!,
        tint800: UIColor(hex: "622A12")!,
        tint900: UIColor(hex: "311509")!)

    static let Yellow: NovaPalettes = .init(
        tint50: UIColor(hex: "FFF5E8")!,
        tint100: UIColor(hex: "FFD699")!,
        tint200: UIColor(hex: "FFC266")!,
        tint300: UIColor(hex: "FFAD33")!,
        tint400: UIColor(hex: "FF9D0A")!,
        tint500: UIColor(hex: "FF9900")!,
        tint600: UIColor(hex: "CC7A00")!,
        tint700: UIColor(hex: "995C00")!,
        tint800: UIColor(hex: "663D00")!,
        tint900: UIColor(hex: "331F00")!)

    static let Magenta: NovaPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "C75EB6")!,
        tint400: UIColor(hex: "B93AA4")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Purple: NovaPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "8A70BB")!,
        tint400: UIColor(hex: "7251B1")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Skyblue: NovaPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "57A5D2")!,
        tint400: UIColor(hex: "3291C8")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    static let Sapphire: NovaPalettes = .init(
        tint50: UIColor(hex: "000000")!,
        tint100: UIColor(hex: "000000")!,
        tint200: UIColor(hex: "000000")!,
        tint300: UIColor(hex: "4760BA")!,
        tint400: UIColor(hex: "1E3DAB")!,
        tint500: UIColor(hex: "000000")!,
        tint600: UIColor(hex: "000000")!,
        tint700: UIColor(hex: "000000")!,
        tint800: UIColor(hex: "000000")!,
        tint900: UIColor(hex: "000000")!)

    let tint50: UIColor
    let tint100: UIColor
    let tint200: UIColor
    let tint300: UIColor
    let tint400: UIColor
    let tint500: UIColor
    let tint600: UIColor
    let tint700: UIColor
    let tint800: UIColor
    let tint900: UIColor
    let tint950: UIColor?
}

extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
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
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        return (0, 0, 0, 0)
    }

    // hue, saturation, brightness and alpha components from UIColor**
    var hsba: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return (hue, saturation, brightness, alpha)
        }
        return (0, 0, 0, 0)
    }

    var htmlRGB: String {
        let rgbaCache = rgba
        return String(
            format: "#%02x%02x%02x", Int(round(rgbaCache.red * 255)), Int(round(rgbaCache.green * 255)),
            Int(round(rgbaCache.blue * 255)))
    }

    var htmlRGBA: String {
        let rgbaCache = rgba
        return String(
            format: "#%02x%02x%02x%02x", Int(round(rgbaCache.red * 255)), Int(round(rgbaCache.green * 255)),
            Int(round(rgbaCache.blue * 255)), Int(round(rgbaCache.alpha * 255)))
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

    class var DefaultButton: UIColor {
        UIColor(light: NovaPalettes.Blue.tint500, dark: NovaPalettes.Blue.tint300)
    }

    class var PressedButton: UIColor {
        UIColor(
            light: NovaPalettes.Blue.tint500.withAlphaComponent(0.7),
            dark: NovaPalettes.Blue.tint300.withAlphaComponent(0.7))
    }

    class var DefaultButtonIcon: UIColor {
        UIColor(light: NovaPalettes.Gray.tint300, dark: NovaPalettes.Gray.tint500)
    }

    //
    class var PrimaryButtonBackground: UIColor {
        UIColor(light: .black, dark: .white)
    }

    class var PrimaryButtonText: UIColor {
        UIColor(light: .white, dark: .black)
    }

    class var AIPrimaryText: UIColor {
        UIColor(light: NovaPalettes.Green.tint600, dark: NovaPalettes.Green.tint100)
    }

    class var AISecondaryText: UIColor {
        UIColor(light: NovaPalettes.Green.tint700, dark: NovaPalettes.Green.tint50)
    }

    class var AITertiaryText: UIColor {
        UIColor(light: NovaPalettes.Green.tint900, dark: NovaPalettes.White)
    }

    class var AIPrimarySurface: UIColor {
        UIColor(light: NovaPalettes.Green.tint50, dark: NovaPalettes.Green.tint600)
    }

    class var AILocalGPT: UIColor {
        UIColor(light: NovaPalettes.LocalGPT, dark: NovaPalettes.LocalGPTDark)
    }

    class var AILocalGPTBackground: UIColor {
        UIColor(light: NovaPalettes.localGPTBackground, dark: NovaPalettes.localGPTDarkBackground)
    }
}
