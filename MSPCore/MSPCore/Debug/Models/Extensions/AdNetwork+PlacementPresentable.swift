import Foundation
import MSPiOSCore

extension AdNetwork: PlacementPresentable {
    public var placementIdAttachment: String? {
        switch self {
        case .unity, .pubmatic, .mintegral, .mobilefuse, .inmobi:
            return "-\(rawValue)"
        case .google, .facebook, .nova, .prebid:
            return nil
        case .unknown:
            return nil
        }
    }
} 
