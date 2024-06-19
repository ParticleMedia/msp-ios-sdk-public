import DeviceKit
import Foundation

public extension UIDevice {

    @objc static var nb_isiPad: Bool {
        return self.current.userInterfaceIdiom == .pad
    }

    @objc static var nb_isiPhone: Bool {
        return self.current.userInterfaceIdiom == .phone
    }
    
    @objc static var nb_orientationWidth: CGFloat {
        return UIDevice.nb_orientationSize.width
    }
    
    @objc static var nb_orientationSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width;
        let screenHeight = UIScreen.main.bounds.height;
        let minL = min(screenWidth, screenHeight)
        let maxL = max(screenWidth, screenHeight)
        
        if UIDevice.current.orientation.isLandscape {
            return CGSize(width: maxL, height: minL)
        } else if UIDevice.current.orientation.isPortrait {
            return CGSize(width: minL, height: maxL)
        } else {
            return CGSize(width: screenWidth, height: screenHeight)
        }
    }

    static var nb_isiPhoneX: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let safeAreaInsets: UIEdgeInsets = UIApplication.shared.delegate?.window??.safeAreaInsets ?? .zero

        return safeAreaInsets.top > 20
    }

    static var nb_safeAreaInsets: UIEdgeInsets {
        let safeAreaInsets: UIEdgeInsets = UIApplication.shared.delegate?.window??.safeAreaInsets ?? .zero
        return safeAreaInsets
    }

    // return "iPhone7,1" etc.
    @objc static var nb_deviceModelRaw: String {
        return Device.identifier
    }

    // return "iPhone 11" etc.
    @objc static var nb_deviceModelMarketName: String {
        return Device.current.safeDescription
    }

    @objc static var statusBarHeight: CGFloat {
        var height = 20.0
        if let insets = UIApplication.shared.delegate?.window??.safeAreaInsets {
            height = insets.top
        }
        return height
    }

    @objc static var bottomRoundAreaHeight: CGFloat {
        return nb_isiPhoneX ? 34.0 : 0.0
    }
}

