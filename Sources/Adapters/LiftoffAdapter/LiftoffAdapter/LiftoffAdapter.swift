//
//  LiftoffAdapter.swift
//  LiftoffAdapter
//
//  Created by Mingming Luo on 2025/12/9.
//

import Foundation
@_implementationOnly import MSPSnapKit
import MSPiOSCore
import PrebidMobile
import UIKit
import VungleAdsSDK

@objc public class LiftoffAdapter: NSObject, AdNetworkAdapter {
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?

    public weak var interstitialAd: LiftoffInterstitialAd?

    public weak var rewardedAd: LiftoffRewardedAd?

    public weak var nativeAd: LiftoffNativeAd?

    public var nativeAdView: NativeAdView?

    private var adMetricReporter: AdMetricReporter?

    private var priceInDollar: Double?

    private var bidResponse: BidResponse?

    /// Retains the VungleBannerView to ensure delegate callbacks are received.
    /// Without this reference, the view may be deallocated before `bannerAdDidLoad(_:)` is called.
    private var bannerView: VungleBannerView?

    public func initialize(
        initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener,
        context: Any?
    ) {
        VungleAds.setIntegrationName("vunglehbs", version: "67")
        let liftoffInitKey = MSPiOSCore.InitializationParametersCustomKeys.LIFTOFF_APP_ID
        let liftoffAppId = initParams.getParameters()?[liftoffInitKey] as? String ?? ""
        VungleAds.initWithAppId(liftoffAppId) { error in
            if let error = error {
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Liftoff] Liftoff SDK initialization failed with error: \(error.localizedDescription)"
                )
            } else {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] Liftoff SDK initialization successful")
            }
            adapterInitListener.onComplete(adNetwork: .liftoff, adapterInitStatus: .SUCCESS, message: "")
        }
    }

    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?,
        params: [String: String]?
    ) {
        DispatchQueue.main.async {
            guard bidResponse is BidResponse,
                let mBidResponse = bidResponse as? BidResponse
            else {
                self.handleAuctionBidError(error: "Failed to load Liftoff ad: invalid bidResponse")
                return
            }

            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId
            self.bidResponse = mBidResponse
            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0.0)

            let rootViewController = adListener.getRootViewController()

            guard let bidResponse = bidResponse as? BidResponse,
                let winningBid = bidResponse.winningBid
            else {
                self.handleAuctionBidError(
                    error: "Failed to load Liftoff ad: no winning bid", bidResponse: self.bidResponse)
                return
            }

            let adFormat = bidderFormat ?? adRequest.adFormat

            MSPLogger.shared.info(
                message:
                    "[Adapter: Liftoff] Start to load Liftoff creative ad. AdFormat = \(adFormat), placementId = \(bidderPlacementId)"
            )

            switch adFormat {
            case .interstitial:
                self.loadInterstitialAd(bidderPlacementId, winningBid, rootViewController, auctionBidListener)
            case .native:
                self.loadNativeAd(bidderPlacementId, winningBid, auctionBidListener)
            case .banner:
                self.loadBannerAd(bidderPlacementId, winningBid, adRequest, auctionBidListener)
            case .multi_format:
                self.loadMultiformatAd(bidderPlacementId, winningBid, adRequest, auctionBidListener)
            case .rewarded:
                self.loadRewardedAdIfSupported(
                    bidResponse: bidResponse,
                    auctionBidListener: auctionBidListener,
                    adListener: adListener,
                    context: context,
                    adRequest: adRequest,
                    bidderPlacementId: bidderPlacementId,
                    params: params
                )
            @unknown default:
                self.handleAuctionBidError(
                    error: "Failed to load liftoff ad: unknown ad format: \(adFormat)", bidResponse: self.bidResponse)
            }
        }
    }

    private func loadInterstitialAd(
        _ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?,
        _ auctionBidListener: AuctionBidListener
    ) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)
        guard let placementReferenceId = placementReferenceId else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff interstitial ad: placementReferenceId is nil",
                bidResponse: self.bidResponse)
            return
        }

        let interstitialAdItem = VungleInterstitial(placementId: placementReferenceId)

        interstitialAdItem.delegate = self

        guard let adm = winningBid.adm else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff interstitial ad: adm is nil", bidResponse: self.bidResponse)
            return
        }

        interstitialAdItem.load(adm)
    }

    private func loadRewardedAd(
        _ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?,
        _ auctionBidListener: AuctionBidListener
    ) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)
        guard let placementReferenceId = placementReferenceId else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff rewarded ad: placementReferenceId is nil",
                bidResponse: self.bidResponse)
            return
        }

        let rewardedAdItem = VungleRewarded(placementId: placementReferenceId)
        rewardedAdItem.delegate = self

        guard let adm = winningBid.adm else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff rewarded ad: adm is nil", bidResponse: self.bidResponse)
            return
        }

        rewardedAdItem.load(adm)
    }

    private func loadNativeAd(_ placementId: String, _ winningBid: Bid, _ auctionBidListener: AuctionBidListener) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)

        guard let placementReferenceId = placementReferenceId else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff native ad: placementReferenceId is nil", bidResponse: self.bidResponse)
            return
        }

        let nativeAdItem = VungleNative(placementId: placementReferenceId)

        nativeAdItem.delegate = self

        guard let adm = winningBid.adm else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff native ad: adm is nil", bidResponse: self.bidResponse)
            return
        }

        nativeAdItem.load(adm)
    }

    private func loadBannerAd(
        _ placementId: String, _ winningBid: Bid, _ adRequest: MSPiOSCore.AdRequest,
        _ auctionBidListener: AuctionBidListener
    ) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)

        guard let placementReferenceId = placementReferenceId else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff banner ad: placementReferenceId is nil", bidResponse: self.bidResponse)
            return
        }

        // pass width and height 0 here to let banner size decided from bid response adm
        let bannerSize = VungleAdSize.VungleAdSizeFromCGSize(CGSize(width: 0, height: 0))
        self.bannerView = VungleBannerView(placementId: placementReferenceId, vungleAdSize: bannerSize)

        self.bannerView?.delegate = self
        self.bannerView?.translatesAutoresizingMaskIntoConstraints = false

        guard let adm = winningBid.adm else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff banner ad: adm is nil", bidResponse: self.bidResponse)
            return
        }

        self.bannerView?.load(adm)
    }

    private func loadMultiformatAd(
        _ placementId: String, _ winningBid: Bid, _ adRequest: MSPiOSCore.AdRequest,
        _ auctionBidListener: any MSPiOSCore.AuctionBidListener
    ) {
        if let type = winningBid.bid.ext.prebid?.type {
            switch type {
            case "native":
                self.loadNativeAd(placementId, winningBid, auctionBidListener)
            case "banner":
                self.loadBannerAd(placementId, winningBid, adRequest, auctionBidListener)
            default:
                self.handleAuctionBidError(
                    error: "Failed to load liftoff ad: unsupported ad type: \(type)", bidResponse: self.bidResponse)
            }
        } else {
            self.handleAuctionBidError(
                error: "Failed to load liftoff ad: prebid type is nil", bidResponse: self.bidResponse)
        }
    }

    private func getPlacementReferenceId(winner: Bid) -> String? {
        let ext = winner.bid.rawJsonDictionary?["ext"] as? NSDictionary
        let vungle = ext?["vungle"] as? NSDictionary
        let placementReferenceId = vungle?["placement_reference_id"] as? String
        return placementReferenceId
    }

    public func destroyAd() {
        interstitialAd?.interstitialAdItem?.delegate = nil
        interstitialAd?.interstitialAdItem = nil

        interstitialAd?.destroy()
        interstitialAd = nil

        if let bannerView = bannerAd?.adView as? VungleBannerView {
            bannerView.delegate = nil
        }

        bannerView?.removeFromSuperview()
        bannerView?.delegate = nil
        bannerView = nil
        bannerAd?.destroy()
        bannerAd = nil

        nativeAd?.nativeAdItem?.unregisterView()
        nativeAd?.nativeAdItem?.delegate = nil
        nativeAd?.nativeAdItem = nil

        nativeAd?.destroy()
        nativeAd = nil
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
            let nativeAdItem = self.nativeAd?.nativeAdItem
        else { return }

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false

            // Get media view from native ad
            if let iconImage = nativeAdItem.iconImage {
                nativeAdContainer.getIcon()?.image = iconImage
            }


            // Create a MediaView for the native ad
            let mediaView = MediaView()
            if let mediaContainer = nativeAdContainer.getMedia() {
                mediaContainer.addSubview(mediaView)
                mediaView.snp.makeConstraints { make in
                    make.edges.equalTo(mediaContainer)
                }
            }

            let nilableClickableViews =
                [
                    nativeAdContainer.getTitle(),
                    nativeAdContainer.getbody(),
                    nativeAdContainer.getMedia(),
                    nativeAdContainer.getAdvertiser(),
                    nativeAdContainer.getCallToAction(),
                    nativeAdContainer.getIcon(),
                ] + (nativeAdContainer.getCustomClickableViews() ?? [])
            nativeAdItem.registerViewForInteraction(
                view: nativeAdView,
                mediaView: mediaView,
                iconImageView: nativeAdContainer.getIcon(),
                viewController: adListener?.getRootViewController(),
                clickableViews: nilableClickableViews.compactMap { $0 }
            )

            nativeAdView.addSubview(nativeAdContainer)
            nativeAdContainer.snp.makeConstraints { make in
                make.edges.equalTo(nativeAdView)
                make.width.lessThanOrEqualTo(nativeAdView)
                make.height.lessThanOrEqualTo(nativeAdView)
            }
        }
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .liftoff
    }

    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
            let ad = (self.bannerAd ?? self.nativeAd) ?? self.interstitialAd
        {
            self.adMetricReporter?.logAdHide(
                ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot,
                fullScreenShot: fullScreenShot)
        }
    }

    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
            let ad = (self.bannerAd ?? self.nativeAd) ?? self.interstitialAd
        {
            self.adMetricReporter?.logAdReport(
                ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description,
                adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }

    public func getSDKVersion() -> String {
        VungleAds.sdkVersion
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "liftoff",
            bidderPlacementId: bidderPlacementId,
            ecpm: ad.adInfo["price"] as? Double ?? 0.0,
            loadInfo: buildLoadInfo(bidResponse: self.bidResponse))
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }

    private func getMSPAd(ad: Any) -> MSPAd? {
        switch ad {
        case is VungleInterstitial:
            self.interstitialAd
        case is VungleBannerView:
            self.bannerAd
        case is VungleNative:
            self.nativeAd
        default:
            nil
        }
    }

    private func handleAuctionBidError(error: String, bidResponse: BidResponse? = nil) {
        guard let auctionBidListener = self.auctionBidListener else { return }

        if let bidResponse = bidResponse {
            let requestId = bidResponse.rawResponse?.requestID ?? ""
            auctionBidListener.onError(error: error, loadInfo: buildLoadInfo(bidResponse: bidResponse))
        } else {
            auctionBidListener.onError(error: error)
        }
    }

    private func buildLoadInfo(bidResponse: BidResponse?) -> [String: Any] {
        var loadInfo: [String: Any] = [:]

        if let requestId = bidResponse?.rawResponse?.requestID,
            !requestId.isEmpty
        {
            loadInfo["request_id"] = requestId
        }

        return loadInfo
    }
}

