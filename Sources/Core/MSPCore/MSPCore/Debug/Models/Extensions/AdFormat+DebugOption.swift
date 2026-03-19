import Foundation
import MSPiOSCore

extension AdFormat: DebugOption {
    var id: String {
        switch self {
        case .banner: return "banner"
        case .interstitial: return "interstitial"
        case .multi_format: return "multi_format"
        case .native: return "native"
        case .rewarded: return "rewarded"
        @unknown default: return "unknown"
        }
    }

    var displayTitle: String {
        switch self {
        case .banner: return "Banner"
        case .interstitial: return "Interstitial"
        case .multi_format: return "Multi_Format(Banner & Native)"
        case .native: return "Native"
        case .rewarded: return "Rewarded"
        @unknown default: return "Unknown"
        }
    }

    var isVisible: Bool {
        switch self {
        case .banner, .interstitial, .multi_format, .native, .rewarded: return true
        @unknown default: return false
        }
    }

    var supportsDebugScopedC2S: Bool {
        switch self {
        case .banner, .interstitial, .native:
            return true
        case .multi_format, .rewarded:
            return false
        @unknown default:
            return false
        }
    }
}
