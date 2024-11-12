//
//  NovaAppOpenAd.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

@objc public final class NovaAppOpenAd: NovaBaseAd {
    // MARK: - Properties

    public let creativeType: NovaCreativeType?
    public let launchOption: String?
    public let startTimeInMs: Double?
    public let expirationTimeInMs: Double?

    /// Headline.
    public let headline: String?
    /// Description.
    public let body: String?
    /// CTA button text.
    public let callToAction: String?
    /// Identify the advertiser. For example, advertiser's name or visible url.
    public let advertiser: String?
    /// video info
    public let videoInfo: NovaNativeAdVideoInfo?
    
    public let iconUrl: String?

    /// Delegate used to handle ad click event logging
    @objc public weak var delegate: NovaAppOpenAdDelegate?

    // MARK: -

    init(
        adUnitId: String,
        requestId: String,
        adId: String,
        adSetId: String,
        imageUrlStr: String?,
        ctrUrl: URL?,
        headline: String?,
        body: String?,
        callToAction: String?,
        advertiser: String?,
        creativeType: NovaCreativeType?,
        videoInfo: NovaNativeAdVideoInfo?,
        iconUrl: String?,
        launchOption: String?,
        thirdPartyViewTrackingUrls: [String],
        thirdPartyImpressionTrackingUrls: [String],
        thirdPartyClickTrackingUrls: [String],
        priceInDollar: Double?,
        startTimeInMs: Double?,
        expirationTimeInMs: Double?,
        encryptedAdToken: String
    ) {
        self.creativeType = creativeType
        self.launchOption = launchOption
        self.startTimeInMs = startTimeInMs
        self.expirationTimeInMs = expirationTimeInMs

        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.videoInfo = videoInfo
        self.iconUrl = iconUrl

        super.init(adUnitId: adUnitId,
                   requestId: requestId,
                   adId: adId,
                   adSetId: adSetId,
                   imageUrlStr: imageUrlStr,
                   ctrUrl: ctrUrl,
                   thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
                   thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
                   thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
                   priceInDollar: priceInDollar,
                   encryptedAdToken: encryptedAdToken)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let creativeTypeStr = try container.decode(String.self, forKey: .creativeType)
        creativeType = NovaCreativeType(rawValue: creativeTypeStr)
        launchOption = try container.decode(String.self, forKey: .launchOption)
        startTimeInMs = try container.decode(Double.self, forKey: .startTimeInMs)
        expirationTimeInMs = try container.decode(Double.self, forKey: .expirationTimeInMs)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        callToAction = try container.decodeIfPresent(String.self, forKey: .callToAction)
        advertiser = try container.decodeIfPresent(String.self, forKey: .advertiser)
        videoInfo = try container.decodeIfPresent(NovaNativeAdVideoInfo.self, forKey: .videoInfo)
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case creativeType
        case launchOption
        case startTimeInMs
        case expirationTimeInMs
        case headline
        case body
        case callToAction
        case advertiser
        case videoInfo
        case iconUrl
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(creativeType?.rawValue, forKey: .creativeType)
        try container.encode(launchOption, forKey: .launchOption)
        try container.encode(startTimeInMs, forKey: .startTimeInMs)
        try container.encode(expirationTimeInMs, forKey: .expirationTimeInMs)
        try container.encodeIfPresent(headline, forKey: .headline)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(callToAction, forKey: .callToAction)
        try container.encodeIfPresent(advertiser, forKey: .advertiser)
        try container.encodeIfPresent(videoInfo, forKey: .videoInfo)
        try container.encodeIfPresent(iconUrl, forKey: .iconUrl)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
    
    public func present(rootViewController: UIViewController) {

        switch self.creativeType {
        case .nativeImage:
            guard let imageUrlStr = self.imageUrlStr else {
                return
            }
            self.requestToDisplay(rootViewController: rootViewController, adResource: .imageURL(imageUrlStr))
            
        case .nativeVideo:
            guard let videoInfo = self.videoInfo else {
                return
            }
            DispatchQueue.main.async {
                self.requestToDisplay(
                    rootViewController: rootViewController,
                    adResource: .video(videoInfo)
                )
            }
        default:
            return
        }
    }
    
    static func downloadAdImage(urlStr: String, completion: @escaping (UIImage?) -> Void) {
        guard let imageUrl = URL(string: urlStr) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            if let error = error {
                completion(nil)
                return
            }

            let httpResponse = response as! HTTPURLResponse
            let statusCode = httpResponse.statusCode

            guard (200 ... 299).contains(statusCode) else {
                completion(nil)
                return
            }

            guard let data else {
                completion(nil)
                return
            }

            completion(UIImage(data: data))
        }.resume()
    }
    
    public func requestToDisplay(
        rootViewController: UIViewController,
        adResource: NovaAppOpenAdResource
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        let controller = NovaAppOpenAdViewController(appOpenAd: self, adResource: adResource)
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .crossDissolve
        rootViewController.present(controller, animated: true)
    }
}