// MARK: - VungleInterstitialDelegate
extension LiftoffAdapter: VungleInterstitialDelegate {
    public func interstitialAdDidLoad(_ interstitial: VungleInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff interstitial ad")

                let interstitialAd = LiftoffInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitial
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd

                self.performHandleAdLoaded(
                    mspAd: interstitialAd,
                    creativeId: interstitial.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }

    public func interstitialAdDidFailToLoad(_ interstitial: VungleInterstitial, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message: "[Adapter: Liftoff] Fail to load Liftoff interstitial ad: \(withError.localizedDescription)")

            self.auctionBidListener?.onError(error: "fail to load interstitial ad: \(withError.localizedDescription)")

            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )

            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }

    public func interstitialAdDidTrackImpression(_ interstitial: VungleInterstitial) {
        handleAdImpressed(interstitial)
    }

    public func interstitialAdDidFailToPresent(_ interstitial: VungleInterstitial, withError: NSError) {
        MSPLogger.shared.info(
            message: "[Adapter: Liftoff] Fail to present Liftoff interstitial ad: \(withError.localizedDescription)")
    }

    public func interstitialAdDidClose(_ interstitial: VungleInterstitial) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }

    public func interstitialAdDidClick(_ interstitial: VungleInterstitial) {
        handleAdClicked(interstitial)
    }

    private func handleAdImpressed(_ ad: Any) {
        let mspAd = getMSPAd(ad: ad)

        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Show Liftoff ad successfully")
            self.adListener?.onAdImpression(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdImpression(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }

    private func handleAdClicked(_ ad: Any) {
        let mspAd = getMSPAd(ad: ad)

        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] liftoff ad clicked")
            self.adListener?.onAdClick(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdClick(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }

    private func performHandleAdLoaded(
        mspAd: MSPAd, creativeId: String?, placementId: String, auctionBidListener: AuctionBidListener
    ) {
        mspAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = "liftoff"
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
        if let creativeId = creativeId {
            mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = creativeId
        }
        if let requestId = self.bidResponse?.rawResponse?.requestID {
            mspAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
        }

        self.handleAdLoaded(
            ad: mspAd,
            auctionBidListener: auctionBidListener,
            bidderPlacementId: self.bidderPlacementId ?? "liftoff"
        )

        self.adMetricReporter?.logAdResult(
            placementId: placementId,
            ad: mspAd,
            fill: true,
            isFromCache: false
        )
    }
}

// MARK: - VungleBannerViewDelegate
extension LiftoffAdapter: VungleBannerViewDelegate {
    public func bannerAdDidLoad(_ banner: VungleBannerView) {
        let item = DispatchWorkItem {
            if let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff banner ad")

                // IMPORTANT: VungleBannerView contains a WebView subview that gets removed when
                // removeFromSuperview() is called, resulting in no content being displayed.
                // Solution: Wrap VungleBannerView in a container view to prevent direct removal.
                let containerView = UIView()
                containerView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(banner)
                banner.snp.makeConstraints { make in
                    make.edges.equalTo(containerView)
                }

                let bannerAd = BannerAd(adView: containerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd

                self.performHandleAdLoaded(
                    mspAd: bannerAd,
                    creativeId: banner.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }

        DispatchQueue.main.async(execute: item)
    }

    public func bannerAdDidFail(_ banner: VungleBannerView, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message: "[Adapter: Liftoff] Fail to load Liftoff banner ad: \(withError.localizedDescription)")

            self.auctionBidListener?.onError(error: "fail to load banner ad: \(withError.localizedDescription)")

            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )

            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }

    public func bannerAdDidFailToPresent(_ banner: VungleBannerView, withError: NSError) {
        MSPLogger.shared.info(
            message: "[Adapter: Liftoff] Fail to present Liftoff banner ad: \(withError.localizedDescription)")
    }

    public func bannerAdDidClick(_ banner: VungleBannerView) {
        handleAdClicked(banner)
    }

    public func bannerAdDidTrackImpression(_ bannerView: VungleBannerView) {
        handleAdImpressed(bannerView)
    }
}

// MARK: - VungleNativeDelegate
extension LiftoffAdapter: VungleNativeDelegate {
    public func nativeAdDidLoad(_ native: VungleNative) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff native ad")

                let builder = NativeAd.Builder(adNetworkAdapter: self)
                    .title(native.title)
                    .body(native.bodyText)
                    .advertiser(native.sponsoredText)
                    .callToAction(native.callToAction)
                    .icon(native.iconImage as Any)

                let nativeAd = LiftoffNativeAd(adNetworkAdapter: self, builder: builder)

                nativeAd.nativeAdItem = native
                self.nativeAd = nativeAd

                self.performHandleAdLoaded(
                    mspAd: nativeAd,
                    creativeId: native.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }

    public func nativeAdDidFailToLoad(_ native: VungleNative, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message: "[Adapter: Liftoff] Fail to load Liftoff native ad: \(withError.localizedDescription)")

            self.auctionBidListener?.onError(error: "fail to load native ad: \(withError.localizedDescription)")

            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )

            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }

    public func nativeAdDidFailToPresent(_ native: VungleNative, withError: NSError) {
        MSPLogger.shared.info(
            message: "[Adapter: Liftoff] Fail to present Liftoff native ad: \(withError.localizedDescription)")
    }

    public func nativeAdDidTrackImpression(_ native: VungleNative) {
        handleAdImpressed(native)
    }

    public func nativeAdDidClick(_ native: VungleNative) {
        handleAdClicked(native)
    }
}

