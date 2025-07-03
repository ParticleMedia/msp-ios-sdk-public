import Foundation
import MSPiOSCore

extension AdFormat: PlacementPresentable {
    public var placementIdAttachment: String? {
        switch self {
        case .banner:
            return "article-top"
        case .native:
            return "foryou-large"
        case .interstitial:
            return "launch-fullscreen"
        case .multi_format:
            return "multi-format"
        }
    }
} 