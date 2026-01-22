import Foundation
import UIKit

extension UIApplication {
    class var novaWindowScenes: [UIWindowScene] {
        Self.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
    }

    class var novaSharedKeyWindow: UIWindow? {
        if #available(iOS 15, *) {
            return novaWindowScenes.first(where: { $0.keyWindow != nil })?.keyWindow
                ?? novaWindowScenes.first?.keyWindow
        } else {
            return Self.shared.windows.filter({ $0.isKeyWindow }).first
        }
    }

    class var novaKeyRootViewController: UIViewController? {
        let vc = novaSharedKeyWindow?.rootViewController
        if vc?.presentedViewController != nil {
            return vc?.presentedViewController
        }
        return vc
    }

    class var novaSafeAreaInsets: UIEdgeInsets {
        Self.novaSharedKeyWindow?.safeAreaInsets ?? .zero
    }

    class var novaTopViewController: UIViewController? {
        guard let rootVC = Self.novaKeyRootViewController else {
            return nil
        }
        var resultVC: UIViewController?
        resultVC = self._topViewController(vc: rootVC)
        while resultVC?.presentedViewController != nil {
            resultVC = self._topViewController(vc: resultVC?.presentedViewController)
        }
        return resultVC
    }

    class var novaCurrentWindowScene: UIWindowScene? {
        Self.shared.connectedScenes.first as? UIWindowScene
    }

    class var novaHasTopSafeArea: Bool {
        Self.novaSafeAreaInsets.top > 20
    }

    private static func _topViewController(vc: UIViewController?) -> UIViewController? {
        if let vc = vc as? UINavigationController {
            return self._topViewController(vc: vc.topViewController)
        } else if let vc = vc as? UITabBarController {
            return self._topViewController(vc: vc.selectedViewController)
        } else {
            return vc
        }
    }
}
