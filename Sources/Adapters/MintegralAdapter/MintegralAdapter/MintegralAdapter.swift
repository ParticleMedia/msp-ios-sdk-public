//
//  MintegralAdapter.swift
//  MintegralAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//
//import shared
import Foundation
import MSPiOSCore
import MTGSDK
import MTGSDKBanner
import MTGSDKBidding
import MTGSDKNewInterstitial
import MTGSDKReward
import PrebidMobile

@objc public class MintegralAdapter: NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        MTGSDK.sdkVersion()
    }


    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public var adUnitId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: MTGBannerAdView?

    public var mintegralInterstitialAdManager: MTGNewInterstitialBidAdManager?
    public weak var interstitialAd: MintegralInterstitialAd?

    public var mintegralRewardAdManager: MTGBidRewardAdManager?
    public weak var rewardedAd: MintegralRewardedAd?

    public var mintegralNativeAdManager: MTGBidNativeAdManager?
    public var nativeAdItem: MTGCampaign?
    public weak var nativeAd: MintegralNativeAd?

    private var adMetricReporter: AdMetricReporter?

    private var priceInDollar: Double?
    private var mtgBidResponse: MTGBiddingResponse?


    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?,
        params: [String: String]?
    ) {
        DispatchQueue.main.async {
            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId

            // Set price and bid response for all ad formats
            if let priceStr = params?["price"] {
                self.priceInDollar = Double(priceStr) ?? 0.0
            } else {
                self.priceInDollar = 0.0
            }
            
            let adFormat = bidderFormat ?? adRequest.adFormat
            self.adUnitId = params?["mintegralAdUnitAd"] as? String
            if adFormat == .interstitial {
                self.loadInterstitialAd(
                    auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest,
                    bidderPlacementId: bidderPlacementId, params: params)
            } else if adFormat == .native {
                self.loadNativeAd(
                    auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest,
                    bidderPlacementId: bidderPlacementId, params: params)
            } else if adFormat == .rewarded {
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
                self.loadBanenrAd(
                    auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest,
                    bidderPlacementId: bidderPlacementId, params: params)
            }
        }
    }

    public func initialize(
        initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener,
        context: Any?
    ) {
        MTGSDK.sharedInstance().setAppID(
            initParams.getParameters()?[InitializationParametersCustomKeys.MINTEGRAL_APP_ID] as? String ?? "",
            apiKey: initParams.getParameters()?[InitializationParametersCustomKeys.MINTEGRAL_API_KEY] as? String ?? "")
        adapterInitListener.onComplete(adNetwork: .mintegral, adapterInitStatus: .SUCCESS, message: "")
    }

    public func destroyAd() {
    }

