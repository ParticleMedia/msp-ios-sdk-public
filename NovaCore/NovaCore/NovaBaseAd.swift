//
//  NovaBaseAd.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation

public class NovaBaseAd: NSObject, Codable {
    // MARK: - Properties

    /// Ad unit id of nova ad
    let adUnitId: String

    /// Rqeust UUID for nova ad, used to join all nova events on server.
    let requestId: String

    /// used in nova ad manager, to identify the ad, not the same as ios system adid.
    let adId: String

    /// used in nova ad manager, to identify the adset which the ad belongs
    let adSetId: String

    /// Ad image url.
    let imageUrlStr: String?

    /// ctr actions when tapping ad
    let adCtrType: AdCtrType

    /// Used for third party viewability tracker.
    let thirdPartyViewTrackingUrls: [String]

    /// Used for third party impression tracker.
    let thirdPartyImpressionTrackingUrls: [String]

    /// Used for third party click tracker.
    let thirdPartyClickTrackingUrls: [String]

    /// Used for record slot request id
    var adOpportunityID: UUID?

    /// Encoded ids for server tracking.
    let encryptedAdToken: String

    // Indicate if a nova ad has logged impression
    var hasImpressionLogged: Bool = false
    var hasLoadedLogged: Bool = false

    let priceInDollar: Double?

    // MARK: -

    init(
        adUnitId: String,
        requestId: String,
        adId: String,
        adSetId: String,
        imageUrlStr: String?,
        adCtrType: AdCtrType,
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
        self.adCtrType = adCtrType
        self.thirdPartyViewTrackingUrls = thirdPartyViewTrackingUrls
        self.thirdPartyImpressionTrackingUrls = thirdPartyImpressionTrackingUrls
        self.thirdPartyClickTrackingUrls = thirdPartyClickTrackingUrls
        self.priceInDollar = priceInDollar
        self.encryptedAdToken = encryptedAdToken
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adUnitId = try container.decode(String.self, forKey: .adUnitId)
        requestId = try container.decode(String.self, forKey: .requestId)
        adId = try container.decode(String.self, forKey: .adId)
        adSetId = try container.decode(String.self, forKey: .adSetId)
        imageUrlStr = try container.decodeIfPresent(String.self, forKey: .imageUrlStr)
        adCtrType = try container.decode(AdCtrType.self, forKey: .ctrType)
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
        case ctrType
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
        try container.encodeIfPresent(imageUrlStr, forKey: .imageUrlStr)
        try container.encode(adCtrType, forKey: .ctrType)
        try container.encode(thirdPartyViewTrackingUrls, forKey: .thirdPartyViewTrackingUrls)
        try container.encode(thirdPartyImpressionTrackingUrls, forKey: .thirdPartyImpressionTrackingUrls)
        try container.encode(thirdPartyClickTrackingUrls, forKey: .thirdPartyClickTrackingUrls)
        try container.encode(encryptedAdToken, forKey: .encryptedAdToken)
        try container.encodeIfPresent(priceInDollar, forKey: .priceInDollar)
    }

    func priceInCents() -> Float {
        if let priceInDollar = priceInDollar {
            return Float(priceInDollar * 100)
        }
        return -1
    }
}
