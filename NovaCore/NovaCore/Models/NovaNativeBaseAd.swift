//  NovaNativeBaseAd.swift
//  NovaCore
//
//  Created by Shanyu Li on 2024/11/21.
//

import Foundation
import UIKit

// MARK: - NovaNativeBaseAd

public class NovaNativeBaseAd: NovaBaseAd, NovaNativeMediaProviding {
    // MARK: Lifecycle

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
        encryptedAdToken: String,
        supportOCPM: Bool,
        creativeType: NovaCreativeType,
        headline: String?,
        body: String?,
        callToAction: String?,
        advertiser: String?,
        iconURL: URL?,
        isImageLayoutVertical: Bool?,
        isImageClickable: Bool,
        imageURLs: [String]?,
        imageContentMode: NovaNativeImageContentMode?,
        videoInfo: NovaNativeAdVideoInfo?,
        multipleItemsInfo: NovaAdMultipleItemsInfo?,
        adDiscountTagInfo: NovaAdDiscountTagInfo?,
        layoutStyle: NovaNativeLayoutStyle?,
        marketingType: NovaAdMarketingType,
        playableInfo: NovaAdPlayableInfo?,
        htmlPageItems: [PageItem]?
    ) throws {
        self.creativeType = creativeType
        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.iconURL = iconURL
        self._isImageClickable = isImageClickable
        self._videoInfo = videoInfo
        self._isImageLayoutVertical = isImageLayoutVertical
        self._imageURLs = imageURLs
        self._imageContentMode = imageContentMode
        self._multipleItemsInfo = multipleItemsInfo
        self.adDiscountTagInfo = adDiscountTagInfo
        self.marketingType = marketingType
        self._playableInfo = playableInfo
        self.htmlPageItems = htmlPageItems
        // give it a default value to make it compile
        self.mediaContent = NovaAdMediaContent(adMedia: Self.defaultAdMedia)

        super.init(
            adUnitId: adUnitId,
            requestId: requestId,
            adId: adId,
            adSetId: adSetId,
            imageUrlStr: imageUrlStr,
            adCtrType: adCtrType,
            thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
            thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
            thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
            priceInDollar: priceInDollar,
            encryptedAdToken: encryptedAdToken,
            supportOCPM: supportOCPM
        )
        self.mediaContent = try NovaAdMediaContent(adMedia: getAdMedia(), discountTagInfo: self.adDiscountTagInfo)
        self.htmlModel = getHtmlModel()

        Task {
            if case let .appInstall(model) = adCtrType {
                appInfo = await {
                    do {
                        return try await NovaAdAppInfo.appInfo(for: model.storeId)
                    } catch {
                        DebugLogger.data.error("Get app info failed with reason: \(error.localizedDescription)")
                        return nil
                    }
                }()
            }
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        creativeType = try container.decode(NovaCreativeType.self, forKey: .creativeType)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        callToAction = try container.decodeIfPresent(String.self, forKey: .callToAction)
        advertiser = try container.decodeIfPresent(String.self, forKey: .advertiser)
        iconURL = try container.decodeIfPresent(URL.self, forKey: .iconURL)
        _isImageLayoutVertical = try container.decodeIfPresent(Bool.self, forKey: .isVerticalImage)
        _isImageClickable = try container.decodeIfPresent(Bool.self, forKey: .isImageClickable) ?? true
        _imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
        _imageContentMode = try container.decodeIfPresent(NovaNativeImageContentMode.self, forKey: .imageContentMode)
        _videoInfo = try container.decodeIfPresent(NovaNativeAdVideoInfo.self, forKey: .videoInfo)
        _multipleItemsInfo = try container.decodeIfPresent(NovaAdMultipleItemsInfo.self, forKey: .multipleItemsInfo)
        adDiscountTagInfo = try container.decodeIfPresent(NovaAdDiscountTagInfo.self, forKey: .adDiscountTagInfo)
        marketingType = try container.decode(NovaAdMarketingType.self, forKey: .marketingType)
        _playableInfo = try container.decodeIfPresent(NovaAdPlayableInfo.self, forKey: .playableInfo)
        mediaContent = NovaAdMediaContent(adMedia: Self.defaultAdMedia)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        mediaContent = try NovaAdMediaContent(adMedia: getAdMedia(), discountTagInfo: adDiscountTagInfo)
    }

    // MARK: Internal

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case creativeType
        case headline
        case body
        case callToAction
        case advertiser
        case iconURL
        case isVerticalImage
        case isImageClickable
        case imageURLs
        case imageContentMode
        case videoInfo
        case multipleItemsInfo
        case layoutStyle
        case adDiscountTagInfo
        case marketingType
        case playableInfo
    }

    public var creativeType: NovaCreativeType

    /// Headline.
    public var headline: String?

    /// Description.
    public var body: String?

    /// CTA button text.
    public var callToAction: String?

    /// Identify the advertiser. For example, advertiser's name or visible url.
    public var advertiser: String?

    /// Icon URL.
    public var iconURL: URL?

    // media used to render media view
    public private(set) var mediaContent: NovaAdMediaContent
    
    // media used to render html webview
    public private(set) var htmlModel: NovaAdHtmlMediaModel?

    // MARK: - Discount Tag

    var adDiscountTagInfo: NovaAdDiscountTagInfo?

    // MARK: - App install

    var appInfo: NovaAdAppInfo?

    // MARK: - DPA

    var marketingType: NovaAdMarketingType

    var singleImageUrl: URL? {
        if let imageUrlStr, let url = URL(string: imageUrlStr) {
            return url
        } else if let first = _imageURLs?.first, let url = URL(string: first) {
            return url
        } else {
            return nil
        }
    }

    // MARK: - Media Model Hooks

    func makeImageModel() throws -> NovaAdImageMediaModel {
        fatalError("\(Self.self) must override makeImageModel()")
    }

    func makeVideoModel() throws -> NovaAdVideoMediaModel {
        fatalError("\(Self.self) must override makeVideoModel()")
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(creativeType.rawValue, forKey: .creativeType)
        try container.encodeIfPresent(headline, forKey: .headline)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(callToAction, forKey: .callToAction)
        try container.encodeIfPresent(advertiser, forKey: .advertiser)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
        try container.encodeIfPresent(_isImageLayoutVertical, forKey: .isVerticalImage)
        try container.encodeIfPresent(_imageContentMode, forKey: .imageContentMode)
        try container.encodeIfPresent(_videoInfo, forKey: .videoInfo)
        try container.encodeIfPresent(_multipleItemsInfo, forKey: .multipleItemsInfo)
        try container.encodeIfPresent(adDiscountTagInfo, forKey: .adDiscountTagInfo)
        try container.encode(marketingType, forKey: .marketingType)
        try container.encode(_playableInfo, forKey: .playableInfo)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }

    // MARK: Private

    private static let defaultAdMedia: NovaAdMedia = .image(model: .init(
        resource: .imageURLStr(""),
        isImageClickable: false,
        adCtrType: .openWeb(model: .init(url: URL(string: "https://example.com")!, openBrowser: false)),
        imageLayoutOrientation: .unknown,
        shouldShowImageBorder: false
    ))

    // MARK: - Image

    // deprecated, Using `layoutStyle` instead
    var _isImageLayoutVertical: Bool?

    /// Whether to use static image in immersive video
    var _isImageClickable: Bool

    /// imageURLs is used to replace the imageURL in IMAGE creative type
    var _imageURLs: [String]?

    /// imageView's content mode
    var _imageContentMode: NovaNativeImageContentMode?

    // MARK: - Video

    /// video info
    var _videoInfo: NovaNativeAdVideoInfo?

    // MARK: - multipleItems

    var _multipleItemsInfo: NovaAdMultipleItemsInfo?

    // MARK: - Playable Ad

    var _playableInfo: NovaAdPlayableInfo?
    
    // MARK: - HTML Ad
    var htmlPageItems: [PageItem]?
}

