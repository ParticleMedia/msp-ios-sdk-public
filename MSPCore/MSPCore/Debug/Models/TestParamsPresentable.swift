import Foundation
import MSPiOSCore

protocol TestParamsPresentable {
    var testParams: [String: String] { get }
}

protocol TestParamPresentable {
    var keyValuePairs: [(String, String)] { get }
}

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

extension NovaCreativeType: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .nativeImage: return [("creative_type", "image")]
        case .nativeVideo: return [("creative_type", "video")]
        case .businessProfile, .fullImage, .sponsoredContent:
            // don't need to implement for now, maybe need attention in the future
            return []
        }
    }
}

extension NovaAppOpenAdLayout: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .horizontal: return [("is_vertical", "false")]
        case .vertical: return [("is_vertical", "true")]
        case .endCard: return [("is_vertical", "true"), ("layout", rawValue)]
        case .verticalCancelTopRight: return [("is_vertical", "true"), ("layout", rawValue)]
        case .horizontalCancelTopRight: return [("is_vertical", "false"), ("layout", rawValue)]
        }
    }
}

extension HighEngagementOption: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .yes: return [("high_engagement", "true")]
        case .no: return [("high_engagement", "false")]
        }
    }
}
