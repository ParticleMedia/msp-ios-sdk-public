import Foundation
import MSPiOSCore

extension AdNetwork: DebugOption {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .facebook: return "Facebook"
        case .google: return "Google"
        case .nova: return "Nova"
        case .pubmatic: return "Pubmatic"
        case .mobilefuse: return "MobileFuse"
        case .prebid: return "Prebid"
        case .unity: return "Unity"
        case .inmobi: return "InMobi"
        case .mintegral: return "Mintegral"
        case .unknown: return ""
        @unknown default: return ""
        }
    }
    
    var isVisible: Bool {
        switch self {
        case .facebook, .google, .nova, .pubmatic: return true
        case .inmobi, .mintegral, .mobilefuse, .prebid, .unity:
            // don't need to implement for now, maybe need attention in the future
            return false
        case .unknown: return false
        @unknown default: return false
        }
    }
} 