@MainActor
 public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        DispatchQueue.main.async {
            guard let nativeAdView = nativeAdView as? NativeAdView,
                let nativeAdItem = self.nativeAdItem
            else { return }

            if let nativeAdContainer = nativeAdView.nativeAdContainer {
                let mediaView = MTGMediaView()
                mediaView.setMediaSourceWith(nativeAdItem, unitId: self.adUnitId ?? "")
                mediaView.delegate = self
                nativeAdContainer.getTitle()?.text = nativeAdItem.appName
                nativeAdContainer.getbody()?.text = nativeAdItem.appDesc
                //nativeAdContainer.getAdvertiser()?.text = nativeAdItem.
                nativeAdContainer.getCallToAction()?.setTitle(nativeAdItem.adCall, for: .normal)


                if let mediaContainer = nativeAdContainer.getMedia() {
                    mediaContainer.translatesAutoresizingMaskIntoConstraints = false
                    mediaView.translatesAutoresizingMaskIntoConstraints = false
                    mediaView.contentMode = .scaleAspectFit
                    mediaContainer.addSubview(mediaView)
                    NSLayoutConstraint.activate([
                        //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                        mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                        mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                        mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                        mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
                        //mediaView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor)
                    ])
                }

                let adChoiceView = MTGAdChoicesView()
                adChoiceView.isHidden = false
                nativeAdContainer.addSubview(adChoiceView)
                NSLayoutConstraint.activate([
                    adChoiceView.topAnchor.constraint(equalTo: nativeAdContainer.topAnchor),
                    adChoiceView.trailingAnchor.constraint(equalTo: nativeAdContainer.trailingAnchor),
                    adChoiceView.widthAnchor.constraint(equalToConstant: nativeAdItem.adChoiceIconSize.width),
                    adChoiceView.heightAnchor.constraint(equalToConstant: nativeAdItem.adChoiceIconSize.height),
                    //mediaView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor)
                ])

                var clickableViews: [UIView] = []

                for view in [
                    nativeAdView, nativeAdContainer.getTitle(), nativeAdContainer.getbody(),
                    nativeAdContainer.getMedia(), nativeAdContainer.getAdvertiser(),
                    nativeAdContainer.getCallToAction(),
                ] {
                    if let view = view {
                        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                        //view.addGestureRecognizer(tapGesture)
                        clickableViews.append(view)
                    }
                }
                self.mintegralNativeAdManager?.registerView(
                    forInteraction: mediaView, withClickableViews: clickableViews, with: nativeAdItem)

                nativeAdView.addSubview(nativeAdContainer)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    nativeAdContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                    nativeAdContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                    nativeAdContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                    nativeAdContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                    nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                    nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
                ])
            }
        }
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "mintegral",
            bidderPlacementId: bidderPlacementId,
            ecpm: ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double ?? 0.0,
            loadInfo: [:]
        )
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .mintegral
    }

    private func loadBanenrAd(
        auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String: String]?
    ) {
        var floor: NSNumber?
        if let floorStr = params?["floor"] {
            floor = NumberFormatter().number(from: floorStr)
        }
        let bannerParam = MTGBiddingBannerRequestParameter(
            placementId: bidderPlacementId,
            unitId: self.adUnitId ?? "",
            basePrice: floor ?? 0.0,
            unitSize: CGSize(width: adRequest.adSize?.width ?? 320, height: adRequest.adSize?.height ?? 50)
        )
        MTGBiddingRequest.getBidWith(bannerParam) { [weak self] bidResponse in
            if bidResponse.success {
                self?.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self?.bannerView = MTGBannerAdView(
                    bannerAdViewWithAdSize: CGSize(
                        width: adRequest.adSize?.width ?? 320, height: adRequest.adSize?.height ?? 50),
                    placementId: bidderPlacementId,
                    unitId: self?.adUnitId ?? "",
                    rootViewController: adListener.getRootViewController())
                self?.bannerView?.delegate = self
                self?.bannerView?.autoRefreshTime = 0
                self?.bannerView?.loadBannerAd(withBidToken: bidResponse.bidToken)
            } else {
                auctionBidListener.onError(error: "Mintegral bid fail")
            }
        }
    }

    private func loadNativeAd(
        auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String: String]?
    ) {
        var floor: NSNumber?
        if let floorStr = params?["floor"] {
            floor = NumberFormatter().number(from: floorStr)
        }
        let nativeParams = MTGBiddingRequestParameter(
            placementId: bidderPlacementId,
            unitId: self.adUnitId ?? "",
            basePrice: floor ?? 0.0)
        MTGBiddingRequest.getBidWith(nativeParams) { [weak self] bidResponse in
            if bidResponse.success {
                self?.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self?.mintegralNativeAdManager = MTGBidNativeAdManager(
                    placementId: bidderPlacementId,
                    unitID: self?.adUnitId ?? "",
                    presenting: adListener.getRootViewController())
                self?.mintegralNativeAdManager?.delegate = self
                self?.mintegralNativeAdManager?.load(withBidToken: bidResponse.bidToken)
            } else {
                auctionBidListener.onError(error: "Mintegral bid fail")
            }
        }
    }

    private func loadInterstitialAd(
        auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String: String]?
    ) {
        var floor: NSNumber?
        if let floorStr = params?["floor"] {
            floor = NumberFormatter().number(from: floorStr)
        }

        let interstitialParams = MTGBiddingRequestParameter(
            placementId: bidderPlacementId,
            unitId: self.adUnitId ?? "",
            basePrice: floor ?? 0.0)

        MTGBiddingRequest.getBidWith(interstitialParams) { [weak self] bidResponse in
            guard let self = self else {
                auctionBidListener.onError(error: "Mintegral bid fail")
                return
            }
            if bidResponse.success {
                self.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self.mintegralInterstitialAdManager = MTGNewInterstitialBidAdManager(
                    placementId: bidderPlacementId,
                    unitId: self.adUnitId ?? "",
                    delegate: self)
                self.mintegralInterstitialAdManager?.loadAd(withBidToken: bidResponse.bidToken)
            } else {
                auctionBidListener.onError(error: "Mintegral bid fail")
            }
        }
    }

    private func loadRewardedAd(
        auctionBidListener: AuctionBidListener, adListener: AdListener, adRequest: AdRequest,
        bidderPlacementId: String, params: [String: String]?
    ) {
        DispatchQueue.main.async {
            guard let adUnitId = params?["mintegralAdUnitAd"] as? String else {
                auctionBidListener.onError(error: "Failed to load mintegral rewarded ad: adUnitId is nil")
                return
            }
            
            self.mintegralRewardAdManager = MTGBidRewardAdManager.sharedInstance()

            if let bidResponse = self.mtgBidResponse {
                self.mintegralRewardAdManager?.loadVideo(
                    withBidToken: bidResponse.bidToken,
                    placementId: bidderPlacementId,
                    unitId: adUnitId,
                    delegate: self
                )
            } else {
                auctionBidListener.onError(error: "Mintegral rewarded bid fail")
            }
        }
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

    public func sendClickAdEvent(ad: MSPAd) {
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: nil)
        }
    }
}

