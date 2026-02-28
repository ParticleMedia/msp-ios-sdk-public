import StoreKit
import UIKit

public protocol NativeAdSKOverlayControllable: AnyObject {
    var canAutoShowSKOverlayOnVideoPlayback: Bool { get }

    func showSKOverlayIfPossible(
        scene: UIWindowScene?,
        position: SKOverlay.Position,
        userDismissible: Bool
    )

    func dismissSKOverlay()
}
