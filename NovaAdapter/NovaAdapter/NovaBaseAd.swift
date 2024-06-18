//
//  NovaBaseAd.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation

@objc public class NovaBaseAd: NSObject, Codable {
    // MARK: - Properties

    /// Ad unit id of nova ad
    @objc public let adUnitId: String

    /// Rqeust UUID for nova ad, used to join all nova events on server.
    @objc public let requestId: String

    /// used in nova ad manager, to identify the ad, not the same as ios system adid.
    @objc public let adId: String

    /// used in nova ad manager, to identify the adset which the ad belongs
    @objc public let adSetId: String

    /// Ad image url.
    @objc public let imageUrlStr: String?

    /// Url used to open ad.
    public let ctrUrl: URL?

    /// Used for third party viewability tracker.
    public let thirdPartyViewTrackingUrls: [String]

    /// Used for third party impression tracker.
    public let thirdPartyImpressionTrackingUrls: [String]

    /// Used for third party click tracker.
    public let thirdPartyClickTrackingUrls: [String]

    /// Encoded ids for server tracking.
    @objc public let encryptedAdToken: String

    // Indicate if a nova ad has logged impression
    var hasImpressionLogged: Bool = false
    var hasLoadedLogged: Bool = false

    public let priceInDollar: Double?

    // MARK: -

    init(
        adUnitId: String,
        requestId: String,
        adId: String,
        adSetId: String,
        imageUrlStr: String?,
        ctrUrl: URL?,
        thirdPartyViewTrackingUrls: [String],
        thirdPartyImpressionTrackingUrls: [String],
        thirdPartyClickTrackingUrls: [String],
        priceInDollar: Double?,
        encryptedAdToken: String
    ) {
        self.adUnitId = adUnitId
        self.requestId = requestId
        self.adId = adId
        self.adSetId = adSetId
        self.imageUrlStr = imageUrlStr
        self.ctrUrl = ctrUrl
        self.thirdPartyViewTrackingUrls = thirdPartyViewTrackingUrls
        self.thirdPartyImpressionTrackingUrls = thirdPartyImpressionTrackingUrls
        self.thirdPartyClickTrackingUrls = thirdPartyClickTrackingUrls
        self.priceInDollar = priceInDollar
        self.encryptedAdToken = encryptedAdToken
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adUnitId = try container.decode(String.self, forKey: .adUnitId)
        requestId = try container.decode(String.self, forKey: .requestId)
        adId = try container.decode(String.self, forKey: .adId)
        adSetId = try container.decode(String.self, forKey: .adSetId)
        imageUrlStr = try container.decode(String.self, forKey: .imageUrlStr)
        ctrUrl = try container.decode(URL.self, forKey: .ctrUrl)
        thirdPartyViewTrackingUrls = try container.decode([String].self, forKey: .thirdPartyViewTrackingUrls)
        thirdPartyImpressionTrackingUrls = try container.decode([String].self, forKey: .thirdPartyImpressionTrackingUrls)
        thirdPartyClickTrackingUrls = try container.decode([String].self, forKey: .thirdPartyClickTrackingUrls)
        encryptedAdToken = try container.decode(String.self, forKey: .encryptedAdToken)
        priceInDollar = try container.decodeIfPresent(Double.self, forKey: .priceInDollar)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case adUnitId
        case requestId
        case adId
        case adSetId
        case imageUrlStr
        case ctrUrl
        case thirdPartyViewTrackingUrls
        case thirdPartyImpressionTrackingUrls
        case thirdPartyClickTrackingUrls
        case encryptedAdToken
        case priceInDollar
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(adUnitId, forKey: .adUnitId)
        try container.encode(requestId, forKey: .requestId)
        try container.encode(adId, forKey: .adId)
        try container.encode(adSetId, forKey: .adSetId)
        try container.encode(imageUrlStr, forKey: .imageUrlStr)
        try container.encode(ctrUrl, forKey: .ctrUrl)
        try container.encode(thirdPartyViewTrackingUrls, forKey: .thirdPartyViewTrackingUrls)
        try container.encode(thirdPartyImpressionTrackingUrls, forKey: .thirdPartyImpressionTrackingUrls)
        try container.encode(thirdPartyClickTrackingUrls, forKey: .thirdPartyClickTrackingUrls)
        try container.encode(encryptedAdToken, forKey: .encryptedAdToken)
        try container.encode(priceInDollar, forKey: .priceInDollar)
    }

    @objc public func priceInCents() -> Float {
        if let priceInDollar = priceInDollar {
            return Float(priceInDollar * 100)
        }
        return -1
    }
}
