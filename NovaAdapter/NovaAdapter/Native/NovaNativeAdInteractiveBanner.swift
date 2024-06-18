import UIKit

public enum InteractiveBannerType: String {
    case displayCard = "display_card"
}

public final class NovaNativeAdInteractiveBanner {
    public let type: InteractiveBannerType
    public let imageUrl: URL
    public let displayTime: DispatchTimeInterval
    public var hasShown: Bool
    
    public init(
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