extension MintegralAdapter: MTGBannerAdViewDelegate {
    public func adViewLoadSuccess(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else { return }
            if let bannerView = self.bannerView {
                MSPLogger.shared.info(message: "[Adapter: Mintegral] successfully loaded Mintegral Banner ad")
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.mtgBidResponse?.price ?? 0.0
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mintegral.rawValue
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = adView.creativeId
                self.handleAdLoaded(
                    ad: bannerAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "mintegral_placement_id")
            }
        }
    }

    public func adViewLoadFailedWithError(_ error: (any Error)!, adView: MTGBannerAdView!) {
        MSPLogger.shared.info(message: "[Adapter: Mintegral] Fail to load Mintegral banner ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error.localizedDescription)
        }
    }

    public func adViewWillLogImpression(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self)
                }
            }
        }
    }

    public func adViewDidClicked(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            if let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
                self.sendClickAdEvent(ad: bannerAd)
            }
        }
    }

    public func adViewWillLeaveApplication(_ adView: MTGBannerAdView!) {
    }

    public func adViewWillOpenFullScreen(_ adView: MTGBannerAdView!) {
    }

    public func adViewCloseFullScreen(_ adView: MTGBannerAdView!) {
    }

    public func adViewClosed(_ adView: MTGBannerAdView!) {
    }
}


extension MintegralAdapter: MTGNewInterstitialBidAdDelegate {
    public func newInterstitialBidAdResourceLoadSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else { return }

