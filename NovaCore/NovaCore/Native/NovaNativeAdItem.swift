//import NBVideoPlayer
import Foundation

@objc public final class NovaNativeAdItem: NovaBaseAd {
    // MARK: - Properties

    /// Headline.
    @objc public let headline: String?

    /// Description.
    @objc public let body: String?

    /// Whether to use static image in immersive video
    public let isImageClickable: Bool

    /// video info
    public let videoInfo: NovaNativeAdVideoInfo?

    /// CTA button text.
    @objc public let callToAction: String?

    /// Identify the advertiser. For example, advertiser's name or visible url.
    @objc public let advertiser: String?

    /// Creative Type.
    public let creativeType: NovaCreativeType?

    public let iconUrlStr: String?
    
    /// interactive banner on immersive video
    public let addOnItem: NovaNativeAdInteractiveBanner?

    /// Decide how to open ad. For example, using browser or in-app web view.
    let launchOption: NovaAdLaunchOption

    /// Delegate used to handle ad state update. For example, ad impression or ad click.
    @objc public weak var delegate: NovaNativeAdDelegate?

    /*
     * Note (Wayne)
     * The following variables are used for ad loggings for in-feed unit.
     * Will remove these once we migrate to use master coordinator.
     */

    @objc public let eCPMInDollar: Decimal

    @objc public var cellIndexPath: IndexPath?

    @objc public var dedupUUID: String?

    /// Time to load this ad after placehoder shows, measured in ms.
    @objc public var impressionLatency: Double = 0.0

    public let isParallax: Bool

    // MARK: -

    init(
        adUnitId: String,
        requestId: String,
        adId: String,
        adSetId: String,
        eCPMInDollar: Decimal,
        headline: String?,
        body: String?,
        callToAction: String?,
        creativeType: NovaCreativeType?,
        imageUrlStr: String?,
        isImageClickable: Bool,
        videoInfo: NovaNativeAdVideoInfo?,
        advertiser: String?,
        iconUrlStr: String?,
        addOnItem: NovaNativeAdInteractiveBanner?,
        ctrUrl: URL?,
        launchOption: NovaAdLaunchOption,
        thirdPartyViewTrackingUrls: [String],
        thirdPartyImpressionTrackingUrls: [String],
        thirdPartyClickTrackingUrls: [String],
        priceInDollar: Double?,
        encryptedAdToken: String,
        isParallax: Bool
    ) {
        self.eCPMInDollar = eCPMInDollar
        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.advertiser = advertiser
        self.creativeType = creativeType
        self.iconUrlStr = iconUrlStr
        self.launchOption = launchOption
        self.isImageClickable = isImageClickable
        self.videoInfo = videoInfo
        self.isParallax = isParallax
        self.addOnItem = addOnItem

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
        fatalError("init(from:) has not been implemented")
    }

    deinit {
        if let videoInfo = videoInfo {
            DispatchQueue.main.async {
                NovaVideoPlayerCacheHandler.shared.removePlayer(cacheKey: videoInfo.cacheKey)
            }
        }
    }

    @objc public func downloadMedia() {
        if let videoInfo = videoInfo,
           let videoUrl = URL(string: videoInfo.videoUrlStr) {
            DispatchQueue.main.async {
                NovaVideoPlayerCacheHandler.shared.getControllerToPreload(cacheKey: videoInfo.cacheKey, url: videoUrl)
            }
        }
    }
}
