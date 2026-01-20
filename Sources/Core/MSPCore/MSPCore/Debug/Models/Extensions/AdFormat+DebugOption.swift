import Foundation
import MSPiOSCore

extension AdFormat: DebugOption {
    var id: String {
        switch self {
        case .banner: return "banner"
        case .interstitial: return "interstitial"
        case .multi_format: return "multi_format"
        case .native: return "native"
        @unknown default: return "unknown"
        }
    }
    
    var displayTitle: String {
        switch self {
        case .banner: return "Banner"
        case .interstitial: return "Interstitial"
        case .multi_format: return "Multi_Format(Banner & Native)"
        case .native: return "Native"
        @unknown default: return "Unknown"
        }
    }
    
    var isVisible: Bool {
        switch self {
        case .banner, .interstitial, .multi_format, .native: return true
        @unknown default: return false
        }
    }
} 