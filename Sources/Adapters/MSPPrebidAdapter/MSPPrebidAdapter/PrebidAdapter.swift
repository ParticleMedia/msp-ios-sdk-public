//import shared
import Foundation
import MSPiOSCore
import PrebidMobile
import UIKit

@objc public class PrebidAdapter: NSObject, AdNetworkAdapter {
    private static let DEFAULT_AUCTION_TIMEOUT_MS: Int = 30 * 1000
    
    public func getSDKVersion() -> String {
        Prebid.shared.version
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .prebid
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
    }

    // MARK: - BannerEventHandler
    public weak var loadingDelegate: BannerEventLoadingDelegate?
    public weak var interactionDelegate: BannerEventInteractionDelegate?
    public var adSizes: [CGSize] = []

    public func destroyAd() {
    }

    private static var isInitialized = false

    private static func setupPrebid(
        initParams: InitializationParameters, adapterInitListener: AdapterInitListener
    ) {
        guard !isInitialized else {
            adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: "")
            return
        }
        isInitialized = true

        do {
            try Prebid.shared.setCustomPrebidServer(url: initParams.getPrebidHostUrl())
            Prebid.shared.prebidServerAccountId = initParams.getPrebidAPIKey()
            let bidRequestTimeoutMillis = initParams.getParameters()?[InitializationParametersCustomKeys.PREBID_BID_REQUEST_TIMEOUT_MILLIS] as? Int ?? DEFAULT_AUCTION_TIMEOUT_MS
            Prebid.shared.timeoutMillis = bidRequestTimeoutMillis
            // Workaround for Prebid SDK bug: timeoutMillis.didSet stores the raw millisecond
            // value into timeoutMillisDynamic, but PBMBidRequester.m reads it as seconds
            // (without dividing by 1000). Resetting to nil forces the correct /1000 path.
            Prebid.shared.timeoutMillisDynamic = nil
            Prebid.initializeSDK { status, error in
                if status == .successed {
                    adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: "")
                } else {
                    adapterInitListener.onComplete(
                        adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: error?.localizedDescription ?? "")
                }
            }
        } catch {
            adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: "")
        }
    }

    public static func initializePrebid(
        initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?
    ) {
        setupPrebid(initParams: initParams, adapterInitListener: adapterInitListener)
    }


    public func initialize(
        initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?
    ) {
        Self.setupPrebid(initParams: initParams, adapterInitListener: adapterInitListener)
    }

    public weak var adListener: AdListener?

    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public var bannerView: BannerView?
    public var priceInDollar: Double?

    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?
    private weak var bannerAd: BannerAd?

    private weak var interstitialAd: PrebidInterstitialAd?
    public var interstitialRenderingAdUnit: InterstitialRenderingAdUnit?

    private var adMetricReporter: AdMetricReporter?
    private var adLoadStartTime: TimeInterval = 0

    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any,
        adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String: String]?
    ) {
        adLoadStartTime = Date().timeIntervalSince1970
        guard bidResponse is BidResponse,
            let mBidResponse = bidResponse as? BidResponse
        else {
            return
        }
        self.adRequest = adRequest
        self.bidResponse = mBidResponse
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        let width = Int(adRequest.adSize?.width ?? 320)
        let height = Int(adRequest.adSize?.height ?? 50)

        let adSize = CGSize(width: width, height: height)

        DispatchQueue.main.async {
            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
            self.adListener = adListener
            if adRequest.adFormat == .interstitial {
                var interstitialRenderingAdUnit = InterstitialRenderingAdUnit(configID: adRequest.placementId)
                self.interstitialRenderingAdUnit = interstitialRenderingAdUnit
                interstitialRenderingAdUnit.delegate = self
                interstitialRenderingAdUnit.handleBidResponse(response: mBidResponse)
            } else if adRequest.adFormat == .rewarded {
                self.loadRewardedAdIfSupported(
                    bidResponse: bidResponse,
                    auctionBidListener: auctionBidListener,
                    adListener: adListener,
                    context: context,
                    adRequest: adRequest,
                    bidderPlacementId: bidderPlacementId,
                    params: params
                )
            } else {
                var bannerView = BannerView(
                    frame: CGRect(origin: .zero, size: adSize),
                    configID: adRequest.placementId,
                    adSize: adSize,
                    eventHandler: self)
                self.bannerView = bannerView

                bannerView.delegate = self
                bannerView.refreshInterval = 0
                bannerView.handleBidResponse(response: mBidResponse)
            }
        }
    }

    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = self.bannerAd
            {
                self.adMetricReporter?.logAdHide(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot,
                    fullScreenShot: fullScreenShot)
            }
        }
    }

    public func sendDismissAdEvent() {
        if let adRequest = self.adRequest,
            let ad = self.interstitialAd
        {
            self.adMetricReporter?.logAdDismiss(ad: ad, adRequest: adRequest, bidResponse: self.bidResponse ?? self)
        }
    }

    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = self.bannerAd
            {
                self.adMetricReporter?.logAdReport(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description,
                    adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
            }
        }
    }

    private func sendClickAdEvent(ad: MSPAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let bidResponse = self.bidResponse
            {
                self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
            }
        }
    }
}

