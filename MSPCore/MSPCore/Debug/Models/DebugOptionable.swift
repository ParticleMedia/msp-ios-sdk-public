import Foundation
import MSPiOSCore

protocol DebugOptionable {
    var id: String { get }
    var displayTitle: String { get }
    var isVisible: Bool { get }
}

extension AdNetwork: DebugOptionable {
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

extension AdFormat: DebugOptionable {
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

extension NovaCreativeType: DebugOptionable {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .nativeImage: return "Image"
        case .nativeVideo: return "Video"
        case .businessProfile: return "Business Profile"
        case .fullImage: return "Full Image"
        case .sponsoredContent: return "Sponsored Content"
        }
    }
    
    var isVisible: Bool {
        switch self {
        case .nativeImage, .nativeVideo: return true
        case .businessProfile, .fullImage, .sponsoredContent:
            // don't need to implement for now, maybe need attention in the future
            return false
        }
    }
}

extension NovaAppOpenAdLayout: DebugOptionable {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .horizontalCancelTopRight: return "Horizontal Cancel TopRight"
        case .verticalCancelTopRight: return "Vertical Cancel TopRight"
        case .endCard: return "End Card"
        }
    }
    
    var isVisible: Bool { true }
}

extension HighEngagementOption: DebugOptionable {
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
    
    var isVisible: Bool { true }
}
