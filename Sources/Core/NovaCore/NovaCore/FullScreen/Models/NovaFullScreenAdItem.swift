//
//  NovaFullScreenAdItem.swift
//  NovaCore
//

import Foundation
import UIKit

/// Base class for full-screen Nova ad items (interstitial and rewarded).
/// Holds shared state: HTML preloading and the cached WebView.
/// Subclasses add format-specific properties (close countdown, expiration, reward tracking, etc.).
public class NovaFullScreenAdItem: NovaNativeBaseAd {

    // MARK: - Properties

    /// Whether the H5 WebView should be preloaded when the ad is loaded.
    public var shouldPreloadHtml: Bool

    /// Cached preloaded HTML view, ready to display when `present` is called.
    /// Intentionally `internal` (not `private`) — consumed and cleared by `NovaInterstitialAdPageSubviewHandler`
    /// after presenting the cached WebView to avoid a second load.
    var cachedHtmlView: NovaAdHtmlView?

    /// Weak reference to the presenting UIViewController, used to call `dismiss`.
    /// Set only via `storeViewController(_:)` — external callers must use that method.
    private(set) weak var viewController: UIViewController?

    // MARK: - Init

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
        imageContentMode: NovaNativeImageContentMode?,
        imageURLs: [String]?,
        videoInfo: NovaNativeAdVideoInfo?,
        multipleItemsInfo: NovaAdMultipleItemsInfo?,
        adDiscountTagInfo: NovaAdDiscountTagInfo?,
        layoutStyle: NovaNativeLayoutStyle?,
        marketingType: NovaAdMarketingType,
        playableInfo: NovaAdPlayableInfo?,
        htmlPageItems: [PageItem]?,
        popupCTAStyleVariant: NovaPopupCTAStyleVariant,
        shouldPreloadHtml: Bool
    ) throws {
        self.shouldPreloadHtml = shouldPreloadHtml
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

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shouldPreloadHtml = try container.decodeIfPresent(Bool.self, forKey: .shouldPreloadHtml) ?? false
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case shouldPreloadHtml
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shouldPreloadHtml, forKey: .shouldPreloadHtml)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }

    // MARK: - Presentation

    func storeViewController(_ viewController: UIViewController) {
        self.viewController = viewController
    }

    /// Dismisses the currently-presented full-screen ad view controller.
    /// Subclasses should override to fire their format-specific delegate callback after dismissal.
    public func dismiss(animated: Bool) {
        viewController?.dismiss(animated: animated)
    }

    /// Dismisses with a completion block. Intended for subclass use.
    func dismissViewController(animated: Bool, completion: (() -> Void)?) {
        viewController?.dismiss(animated: animated, completion: completion)
    }

    // MARK: - HTML Preloading

    /// Preloads the H5 WebView content.
    public func preloadHtmlView(enableFeedback: Bool, completion: @escaping () -> Void) {
        guard case let .html(model) = mediaContent.adMedia else {
            completion()
            return
        }
        let htmlView = NovaAdHtmlView(supportReportHandling: enableFeedback)
        cachedHtmlView = htmlView
        htmlView.preload(
            with: model.currentPage,
            completion: completion,
            tracingInfo: .init(adUnitId: adUnitId, encryptedToken: encryptedAdToken)
        )
    }
}
