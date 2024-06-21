import Foundation
import UIKit

public extension UIApplication {

    @objc var nb_safeAreaInsets: UIEdgeInsets {
        guard self.windows.count > 0 else {
            return .zero
        }

        return self.windows[0].safeAreaInsets
    }
    
    class var windowScenes: [UIWindowScene] {
        return Self.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
    }

    class var sharedKeyWindow: UIWindow? {
        if #available(iOS 15, *) {
            return windowScenes.first(where: { $0.keyWindow != nil })?.keyWindow ?? windowScenes.first?.keyWindow
        } else {
            return Self.shared.windows.filter({ $0.isKeyWindow }).first
        }
    }

    class var keyRootViewController: UIViewController? {
        sharedKeyWindow?.rootViewController
    }

}

