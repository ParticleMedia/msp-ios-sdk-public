//  NovaNativeBaseAd.swift
//  NovaCore
//
//  Created by Shanyu Li on 2024/11/21.
//

import Foundation
import MSPiOSCore
import UIKit

enum NovaPopupCTAStyleVariant: String {
    case legacy
    case v2
}

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
        ctaStyle: NovaAdCtaStyle?,
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
        htmlPageItems: [PageItem]?,
        popupCTAStyleVariant: NovaPopupCTAStyleVariant
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
        self._htmlPageItems = htmlPageItems
        self.popupCTAStyleVariant = popupCTAStyleVariant
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
            ctaStyle: ctaStyle
        )
        setupAppInfo()
        self.mediaContent = try NovaAdMediaContent(adMedia: getAdMedia(), discountTagInfo: self.adDiscountTagInfo)
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
        _htmlPageItems = try container.decodeIfPresent([PageItem].self, forKey: .pageItems)
        mediaContent = NovaAdMediaContent(adMedia: Self.defaultAdMedia)
        popupCTAStyleVariant = .legacy

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        setupAppInfo()
        mediaContent = try NovaAdMediaContent(adMedia: getAdMedia(), discountTagInfo: adDiscountTagInfo)
    }

    deinit {
        NovaAdImpressionTimeTracker.clear(encryptedAdToken: encryptedAdToken)
        NovaAdImageMetricReporter.clear(encryptedAdToken: encryptedAdToken)
        NovaAdVideoMetricReporter.clear(encryptedAdToken: encryptedAdToken)
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
        case pageItems
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

    let popupCTAStyleVariant: NovaPopupCTAStyleVariant

    // media used to render media view
    public private(set) var mediaContent: NovaAdMediaContent

    /// Optional MRAID delegate for this ad. If not set, SDK falls back to default
    /// MRAID behaviors (play video with AVPlayer, save picture to Photos, and
    /// create calendar events with EventKit).


    // MARK: - Discount Tag

    var adDiscountTagInfo: NovaAdDiscountTagInfo?

    // MARK: - App install
    lazy var appStoreId: Int? = {
        switch adCtrType {
        case .openWeb:
            return nil
        case let .appInstall(model):
            return model.storeId
        case let .playable(model):
            switch model.launchAdType {
            case .openWeb:
                return nil
            case let .appInstall(model):
                return model.storeId
            case .playable:
                assertionFailure("playable ad can not have playable as launch type")
                return nil
            }
        }
    }()
    var appInfo: AsyncValue<NovaAdAppInfo>?

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
        try container.encode(_htmlPageItems, forKey: .pageItems)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }

    // MARK: Private

    private static let defaultAdMedia: NovaAdMedia = .image(
        model: .init(
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
    var _htmlPageItems: [PageItem]?
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
                throw NovaAdMediaError.invalid(
                    adId: adId, creativeType: creativeType, message: "missing multiple items info")
            }
        case .playableImage:
            return try .imagePlayable(
                imageModel: makeImageModel(),
                playableModel: makePlayableModel()
            )
        case .playableVideo:
            return try .videoPlayable(
                videoModel: makeVideoModel(),
                playableModel: makePlayableModel()
            )
        case .html:
            return try .html(model: makeHtmlModel())
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
        let imageFallbackOrientation: NovaNativeMediaLayoutOrientation =
            if let _isImageLayoutVertical {
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
                advertiser: advertiser,
                iconURL: iconURL,
                popupCTAStyleVariant: popupCTAStyleVariant,
                endCardModel: endCardModel
            )
        } else {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing video info")
        }
    }

    func makePlayableModel() throws -> NovaAdPlayableMediaModel {
        guard let info = _playableInfo, case let .playable(model) = adCtrType else {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing playable info")
        }

        return .init(
            playableActionModel: model,
            layout: info.layout,
            actionBarFormat: info.actionBarFormat,
            tapToTryFormat: info.tapToTryFormat,
            appInfo: appInfo
        )
    }

    func makeHtmlModel() throws -> NovaAdHtmlMediaModel {
        guard let _htmlPageItems else {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: "missing html page items")
        }

        let validPageItems = _htmlPageItems.compactMap { (pageItem) -> NovaAdHtmlPageModel? in
            guard
                let resource: NovaAdHtmlResource = {
                    let url: URL? =
                        if let urlString = pageItem.url, let url = URL(string: urlString) {
                            url
                        } else {
                            nil
                        }

                    if let html = pageItem.html {
                        return .html(html, baseUrl: url)
                    } else if let url {
                        return .url(url)
                    } else {
                        return nil
                    }
                }()
            else {
                return nil
            }

            return NovaAdHtmlPageModel(
                resource: resource,
                closeCountDownSeconds: pageItem.skipCountdown ?? 0,
                closeDelaySeconds: pageItem.skipDelay ?? 0,
                useClickUrl: pageItem.useClickUrl ?? false,
                useCustomClose: pageItem.useCustomClose ?? false,
                appStoreId: self.appStoreId,
                theme: pageItem.theme
            )
        }

        do {
            return try NovaAdHtmlMediaModel(pages: validPageItems)
        } catch {
            throw NovaAdMediaError.invalid(adId: adId, creativeType: creativeType, message: error.localizedDescription)
        }
    }


    func setupAppInfo() {
        appInfo = {
            if let appStoreId {
                return AsyncValue(
                    priority: .background,
                    operation: {
                        try await NovaAdAppInfo.appInfo(for: appStoreId)
                    })
            } else {
                return nil
            }
        }()
    }
}