// MARK: - Media Extension

extension NovaNativeBaseAd {
    func getAdMedia() throws -> NovaAdMedia {
        switch creativeType {
        case .nativeVideo:
            return try .video(model: makeVideoModel())
        case .nativeImage, .businessProfile, .sponsoredContent, .fullImage:
            if let _imageURLs {
                let urls = _imageURLs.compactMap { URL(string: $0) }
                if urls.count > 1 {
                    return .multipleImages(model: .init(imageURLs: urls, adCtrType: adCtrType, timerInterval: 3.0))
                }
            }
            return try .image(model: makeImageModel())
        case .carousel:
            if let _multipleItemsInfo {
                return .multipleItems(model: .init(info: _multipleItemsInfo))
            } else {
                throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing multiple items info")
            }
        case .playableImage:
            guard case let .playable(model) = adCtrType else {
                throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing playable info")
            }

            return try .imagePlayable(
                imageModel: makeImageModel(),
                playableModel: .init(playableActionModel: model, layout: _playableInfo?.layout)
            )
        case .playableVideo:
            guard case let .playable(model) = adCtrType else {
                throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing playable info")
            }

            return try .videoPlayable(
                videoModel: makeVideoModel(),
                playableModel: .init(playableActionModel: model, layout: _playableInfo?.layout)
            )
        case .html:
            return .html
        }
    }
    
