import Foundation
import MSPiOSCore

extension NovaCreativeType: TestParamPresentable {
    var keyValuePairs: [(String, String)] {
        switch self {
        case .nativeImage: return [("creative_type", "image")]
        case .nativeVideo: return [("creative_type", "video")]
        case .businessProfile, .fullImage, .sponsoredContent, .html:
            // don't need to implement for now, maybe need attention in the future
            return []
        }
    }
} 
