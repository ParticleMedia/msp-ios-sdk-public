

import Foundation
import UIKit

struct NovaWebViewNavigationViewModel {
    let includingStatusBar: Bool
    let title: String?
    var titleFontSize: CGFloat = 16
    let hideLeftButton: Bool
    let leftButtonIcon: UIImage?
    let rightButtonIcon: UIImage?
    let leftButtonTapActionHandler: (() -> Void)?
    let rightButtonTapActionHandler: (() -> Void)?
    let navigationBarHeight: Double?

    /// - Parameters:
    ///   - includingStatusBar: If `true`, the icon and title will constraint to the bottom of navigation bar, if `false`, the icon and title will constraint to the middle Y of navigation bar
    init(
        includingStatusBar: Bool = true,
        title: String?,
        titleFontSize: CGFloat? = nil,
        hideLeftButton: Bool = false,
        leftButtonIcon: UIImage? = nil,
        leftButtonTapActionHandler: @escaping () -> Void,
        rightButtonIcon: UIImage? = nil,
        rightButtonTapActionHandler: @escaping () -> Void,
        navigationBarHeight: Double? = nil
    ) {
        self.includingStatusBar = includingStatusBar
        self.title = title
        self.leftButtonIcon = leftButtonIcon
        if let titleFontSize {
            self.titleFontSize = titleFontSize
        }
        self.hideLeftButton = hideLeftButton
        self.leftButtonTapActionHandler = leftButtonTapActionHandler
        self.rightButtonIcon = rightButtonIcon
        self.rightButtonTapActionHandler = rightButtonTapActionHandler
        self.navigationBarHeight = navigationBarHeight
    }
}
