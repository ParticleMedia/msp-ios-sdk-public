import Foundation

public final class NovaNativeAdItem: NovaNativeBaseAd {
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
        addOnItem: NovaNativeAdInteractiveBanner?,
        eCPMInDollar: Decimal,
        isParallax: Bool,
        htmlPageItems: [PageItem]?,
        popupCTAStyleVariant: NovaPopupCTAStyleVariant
    ) throws {
        self.addOnItem = addOnItem
        self.eCPMInDollar = eCPMInDollar
        self.isParallax = isParallax
        self._layoutStyle = layoutStyle

        try super.init(
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
            ctaStyle: ctaStyle,
            creativeType: creativeType,
            headline: headline,
            body: body,
            callToAction: callToAction,
            advertiser: advertiser,
            iconURL: iconURL,
            isImageLayoutVertical: isImageLayoutVertical,
            isImageClickable: isImageClickable,
            imageURLs: imageURLs,
            imageContentMode: imageContentMode,
            videoInfo: videoInfo,
            multipleItemsInfo: multipleItemsInfo,
            adDiscountTagInfo: adDiscountTagInfo,
            layoutStyle: layoutStyle,
            marketingType: marketingType,
            playableInfo: playableInfo,
            htmlPageItems: htmlPageItems,
            popupCTAStyleVariant: popupCTAStyleVariant
        )
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    // MARK: Public

    /// Delegate used to handle ad state update. For example, ad impression or ad click.
    public weak var delegate: NovaNativeAdDelegate?

    public var layoutStyle: NovaNativeLayoutStyle {
        if skOverlayAppStoreId != nil {
            return .skOverlay
        }

        if let _layoutStyle {
            return _layoutStyle
        }

        switch creativeType {
        case .nativeVideo, .playableVideo:
            return _videoInfo?.isLayoutVertical == true ? .vertical : .horizontal
        case .nativeImage, .businessProfile, .fullImage, .playableImage:
            return _isImageLayoutVertical == true ? .vertical : .horizontal
        case .sponsoredContent:
            return .sponsor
        case .carousel:
            switch _multipleItemsInfo?.style {
            case .carousel:
                return .carousel
            case .collection:
                return .collection
            case .none:
                return .unknown
            }
        case .html:
            return .unknown
        }
    }

    // MARK: - NovaNativeMediaProviding

    override func makeImageModel() throws -> NovaAdImageMediaModel {
        try makeImageModel(with: layoutStyle.mediaOrientation)
    }

    override func makeVideoModel() throws -> NovaAdVideoMediaModel {
        try makeVideoModel(with: layoutStyle.mediaOrientation)
    }

    // MARK: Internal

    /// interactive banner on immersive video
    let addOnItem: NovaNativeAdInteractiveBanner?

    // Note (Wayne)
    // The following variables are used for ad loggings for in-feed unit.
    // Will remove these once we migrate to use master coordinator.

    let eCPMInDollar: Decimal

    var cellIndexPath: IndexPath?

    var dedupUUID: String?

    /// Time to load this ad after placehoder shows, measured in ms.
    var impressionLatency: Double = 0.0

    let isParallax: Bool

    // MARK: Private

    // MARK: - Layout

    private var _layoutStyle: NovaNativeLayoutStyle?
}

extension NovaNativeAdItem {
    public var skOverlayAppStoreId: Int? {
        guard ctaStyle == .downloadBanner else {
            return nil
        }
        return appStoreId
    }

    public var skOverlayTrackingURL: URL? {
        guard ctaStyle == .downloadBanner else {
            return nil
        }
        switch adCtrType {
        case let .appInstall(model):
            return model.fallbackWebModel.url
        case let .playable(model):
            switch model.launchAdType {
            case let .appInstall(model):
                return model.fallbackWebModel.url
            case .openWeb, .playable:
                return nil
            }
        case .openWeb:
            return nil
        }
    }

    public var novaAdReportContext: NovaAdReportContext {
        .init(
            advertiser: advertiser,
            headline: headline,
            body: body,
            adId: adId,
            adSetId: adSetId,
            adRequestId: requestId,
            encryptedToken: encryptedAdToken
        )
    }
}
