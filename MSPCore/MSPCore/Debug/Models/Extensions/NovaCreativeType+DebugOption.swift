import Foundation
import MSPiOSCore

extension NovaCreativeType: DebugOption {
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
    
    var placementIdAttachment: String? { nil }
}
