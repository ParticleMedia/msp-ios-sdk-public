public struct NovaResponseDataModel: Codable {
    public let ads: [AdItem]?

    enum CodingKeys: String, CodingKey {
        case ads = "ad"
    }
}

public struct AdItem: Codable {
    let creative: Creative
    let startTimeMs: String?
    let expirationMs: String?
    let encryptedAdToken: String
    let adId: String
    let adsetId: String
    let requestId: String
    let price: Double? // price in dollar
}

struct Creative: Codable {
    let ctrUrl: String
    let appStoreId: String?
    let headline: String?
    let body: String?
    let callToAction: String?
    let imageUrl: String?
    let isImageClickable: Bool?
    let isVerticalImage: Bool?
    let advertiser: String?
    let iconUrl: String?
    let adFormatSpec: AdFormatSpec?
    let address: String?
    let launchOption: String?
    let creativeType: String?
    let adm: String?
    let layout: String?
    let closeCountDownTimeSecond: Int?
    
    let clickableComponents: [String]?

    let thirdPartyViewTrackingUrls: [String]?
    let thirdPartyImpressionTrackingUrls: [String]?
    let thirdPartyClickTrackingUrls: [String]?

    let videoItem: VideoItem?
    let addonItem: AddOnItem?
}

public enum NovaAppOpenAdLayout: String, Codable {
    case horizontal = "horizontal"
    case vertical = "vertical"
    case horizontalCancelTopRight = "horizontal_cancel_top_right"
    case verticalCancelTopRight = "vertical_cancel_top_right"
}

public enum NovaAppOpenAdClickableComponent: String {
    case title = "title"
    case body = "body"
    case media = "media"
    case advertiserName = "advertiser_name"
    case adTag = "ad_tag"
    case cta = "cta"
    case icon = "icon"
    case all = "all"
}

struct VideoItem: Codable {
    let videoUrl: String?
    let coverUrl: String?
    let isPlayAutomatically: Bool?
    let isLoop: Bool?
    let isMute: Bool?
    let isVideoClickable: Bool?
    let isVertical: Bool?
    let isPlayOnLandingPage: Bool?
}

struct AdFormatSpec: Codable {
    let backgroundColor: String?
    let textColor: String?
}

struct AddOnItem: Codable {
    let type: String?
    let imageUrl: String
    let displayTime: Int
}