    public var isVideo: Bool {
        switch creativeType {
        case .playableVideo, .nativeVideo:
            return true
        default:
            return false
        }
    }

    func makeImageModel(with orientation: NovaNativeMediaLayoutOrientation?) throws -> NovaAdImageMediaModel {
        let imageFallbackOrientation: NovaNativeMediaLayoutOrientation = if let _isImageLayoutVertical {
            _isImageLayoutVertical ? .vertical : .horizontal
        } else {
            .unknown
        }
        if let _imageURLs {
            let urls = _imageURLs.compactMap { URL(string: $0) }
            if let first = urls.first {
                return .init(
                    resource: .imageUrl(first),
                    isImageClickable: _isImageClickable,
                    adCtrType: adCtrType,
                    imageContentMode: _imageContentMode?.toUIViewContentMode(),
                    imageLayoutOrientation: orientation ?? imageFallbackOrientation,
                    shouldShowImageBorder: marketingType == .dpa
                )
            }
        }
        if let imageUrlStr {
            return .init(
                resource: .imageURLStr(imageUrlStr),
                isImageClickable: _isImageClickable,
                adCtrType: adCtrType,
                imageContentMode: _imageContentMode?.toUIViewContentMode(),
                imageLayoutOrientation: orientation ?? imageFallbackOrientation,
                shouldShowImageBorder: marketingType == .dpa
            )
        } else {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing image URL")
        }
    }

    func makeVideoModel(with orientation: NovaNativeMediaLayoutOrientation?) throws -> NovaAdVideoMediaModel {
        if let _videoInfo {
            let endCardModel: NovaAdEndCardViewModel? = {
                if _videoInfo.endCardStyle != nil, let endCardStyle = getEndCardStyle() {
                    return NovaAdEndCardViewModel.create(from: self, style: endCardStyle)
                } else {
                    return nil
                }
            }()
            return .init(
                videoInfo: _videoInfo,
                videoLayoutOrientation: orientation ?? (_videoInfo.isLayoutVertical ? .vertical : .horizontal),
                adCtrType: adCtrType,
                callToAction: callToAction,
                endCardModel: endCardModel
            )
        } else {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing video info")
        }
    }
    
    func getHtmlModel() -> NovaAdHtmlMediaModel? {
        var pages = [NovaAdHtmlPageModel]()
        if let htmlPageItems = self.htmlPageItems {
            for pageItem in htmlPageItems {
                let resource = NovaAdHtmlResource(url: pageItem.url, htmlString: pageItem.html)
                let closeCountDownSeconds = pageItem.skipCountdown ?? 0
                let closeDelaySeconds = pageItem.skipDelay ?? 0
                let useClickUrl = pageItem.useClickUrl ?? false
                let useCustomClose = pageItem.useCustomClose ?? false
                let pageModel = NovaAdHtmlPageModel(resource: resource, closeCountDownSeconds: closeCountDownSeconds, closeDelaySeconds: closeDelaySeconds, useClickUrl: useClickUrl, useCustomClose: useCustomClose)
                pages.append(pageModel)
            }
        }
        if !pages.isEmpty {
            return NovaAdHtmlMediaModel(pages: pages)
        } else {
            return nil
        }
    }
}