extension PrebidAdapter: BannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController? {
        if Thread.isMainThread {
            return self.adListener?.getRootViewController()
        } else {
            return DispatchQueue.main.sync {
                self.adListener?.getRootViewController()
            }
        }
        //return self.adListener?.getRootViewController()
    }

    @objc public func bannerViewDidReceiveBidResponse(_ bannerView: BannerView) {
        self.bannerView?.loadAdContent()
    }

    @objc public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        MSPLogger.shared.info(message: "[Adapter: Prebid] successfully loaded Prebid Banner ad")
        DispatchQueue.main.async {
            var prebidAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = prebidAd
            if let priceInDollar = self.priceInDollar {
                prebidAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }

            if let burl = self.bidResponse?.winningBid?.bid.burl {
                prebidAd.adInfo[MSPConstants.AD_INFO_OPENRTB_BURL] = self.replaceMacroAuctionPrice(
                    url: burl, price: self.priceInDollar)
            }
            if let nurl = self.bidResponse?.winningBid?.bid.nurl {
                prebidAd.adInfo[MSPConstants.AD_INFO_OPENRTB_NURL] = self.replaceMacroAuctionPrice(
                    url: nurl, price: self.priceInDollar)
            }
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                prebidAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }

            prebidAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = self.bidResponse?.winningBidSeat
            prebidAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid

            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: prebidAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: prebidAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: prebidAd, fill: true, isFromCache: false)
            }
        }
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        adRequest?.s2sLatencyInfo.adLoadLatencyMs = Int32((Date().timeIntervalSince1970 - adLoadStartTime) * 1000)
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "msp",
            bidderPlacementId: bidderPlacementId,
            ecpm: ad.adInfo["price"] as? Double ?? 0.0,
            loadInfo: buildLoadInfo(bidResponse: self.bidResponse))
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil,
                bidResponse: self.bidResponse)
        }
    }

    @objc public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Prebid] Fail to load Prebid Banner ad")
            self.handleAuctionBidError(error: "fail to get ad", bidResponse: self.bidResponse)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error.localizedDescription, bidResponse: self.bidResponse)
            }
        }
    }

    @objc public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        if let prebidAd = self.bannerAd {
            adListener?.onAdClick(ad: prebidAd)
            self.sendClickAdEvent(ad: prebidAd)
        }
    }

    @objc public func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        if let prebidAd = self.bannerAd {
            adListener?.onAdClick(ad: prebidAd)
            self.sendClickAdEvent(ad: prebidAd)
        }
    }

    private func replaceMacroAuctionPrice(url: String?, price: Double?) -> String? {
        guard let price = price else {
            return url
        }
        return url?.replacingOccurrences(of: "${AUCTION_PRICE}", with: String(price))
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

extension PrebidAdapter: BannerEventHandler {
    public func requestAd(with bidResponse: BidResponse?) {
        loadingDelegate?.prebidDidWin()
    }

    public func trackImpression() {
        DispatchQueue.main.async {
            if let prebidAd = self.bannerAd {
                self.adListener?.onAdImpression(ad: prebidAd)
                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdImpression(ad: prebidAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }
}

extension PrebidAdapter: InterstitialAdUnitDelegate {
    @objc public func interstitialDidReceiveAd(_ interstitial: PrebidMobile.InterstitialRenderingAdUnit) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Prebid] successfully loaded Prebid Interstitial ad")
            var interstitialAd = PrebidInterstitialAd(adNetworkAdapter: self)
            self.interstitialAd = interstitialAd
            interstitialAd.rootViewController = self.adListener?.getRootViewController()
            interstitialAd.interstitialRenderingAdUnit = interstitial
            if let priceInDollar = self.priceInDollar {
                interstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }

            if let burl = self.bidResponse?.winningBid?.bid.burl {
                interstitialAd.adInfo[MSPConstants.AD_INFO_OPENRTB_BURL] = self.replaceMacroAuctionPrice(
                    url: burl, price: self.priceInDollar)
            }
            if let nurl = self.bidResponse?.winningBid?.bid.nurl {
                interstitialAd.adInfo[MSPConstants.AD_INFO_OPENRTB_NURL] = self.replaceMacroAuctionPrice(
                    url: nurl, price: self.priceInDollar)
            }

            interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = self.bidResponse?.winningBidSeat
            interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                interstitialAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }
            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: prebidAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: interstitialAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: interstitialAd, fill: true, isFromCache: false)
            }
        }
    }

    /// Called when the load process fails to produce a viable ad
    @objc public func interstitial(
        _ interstitial: PrebidMobile.InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: (any Error)?
    ) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Prebid] Fail to load Prebid Interstitial ad")
            self.handleAuctionBidError(error: error?.localizedDescription ?? "", bidResponse: self.bidResponse)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error?.localizedDescription ?? "", bidResponse: self.bidResponse)
            }
        }
    }

    /// Called when the interstitial view will be launched,  as a result of show() method.
    @objc public func interstitialWillPresentAd(_ interstitial: PrebidMobile.InterstitialRenderingAdUnit) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdImpression(ad: interstitialAd)

                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdImpression(
                        ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }

    /// Called when the interstitial is dismissed by the user
    @objc public func interstitialDidDismissAd(_ interstitial: PrebidMobile.InterstitialRenderingAdUnit) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
            self.sendDismissAdEvent()
        }
    }

    /// Called when user clicked the ad
    @objc public func interstitialDidClickAd(_ interstitial: PrebidMobile.InterstitialRenderingAdUnit) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
            self.sendClickAdEvent(ad: interstitialAd)
        }
    }
}
