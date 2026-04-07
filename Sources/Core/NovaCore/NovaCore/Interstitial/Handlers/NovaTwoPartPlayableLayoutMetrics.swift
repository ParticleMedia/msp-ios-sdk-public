import UIKit

enum NovaTwoPartPlayableLayoutMetrics {
    static let minimumBottomBannerInset: CGFloat = 12

    static func bottomBannerInset(for safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom, minimumBottomBannerInset)
    }
}
