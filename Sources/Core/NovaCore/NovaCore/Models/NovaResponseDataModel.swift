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
    let price: Double?  // price in dollar
    let highValue: Bool?

    private enum CodingKeys: String, CodingKey {
        case creative
        case startTimeMs
        case expirationMs
        case encryptedAdToken
        case adId
        case adsetId
        case requestId
        case price
        case highValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creative = try container.decode(Creative.self, forKey: .creative)
        startTimeMs = try container.decodeIfPresent(String.self, forKey: .startTimeMs)
        expirationMs = try container.decodeIfPresent(String.self, forKey: .expirationMs)
        encryptedAdToken = try container.decode(String.self, forKey: .encryptedAdToken)
        adId = try container.decode(String.self, forKey: .adId)
        adsetId = try container.decode(String.self, forKey: .adsetId)
        requestId = try container.decode(String.self, forKey: .requestId)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        // Tolerate type mismatch (e.g. server sends string/number): collapse to nil
        // so the ad still loads; builder layer defaults absent values to false.
        highValue = (try? container.decodeIfPresent(Bool.self, forKey: .highValue)) ?? nil
    }
}

struct Creative: Codable {
    let ctrUrl: String
    let ctaStyle: String?
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
    let theme: String?
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
