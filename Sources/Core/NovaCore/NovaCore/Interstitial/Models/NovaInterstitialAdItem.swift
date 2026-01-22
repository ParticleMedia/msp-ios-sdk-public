//
//  NovaInterstitialAd.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

public final class NovaInterstitialAdItem: NovaNativeBaseAd {
    // MARK: - Properties

    let startTimeInMs: Double?
    let expirationTimeInMs: Double?

    let closeCountDownTimeSeconds: Int?

    let clickableComponents: [NovaClickableComponent]?

    /// Delegate used to handle ad state update. For example, ad impression or ad click.
    public weak var delegate: NovaInterstitialAdDelegate?

    // MARK: - Layout

    private var _layoutStyle: NovaInterstitialAdLayout?

    var layoutStyle: NovaInterstitialAdLayout {
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
            return .horizontal
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
        startTimeInMs: Double?,
        expirationTimeInMs: Double?,
        headline: String?,
        body: String?,
        callToAction: String?,
        advertiser: String?,
        iconUrl: URL?,
        isVerticalImage: Bool?,
        isImageClickable: Bool,
        imageContentMode: NovaNativeImageContentMode?,
        imageUrls: [String]?,
        novaInterstitialAdLayout: NovaInterstitialAdLayout?,
        videoInfo: NovaNativeAdVideoInfo?,
        multipleItemsInfo: NovaAdMultipleItemsInfo?,
        adDiscountTagInfo: NovaAdDiscountTagInfo?,
        layoutStyle: NovaNativeLayoutStyle?,
        marketingType: NovaAdMarketingType,
        playableInfo: NovaAdPlayableInfo?,
        closeCountDownTimeSeconds: Int?,
        clickableComponents: [NovaClickableComponent]?,
        htmlPageItems: [PageItem]?,
        popupCTAStyleVariant: NovaPopupCTAStyleVariant
    ) throws {
        self.startTimeInMs = startTimeInMs
        self.expirationTimeInMs = expirationTimeInMs
        self._layoutStyle = novaInterstitialAdLayout
        self.closeCountDownTimeSeconds = closeCountDownTimeSeconds
        self.clickableComponents = clickableComponents

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
            supportOCPM: supportOCPM,
            creativeType: creativeType,
            headline: headline,
            body: body,
            callToAction: callToAction,
            advertiser: advertiser,
            iconURL: iconUrl,
            isImageLayoutVertical: isVerticalImage,
            isImageClickable: isImageClickable,
            imageURLs: imageUrls,
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
        let container = try decoder.container(keyedBy: CodingKeys.self)

        startTimeInMs = try container.decodeIfPresent(Double.self, forKey: .startTimeInMs)
        expirationTimeInMs = try container.decodeIfPresent(Double.self, forKey: .expirationTimeInMs)
        _layoutStyle = try container.decodeIfPresent(NovaInterstitialAdLayout.self, forKey: .novaInterstitialAdLayout)
        closeCountDownTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .closeCountDownTimeSeconds)
        clickableComponents = try container.decodeIfPresent([NovaClickableComponent].self, forKey: .clickableComponents)
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }

    private weak var viewController: UIViewController?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case startTimeInMs
        case expirationTimeInMs
        case novaInterstitialAdLayout
        case closeCountDownTimeSeconds
        case clickableComponents
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(startTimeInMs, forKey: .startTimeInMs)
        try container.encode(expirationTimeInMs, forKey: .expirationTimeInMs)

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }

    public func present(rootViewController: UIViewController, reportHandling: NovaInterstitialAdReportHandling) {
        requestToDisplay(rootViewController: rootViewController, reportHandling: reportHandling)
    }

    func requestToDisplay(
        rootViewController: UIViewController,
        reportHandling: NovaInterstitialAdReportHandling
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        let viewController = NovaInterstitialAdViewController(interstitialAd: self, reportHandling: reportHandling)
        self.viewController = viewController
        viewController.modalPresentationStyle = .fullScreen
        viewController.modalTransitionStyle = .crossDissolve

        rootViewController.present(viewController, animated: true)
    }

    public func dismiss(animated: Bool) {
        viewController?.dismiss(animated: animated) {
            self.delegate?.interstitialAdDidDismiss(self)
        }
    }
}
