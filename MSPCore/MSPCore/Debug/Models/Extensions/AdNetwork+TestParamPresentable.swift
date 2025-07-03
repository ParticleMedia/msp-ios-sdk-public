import Foundation
import MSPiOSCore

extension AdNetwork: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .nova: return [("ad_network", "msp_nova")]
        case .google: return [("ad_network", "msp_google")]
        case .facebook: return [("ad_network", "msp_fb")]
        case .pubmatic: return [("ad_network", "pubmatic")]
        case .inmobi, .mintegral, .mobilefuse, .prebid, .unity:
            // don't need to implement for now, maybe need attention in the future
            return []
        case .unknown: return []
        @unknown default:
            return []
        }
    }
} 