// MARK: - VungleRewardedDelegate

extension LiftoffAdapter: VungleRewardedDelegate {
    public func rewardedAdDidLoad(_ rewarded: VungleRewarded) {
        MSPLogger.shared.info(message: "[Adapter: Liftoff] Successfully loaded Liftoff rewarded ad")

        DispatchQueue.main.async {
            guard let adListener = self.adListener,
                let auctionBidListener = self.auctionBidListener,
                let bidderPlacementId = self.bidderPlacementId
            else {
                return
            }

            // Create reward from adRequest or use default
            let reward = self.adRequest?.reward ?? Reward(type: "reward", amount: 1)

            let rewardedAd = LiftoffRewardedAd(
                adNetworkAdapter: self,
                reward: reward,
                vungleRewarded: rewarded
            )
            self.rewardedAd = rewardedAd

            // Set ad info
            rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.liftoff.rawValue
            rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = bidderPlacementId
            if let priceInDollar = self.priceInDollar {
                rewardedAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }

            self.handleAdLoaded(
                ad: rewardedAd,
                auctionBidListener: auctionBidListener,
                bidderPlacementId: bidderPlacementId
            )

            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: rewardedAd,
                fill: true,
                isFromCache: false
            )
        }
    }

    public func rewardedAdDidFailToLoad(_ rewarded: VungleRewarded, error: Error) {
        MSPLogger.shared.info(
            message: "[Adapter: Liftoff] Fail to load Liftoff rewarded ad: \(error.localizedDescription)")

        self.handleAuctionBidError(
            error: "Failed to load liftoff rewarded ad: \(error.localizedDescription)",
            bidResponse: self.bidResponse
        )

        self.adMetricReporter?.logAdResult(
            placementId: self.adRequest?.placementId ?? "",
            ad: nil,
            fill: false,
            isFromCache: false
        )

        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil,
                adRequest: adRequest,
                errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error.localizedDescription
            )
        }
    }

    // Note: Other VungleRewardedDelegate methods (impression, click, reward, dismiss, present failure)
    // are handled directly by LiftoffRewardedAd class through its own delegate conformance
}

// MARK: - Rewarded Ad Support Override

extension LiftoffAdapter {
    /// Provide Liftoff/Vungle rewarded ad support
    public func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    ) {
        guard let mBidResponse = bidResponse as? BidResponse,
            let winningBid = mBidResponse.winningBid
        else {
            self.handleAuctionBidError(
                error: "Failed to load Liftoff rewarded ad: invalid bidResponse",
                bidResponse: self.bidResponse
            )
            return
        }

        let rootViewController = adListener.getRootViewController()
        self.loadRewardedAd(bidderPlacementId, winningBid, rootViewController, auctionBidListener)
    }
}
