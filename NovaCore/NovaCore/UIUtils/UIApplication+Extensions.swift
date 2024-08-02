import Foundation
import UIKit

public extension UIApplication {

    @objc var nova_safeAreaInsets: UIEdgeInsets {
        guard self.windows.count > 0 else {
            return .zero
        }

        return self.windows[0].safeAreaInsets
    }
    
    class var novawindowScenes: [UIWindowScene] {
        return Self.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
    }

    class var novasharedKeyWindow: UIWindow? {
        if #available(iOS 15, *) {
            return novawindowScenes.first(where: { $0.keyWindow != nil })?.keyWindow ?? novawindowScenes.first?.keyWindow
        } else {
            return Self.shared.windows.filter({ $0.isKeyWindow }).first
        }
    }

    class var novakeyRootViewController: UIViewController? {
        novasharedKeyWindow?.rootViewController
    }

}

