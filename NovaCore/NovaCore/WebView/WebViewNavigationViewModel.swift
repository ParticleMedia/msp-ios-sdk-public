

import Foundation

public struct WebViewNavigationViewModel {
    public let includingStatusBar: Bool
    public let title: String?
    public var titleFontSize: CGFloat = 16
    public let hideLeftButton: Bool
    public let leftButtonIcon: NovaIcon.NovaSystem?
    public let rightButtonIcon: NovaIcon.NovaSystem?
    public let leftButtonTapActionHandler: (() -> Void)?
    public let rightButtonTapActionHandler: (() -> Void)?
    
    /// - Parameters:
    ///   - includingStatusBar: If `true`, the icon and title will constraint to the bottom of navigation bar, if `false`, the icon and title will constraint to the middle Y of navigation bar
    public init(
        includingStatusBar: Bool = true,
        title: String?,
        titleFontSize: CGFloat? = nil,
        hideLeftButton: Bool = false,
        leftButtonIcon: NovaIcon.NovaSystem? = nil,
        leftButtonTapActionHandler: @escaping () -> Void,
        rightButtonIcon: NovaIcon.NovaSystem? = nil,
        rightButtonTapActionHandler: @escaping () -> Void
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
    }
}
