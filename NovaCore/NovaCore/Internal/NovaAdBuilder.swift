import Foundation

// MARK: - NovaAdBuildError

enum NovaAdBuildError: LocalizedError {
    case invalidCreativeType
    case invalidCtrUrlStr
    case invalidPlayableUrlStr

    var errorDescription: String? {
        switch self {
        case .invalidCreativeType:
            return "Invalid creative type"
        case .invalidCtrUrlStr:
            return "Invalid CTR URL string"
        case .invalidPlayableUrlStr:
            return "Invalid playable URL string"
        }
    }
}

// MARK: - AbConfigKeys

enum AbConfigKeys {
    static let discountTagStyle = "ios_discount_tag_style"
    static let multipleItemsStyle = "ios_carousel_style"
    static let immersivePlayableUIStyle = "immersive_playable_ui"
}

// MARK: - AdScene

enum AdScene {
    case banner
    case appOpen
    case native
}

// MARK: - NovaAdBuilder

public enum NovaAdBuilder {
    public static func buildNativeAd(
        adItem: AdItem,
        adUnitId: String,
        eCPMInDollar: Decimal,
        abConfig: [String: String]? = nil,
        isParallax: Bool = false
    ) throws -> NovaNativeAdItem {
        let creativeType = try NovaAdBuilder.buildCreativeType(creative: adItem.creative)

        let adCtrType = try NovaAdBuilder.buildCtrType(creative: adItem.creative)

        let iconURL = adItem.creative.iconUrl.flatMap(URL.init(string:))
        let videoInfo = NovaAdBuilder.buildVideoInfo(adItem.creative.videoItem, adId: adItem.adId)

        let thirdPartyViewTrackingUrls = adItem.creative.thirdPartyViewTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []
        let thirdPartyImpressionTrackingUrls = adItem.creative.thirdPartyImpressionTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []
        let thirdPartyClickTrackingUrls = adItem.creative.thirdPartyClickTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []

        return try NovaNativeAdItem(
            adUnitId: adUnitId,
            requestId: adItem.requestId,
            adId: adItem.adId,
            adSetId: adItem.adsetId,
            imageUrlStr: adItem.creative.imageUrl,
            adCtrType: adCtrType,
            thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
            thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
            thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
            priceInDollar: adItem.price,
            encryptedAdToken: adItem.encryptedAdToken,
            creativeType: creativeType,
            headline: adItem.creative.headline,
            body: adItem.creative.body,
            callToAction: adItem.creative.callToAction,
            advertiser: adItem.creative.advertiser,
            iconURL: iconURL,
            isImageLayoutVertical: adItem.creative.isVerticalImage,
            isImageClickable: adItem.creative.isImageClickable ?? false,
            imageURLs: adItem.creative.imageUrls,
            imageContentMode: NovaNativeImageContentMode(rawValue: adItem.creative.imageScaleMode ?? ""),
            videoInfo: videoInfo,
            multipleItemsInfo: buildMultipleItemsInfo(
                adItem.creative.carouselItems,
                externalAppStoreId: adItem.creative.appStoreId,
                launchOption: adItem.creative.launchOption,
                abConfig: abConfig,
                adId: adItem.adId
            ),
            adDiscountTagInfo: buildAdDiscountTagInfo(adItem.creative.tagItem, abConfig: abConfig),
            layoutStyle: NovaNativeLayoutStyle(rawValue: adItem.creative.layout ?? ""),
            marketingType: buildMarketingType(item: adItem.creative.tagItem),
            playableInfo: buildPlayableInfo(adItem.creative.playableItem, for: .native, abConfig: abConfig),
            addOnItem: buildInteractiveBanner(adItem.creative.addonItem),
            eCPMInDollar: Decimal(adItem.price ?? 0),
            isParallax: isParallax
        )
    }

