import Foundation

public struct NovaResponseDataModel: Codable {
    public let ads: [AdItem]?
    public let abConfig: [String: String]?

    enum CodingKeys: String, CodingKey {
        case ads = "ad"
        case abConfig
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
    let imageUrls: [String]?
    let imageScaleMode: String?
    let isVerticalImage: Bool?
    let isImageClickable: Bool?
    let layout: String?
    let advertiser: String?
    let iconUrl: String?
    let adFormatSpec: AdFormatSpec?
    let address: String?
    let launchOption: String?
    let creativeType: String?
    let adm: String?
    let marketingType: String?
    let closeCountDownTimeSecond: Int?
    let clickableComponents: [String]?

    let thirdPartyViewTrackingUrls: [String]?
    let thirdPartyImpressionTrackingUrls: [String]?
    let thirdPartyClickTrackingUrls: [String]?

    let videoItem: VideoItem?
    let addonItem: AddOnItem?
    let carouselItems: [MultipleItemsItem]?
    let tagItem: TagItem?
    let playableItem: PlayableItem?
    
    let htmlPageItems: [PageItem]?
}

struct PageItem: Codable {
    let html: String?
    let url: String?
    let skipDelay: Int?
    let skipCountdown: Int?
    let useClickUrl: Bool?
    let useCustomClose: Bool?
}

struct MultipleItemsItem: Codable {
    let imageUrl: String?
    let body: String?
    let callToAction: String?
    let appStoreId: String?
    let ctrUrl: String?
}

struct TagItem: Codable {
    let position: String
    let style: String
    let texts: [String]
}

struct PlayableItem: Codable {
    let url: String?
    let clickAreaMode: String?
    let layout: String?
    let actionBarFormat: String?
    let tapToTryFormat: String?
}

struct VideoItem: Codable {
    let videoUrl: String?
    let coverUrl: String?
    let isPlayAutomatically: Bool?
    let isLoop: Bool?
    let isMute: Bool?
    let endCardStyle: String?
    let isVideoClickable: Bool?
    let isVertical: Bool?
    let isPlayOnLandingPage: Bool?
}

struct AddOnItem: Codable {
    let type: String?
    let imageUrl: String
    let displayTime: Int
}

struct AdFormatSpec: Codable {
    let backgroundColor: String?
    let textColor: String?
}
