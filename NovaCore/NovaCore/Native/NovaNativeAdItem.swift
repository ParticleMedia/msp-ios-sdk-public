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
        creativeType: NovaCreativeType,
        headline: String?,
        body: String?,
        callToAction: String?,
        advertiser: String?,
        iconUrlStr: String?,
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
        isParallax: Bool
    ) throws {
        self.addOnItem = addOnItem
        self.eCPMInDollar = eCPMInDollar
        self.isParallax = isParallax

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
            creativeType: creativeType,
            headline: headline,
            body: body,
            callToAction: callToAction,
            advertiser: advertiser,
            iconUrlStr: iconUrlStr,
            isImageLayoutVertical: isImageLayoutVertical,
            isImageClickable: isImageClickable,
            imageURLs: imageURLs,
            imageContentMode: imageContentMode,
            videoInfo: videoInfo,
            multipleItemsInfo: multipleItemsInfo,
            adDiscountTagInfo: adDiscountTagInfo,
            layoutStyle: layoutStyle,
            marketingType: marketingType,
            playableInfo: playableInfo
        )
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    // MARK: Internal

    /// Delegate used to handle ad state update. For example, ad impression or ad click.
    public weak var delegate: NovaNativeAdDelegate?

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

    var layoutStyle: NovaNativeLayoutStyle {
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
        }
    }


    // MARK: Private

    // MARK: - Layout

    private var _layoutStyle: NovaNativeLayoutStyle?
}