            if let mintegralInterstitialAdManager = self.mintegralInterstitialAdManager {
                MSPLogger.shared.info(message: "[Adapter: Mintegral] successfully loaded Mintegral Interstitial ad")
                let interstitialAd = MintegralInterstitialAd(adNetworkAdapter: self)
                interstitialAd.mintegralInterstitialAdManager = mintegralInterstitialAdManager
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.mtgBidResponse?.price ?? 0.0
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mintegral.rawValue
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = adManager.getCreativeId(
                    withUnitId: adManager.currentUnitId)
                self.handleAdLoaded(
                    ad: interstitialAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "mintegral")
            }
        }
    }

    public func newInterstitialAdLoadFail(_ error: NSError, _ adManager: MTGNewInterstitialAdManager) {
        MSPLogger.shared.info(message: "[Adapter: Mintegral] Fail to load Mintegral Interstitial ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
    }

    public func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self)
                }
            }
        }
    }

    public func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        // to do: investigate why it is called multiple times
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
                self.sendClickAdEvent(ad: interstitialAd)
            }
        }
    }

    public func newInterstitialBidAdDidClosed(_ adManager: MTGNewInterstitialBidAdManager) {
        if let interstitialAd = self.interstitialAd {
            adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
}

extension MintegralAdapter: MTGBidNativeAdManagerDelegate, MTGMediaViewDelegate {
    public func nativeAdsLoaded(_ nativeAds: [Any]?, bidNativeManager: MTGBidNativeAdManager) {
        if let nativeAdItem = nativeAds?[0] as? MTGCampaign {
            MSPLogger.shared.info(message: "[Adapter: Mintegral] successfully loaded Mintegral Native ad")
            DispatchQueue.main.async {
                self.nativeAdItem = nativeAdItem
                if let auctionBidListener = self.auctionBidListener {
                    var mintegralNativeAd = MintegralNativeAd(
                        adNetworkAdapter: self,
                        title: nativeAdItem.appName,
                        body: nativeAdItem.appDesc,
                        advertiser: "",
                        callToAction: nativeAdItem.adCall)
                    mintegralNativeAd.nativeAdItem = nativeAdItem
                    self.nativeAd = mintegralNativeAd
                    mintegralNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.mtgBidResponse?.price ?? 0.0
                    mintegralNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mintegral.rawValue
                    mintegralNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                    mintegralNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = nativeAdItem.creativeId
                    if let adListener = self.adListener,
                        let adRequest = self.adRequest,
                        let auctionBidListener = self.auctionBidListener
                    {
                        self.handleAdLoaded(
                            ad: mintegralNativeAd, auctionBidListener: auctionBidListener,
                            bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                    }
                }
            }
        }
    }

    public func nativeAdsFailedToLoadWithError(_ error: Error, bidNativeManager: MTGBidNativeAdManager) {
        MSPLogger.shared.info(message: "[Adapter: Mintegral] Fail to load Mintegral Native ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
    }

    public func nativeAdDidClick(_ nativeAd: MTGCampaign, bidNativeManager: MTGBidNativeAdManager) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
                self.sendClickAdEvent(ad: nativeAd)
            }
        }
    }

    public func nativeAdImpression(with type: MTGAdSourceType, bidNativeManager: MTGBidNativeAdManager) {
        //TO do: investigate why it is not working
        /*
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd,
               let adRequest = self.adRequest {
                self.adListener?.onAdImpression(ad: nativeAd)
                var params = [String:Any?]()
                params["seat"] = "mintegral"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.mtgBidResponse?.price ?? 0.0
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
            }
        }
         */
    }

    public func nativeAdImpression(with type: MTGAdSourceType, mediaView: MTGMediaView) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd,
                let adRequest = self.adRequest
            {
                self.adListener?.onAdImpression(ad: nativeAd)
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self)
            }
        }
    }
}

// MARK: - MTGRewardAdLoadDelegate

extension MintegralAdapter: MTGRewardAdLoadDelegate {
    
    public func onVideoAdLoadSuccess(_ placementId: String!, unitId: String!) {
        MSPLogger.shared.info(message: "[Adapter: Mintegral] Successfully loaded Mintegral rewarded ad")
        
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener,
                  let bidderPlacementId = self.bidderPlacementId,
                  let rewardedManager = self.mintegralRewardAdManager,
                  let resolvedUnitId = unitId ?? self.adUnitId else {
                return
            }
            
            let reward = self.adRequest?.reward ?? Reward(type: "reward", amount: 1)
            
            let rewardedAd = MintegralRewardedAd(
                adNetworkAdapter: self,
                reward: reward,
                placementId: placementId ?? bidderPlacementId,
                unitId: resolvedUnitId,
                mtgRewardAdManager: rewardedManager
            )
            self.rewardedAd = rewardedAd
            
            // Set ad info
            rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mintegral.rawValue
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
    
    public func onVideoAdLoadFailed(_ placementId: String!, unitId: String!, error: Error!) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        MSPLogger.shared.info(
            message: "[Adapter: Mintegral] Fail to load Mintegral rewarded ad: \(errorMessage)")
        
        self.auctionBidListener?.onError(error: "Failed to load mintegral rewarded ad: \(errorMessage)")
        
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
                errorMessage: errorMessage
            )
        }
    }
}

// MARK: - Rewarded Ad Support Override

extension MintegralAdapter {
    
    /// Provide Mintegral rewarded ad support
    public func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    ) {
        self.loadRewardedAd(
            auctionBidListener: auctionBidListener,
            adListener: adListener,
            adRequest: adRequest,
            bidderPlacementId: bidderPlacementId,
            params: params
        )
    }
}