    public static func buildInterstitialAd(
        adItem: AdItem,
        adUnitId: String,
        eCPMInDollar: Decimal,
        abConfig: [String: String]? = nil
    ) -> NovaInterstitialAdItem? {
        guard let creativeType = try? NovaAdBuilder.buildCreativeType(creative: adItem.creative) else {
            DebugLogger.data.error("Missing valid creative type: ad id: \(adItem.adId)")
            return nil
        }
        guard let adCtrType = try? NovaAdBuilder.buildCtrType(creative: adItem.creative) else {
            DebugLogger.data.error("Missing valid ctr type: ad id: \(adItem.adId)")
            return nil
        }

        let videoInfo = buildVideoInfo(adItem.creative.videoItem, adId: adItem.adId)
        let iconURL = adItem.creative.iconUrl.flatMap(URL.init(string:))

        let thirdPartyViewTrackingUrls = adItem.creative.thirdPartyViewTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []
        let thirdPartyImpressionTrackingUrls = adItem.creative.thirdPartyImpressionTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []
        let thirdPartyClickTrackingUrls = adItem.creative.thirdPartyClickTrackingUrls?.map {
            NovaAdUrlTransformer.replaceMacro(in: $0)
        } ?? []

        let startTimeInMs = Double(adItem.startTimeMs ?? "")
        let expirationTimeInMs = Double(adItem.expirationMs ?? "")

        do {
            let adItem = try NovaInterstitialAdItem(
                adUnitId: adUnitId,
                requestId: adItem.requestId,
                adId: adItem.adId,
                adSetId: adItem.adsetId,
                imageUrlStr: adItem.creative.imageUrl,
                adCtrType: adCtrType,
                thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
                thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
                thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
                priceInDollar: adItem.price,
                encryptedAdToken: adItem.encryptedAdToken,
                creativeType: creativeType,
                startTimeInMs: startTimeInMs,
                expirationTimeInMs: expirationTimeInMs,
                headline: adItem.creative.headline,
                body: adItem.creative.body,
                callToAction: adItem.creative.callToAction,
                advertiser: adItem.creative.advertiser,
                iconUrl: iconURL,
                isVerticalImage: adItem.creative.isVerticalImage,
                isImageClickable: adItem.creative.isImageClickable ?? false,
                imageContentMode: NovaNativeImageContentMode(rawValue: adItem.creative.imageScaleMode ?? ""),
                imageUrls: adItem.creative.imageUrls,
                novaInterstitialAdLayout: NovaInterstitialAdLayout(rawValue: adItem.creative.layout ?? ""),
                videoInfo: videoInfo,
                multipleItemsInfo: buildMultipleItemsInfo(
                    adItem.creative.carouselItems,
                    externalAppStoreId: adItem.creative.appStoreId,
                    launchOption: adItem.creative.launchOption,
                    abConfig: abConfig,
                    adId: adItem.adId
                ),
                adDiscountTagInfo: buildAdDiscountTagInfo(adItem.creative.tagItem, abConfig: abConfig),
                layoutStyle: NovaNativeLayoutStyle(rawValue: adItem.creative.layout ?? ""),
                marketingType: buildMarketingType(item: adItem.creative.tagItem),
                playableInfo: buildPlayableInfo(adItem.creative.playableItem, for: .appOpen, abConfig: abConfig),
                closeCountDownTimeSeconds: Int(adItem.creative.closeCountDownSeconds ?? ""),
                clickableComponents: adItem.creative.clickableComponents?
                    .compactMap { NovaClickableComponent(rawValue: $0) }
            )
            return adItem
        } catch {
            DebugLogger.data.error("Failed to build interstitial ad item: \(error.localizedDescription)")
            return nil
        }
    }

