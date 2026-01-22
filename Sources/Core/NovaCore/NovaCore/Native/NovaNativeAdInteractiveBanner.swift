import UIKit

enum InteractiveBannerType: String {
    case displayCard = "display_card"
}

final class NovaNativeAdInteractiveBanner {
    let type: InteractiveBannerType
    let imageUrl: URL
    let displayTime: DispatchTimeInterval
    var hasShown: Bool

    init(
        type: InteractiveBannerType,
        imageUrl: URL,
        displayTime: DispatchTimeInterval,
        hasShown: Bool = false
    ) {
        self.type = type
        self.imageUrl = imageUrl
        self.displayTime = displayTime
        self.hasShown = hasShown
    }
}