    public static func buildInterstitialAds(
        adItems: [AdItem],
        adUnitId: String,
        abConfig: [String: String]?
    ) -> [NovaInterstitialAdItem] {
        return adItems.compactMap { (adItem: AdItem) -> NovaInterstitialAdItem? in
            guard let creativeType = try? NovaAdBuilder.buildCreativeType(creative: adItem.creative) else {
                DebugLogger.data.error("Missing valid creative type: ad id: \(adItem.adId)")
                return nil

            }
            guard let adCtrType = try? NovaAdBuilder.buildCtrType(creative: adItem.creative) else {
                DebugLogger.data.error("Missing valid ctr type: ad id: \(adItem.adId)")
                return nil
            }

            let iconURL = adItem.creative.iconUrl.flatMap(URL.init(string:))

            let videoInfo = buildVideoInfo(adItem.creative.videoItem, adId: adItem.adId)

            let thirdPartyViewTrackingUrls = adItem.creative.thirdPartyViewTrackingUrls?.map {
                NovaAdUrlTransformer.replaceMacro(in: $0)
            } ?? []
            let thirdPartyImpressionTrackingUrls = adItem.creative.thirdPartyImpressionTrackingUrls?.map {
                NovaAdUrlTransformer.replaceMacro(in: $0)
            } ?? []
            let thirdPartyClickTrackingUrls = adItem.creative.thirdPartyClickTrackingUrls?.map {
                NovaAdUrlTransformer.replaceMacro(in: $0)
            } ?? []

            let startTimeInMs = Double(adItem.startTimeMs ?? "")
            let expirationTimeInMs = Double(adItem.expirationMs ?? "")

            do {
                let adItem = try NovaInterstitialAdItem(
                    adUnitId: adUnitId,
                    requestId: adItem.requestId,
                    adId: adItem.adId,
                    adSetId: adItem.adsetId,
                    imageUrlStr: adItem.creative.imageUrl,
                    adCtrType: adCtrType,
                    thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
                    thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
                    thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
                    priceInDollar: adItem.price,
                    encryptedAdToken: adItem.encryptedAdToken,
                    creativeType: creativeType,
                    startTimeInMs: startTimeInMs,
                    expirationTimeInMs: expirationTimeInMs,
                    headline: adItem.creative.headline,
                    body: adItem.creative.body,
                    callToAction: adItem.creative.callToAction,
                    advertiser: adItem.creative.advertiser,
                    iconUrl: iconURL,
                    isVerticalImage: adItem.creative.isVerticalImage,
                    isImageClickable: adItem.creative.isImageClickable ?? false,
                    imageContentMode: NovaNativeImageContentMode(rawValue: adItem.creative.imageScaleMode ?? ""),
                    imageUrls: adItem.creative.imageUrls,
                    novaInterstitialAdLayout: NovaInterstitialAdLayout(rawValue: adItem.creative.layout ?? ""),
                    videoInfo: videoInfo,
                    multipleItemsInfo: buildMultipleItemsInfo(
                        adItem.creative.carouselItems,
                        externalAppStoreId: adItem.creative.appStoreId,
                        launchOption: adItem.creative.launchOption,
                        abConfig: abConfig,
                        adId: adItem.adId
                    ),
                    adDiscountTagInfo: buildAdDiscountTagInfo(adItem.creative.tagItem, abConfig: abConfig),
                    layoutStyle: NovaNativeLayoutStyle(rawValue: adItem.creative.layout ?? ""),
                    marketingType: buildMarketingType(item: adItem.creative.tagItem),
                    playableInfo: buildPlayableInfo(adItem.creative.playableItem, for: .appOpen, abConfig: abConfig),
                    closeCountDownTimeSeconds: Int(adItem.creative.closeCountDownSeconds ?? ""),
                    clickableComponents: adItem.creative.clickableComponents?
                        .compactMap { NovaClickableComponent(rawValue: $0) }
                )
                return adItem
            } catch {
                DebugLogger.data.error("Failed to build interstitial ad item: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

// MARK: - Private methods

private extension NovaAdBuilder {
    static func buildCreativeType(creative: Creative) throws -> NovaCreativeType {
        guard let creativeType = NovaCreativeType(rawValue: creative.creativeType ?? "") else {
            throw NovaAdBuildError.invalidCreativeType
        }
        return creativeType
    }

    static func buildCtrType(creative: Creative) throws -> AdCtrType {
        switch NovaCreativeType(rawValue: creative.creativeType ?? "") {
        case .playableImage, .playableVideo:
            guard let playableUrlStr = creative.playableItem?.url,
                  let playableUrl = URL(string: NovaAdUrlTransformer.replaceMacro(in: playableUrlStr))
            else {
                throw NovaAdBuildError.invalidPlayableUrlStr
            }

            let playableModel = try PlayableModel(
                playableUrl: playableUrl,
                fallback: buildBaseCtrType(
                    urlStr: creative.ctrUrl,
                    launchOption: creative.launchOption,
                    appStoreId: creative.appStoreId
                ),
                playableArea: AdPlayableArea(rawValue: creative.playableItem?.clickAreaMode ?? "") ?? .all
            )
            return .playable(model: playableModel)
        case .businessProfile, .fullImage, .nativeImage, .nativeVideo, .sponsoredContent, .carousel:
            return try buildBaseCtrType(
                urlStr: creative.ctrUrl,
                launchOption: creative.launchOption,
                appStoreId: creative.appStoreId
            )
        case .none:
            throw NovaAdBuildError.invalidCreativeType
        }
    }

    static func buildBaseCtrType(urlStr: String, launchOption: String?, appStoreId: String?) throws -> AdCtrType {
        let transformedUrlStr = NovaAdUrlTransformer.replaceMacro(in: urlStr)
        guard let url = URL(string: transformedUrlStr) else {
            throw NovaAdBuildError.invalidPlayableUrlStr
        }

        let openBrowser = NovaAdLaunchOption(rawValue: launchOption ?? "") == .launchBrowser

        if let appStoreId, !appStoreId.isEmpty, let appStoreIdInInt = Int(appStoreId) {
            return .appInstall(
                model: AppInstallModel(
                    storeId: appStoreIdInInt,
                    fallbackWebModel: OpenWebModel(url: url, openBrowser: openBrowser)
                )
            )
        } else {
            return .openWeb(model: OpenWebModel(url: url, openBrowser: openBrowser))
        }
    }

    static func buildVideoInfo(_ videoItem: VideoItem?, adId: String) -> NovaNativeAdVideoInfo? {
        guard let videoItem = videoItem, let videoUrlStr = videoItem.videoUrl else { return nil }

        return NovaNativeAdVideoInfo(
            adId: adId,
            coverUrlStr: videoItem.coverUrl,
            videoUrlStr: videoUrlStr,
            isLayoutVertical: videoItem.isVertical ?? false,
            isVideoClickable: videoItem.isVideoClickable ?? false,
            isPlayOnLandingPage: videoItem.isPlayOnLandingPage ?? false,
            isAuto: videoItem.isPlayAutomatically ?? true,
            isMute: videoItem.isMute ?? true,
            isLoop: videoItem.isLoop ?? true,
            endCardStyle: NovaNativeAdEndCardStyle(rawValue: videoItem.endCardStyle ?? "")
        )
    }

    static func buildInteractiveBanner(_ addOnItem: AddOnItem?) -> NovaNativeAdInteractiveBanner? {
        guard let type = addOnItem?.type,
              let type = InteractiveBannerType(rawValue: type),
              let url = addOnItem?.imageUrl,
              let imageUrl = URL(string: url),
              let displayTime = addOnItem?.displayTime
        else {
            return nil
        }

        return NovaNativeAdInteractiveBanner(type: type, imageUrl: imageUrl, displayTime: .milliseconds(displayTime))
    }

    static func buildMultipleItemsInfo(
        _ items: [MultipleItemsItem]?,
        externalAppStoreId: String?,
        launchOption: String?,
        abConfig: [String: String]?,
        adId: String
    ) -> NovaAdMultipleItemsInfo? {
        guard items?.isEmpty == false else {
            return nil
        }
        let items = items?.compactMap { (item: MultipleItemsItem) -> NovaNativeMultipleItemsItem? in
            guard let imageUrlStr = item.imageUrl, let imageURL = URL(string: imageUrlStr),
                  let body = item.body,
                  let callToAction = item.callToAction
            else {
                return nil
            }
            guard let ctrUrl = item.ctrUrl, let ctrType = try? Self.buildBaseCtrType(
                urlStr: ctrUrl,
                launchOption: launchOption,
                appStoreId: item.appStoreId ?? externalAppStoreId
            ) else {
                return nil
            }

            return NovaNativeMultipleItemsItem(
                imageUrl: imageURL,
                body: body,
                callToAction: callToAction,
                ctrType: ctrType
            )
        }
        let style = NovaAdMultipleItemsInfo.Style(
            rawValue: abConfig?[AbConfigKeys.multipleItemsStyle] ?? ""
        ) ?? .carousel

        do {
            return try NovaAdMultipleItemsInfo(items: items ?? [], style: style)
        } catch {
            DebugLogger.data.error("Ad With Id: \(adId) failed to build multiple items info: \(error.localizedDescription)")
            return nil
        }
    }

    static func buildAdDiscountTagInfo(_ item: TagItem?, abConfig: [String: String]?) -> NovaAdDiscountTagInfo? {
        guard let item else {
            return nil
        }

        let backgroundStyle = NovaAdDiscountTagStyle.Background(
            rawValue: (abConfig?[AbConfigKeys.discountTagStyle] ?? "")
        ) ?? .default
        return try? NovaAdDiscountTagInfo(from: item, backgroundStyle: backgroundStyle)
    }

    static func buildMarketingType(item: TagItem?) -> NovaAdMarketingType {
        guard let item else {
            return .normal
        }

        if item.style == "GAUSSIAN_BLUR" {
            return .dpa
        } else {
            return .normal
        }
    }

    static func buildPlayableInfo(
        _ playableItem: PlayableItem?,
        for scene: AdScene,
        abConfig: [String: String]?
    ) -> NovaAdPlayableInfo? {
        guard let playableItem else {
            return nil
        }
        guard let playableUrlStr = playableItem.url, let url = URL(string: playableUrlStr) else {
            return nil
        }

        let layout: NovaAdPlayableInfo.Layout = {
            switch scene {
            case .banner:
                return .showMedia
            case .appOpen:
                return .twoPart
            case .native:
                switch abConfig?[AbConfigKeys.immersivePlayableUIStyle] {
                case "exp1":
                    return .showPlayable
                case "exp2":
                    return .twoPart
                default:
                    return .showMedia
                }
            }
        }()

        return NovaAdPlayableInfo(
            playableUrl: url,
            playableArea: AdPlayableArea(rawValue: playableItem.clickAreaMode ?? "") ?? .all,
            layout: layout
        )
    }

}
