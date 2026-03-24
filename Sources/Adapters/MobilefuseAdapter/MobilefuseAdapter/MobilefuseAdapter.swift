//
//  MobilefuseAdapter.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

//import shared
import Foundation
import MSPiOSCore
import MobileFuseSDK
import PrebidMobile

@objc public class MobilefuseAdapter: NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        MobileFuse.version()
    }


    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: MFBannerAd?

    private var interstitialAdItem: MFInterstitialAd?
    public weak var interstitialAd: MobilefuseInterstitialAd?

    private var rewardedAdItem: MFRewardedAd?
    public weak var rewardedAd: MobilefuseRewardedAd?

    private var nativeAdItem: MFNativeAd?
    public weak var nativeAd: MobilefuseNativeAd?

    private var adMetricReporter: AdMetricReporter?

    private var priceInDollar: Double?

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

            if let priceStr = params?["price"] {
                self.priceInDollar = Double(priceStr) ?? 0.0
            } else {
                self.priceInDollar = 0.0
            }

            let adFormat = bidderFormat ?? adRequest.adFormat

            if adFormat == .interstitial {
                self.interstitialAdItem = MFInterstitialAd(placementId: bidderPlacementId)
                self.interstitialAdItem?.register(self)

                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.interstitialAdItem?.testMode = true
                }
                self.interstitialAdItem?.load()
            } else if adFormat == .native {
                self.nativeAdItem = MFNativeAd(placementId: bidderPlacementId)
                self.nativeAdItem?.register(self)
                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.nativeAdItem?.testMode = true
                }
                self.nativeAdItem?.load()
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
                self.bannerView = MFBannerAd(
                    placementId: bidderPlacementId, with: self.getMFBannerAdSize(adRequest: adRequest))
                self.bannerView?.register(self)
                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.bannerView?.testMode = true
                }
                self.bannerView?.load()
            }
        }
    }

    public func initialize(
        initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener,
        context: Any?
    ) {
        MobileFuse.initWithDelegate(self)
        adapterInitListener.onComplete(adNetwork: .mobilefuse, adapterInitStatus: .SUCCESS, message: "")
    }

    public func destroyAd() {
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
            let nativeAdItem = self.nativeAdItem
        else { return }

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            //nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false


            if let mediaContainer = nativeAdContainer.getMedia(),
                let mediaView = nativeAdItem.getMainContentView()
            {
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
                ])
            }
            var clickableViews: [UIView] = []

            for view in [
                nativeAdView, nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getMedia(),
                nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction(),
                nativeAdItem.getMainContentView(),
            ] {
                if let view = view {
                    //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                    //view.addGestureRecognizer(tapGesture)
                    clickableViews.append(view)
                }
            }

            nativeAdItem.registerView(
                forInteraction: nativeAdItem.getMainContentView(), withClickableViews: clickableViews)

            //[nativeAd registerViewForInteraction:containerView withClickableViews:@[ ... ]];
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

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    private func getMFBannerAdSize(adRequest: AdRequest) -> MFBannerAdSize {
        if let width = adRequest.adSize?.width,
            let height = adRequest.adSize?.height
        {
            if width == 300, height == 250 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_300x250
            } else if width == 320, height == 50 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_320x50
            } else if width == 300, height == 50 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_300x50
            } else if width == 728, height == 90 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_728x90
            }
        }
        return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_DEFAULT
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "mobilefuse", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .mobilefuse
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

    private func sendClickAdEvent(ad: MSPAd) {
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: nil)
        }
    }
}

extension MobilefuseAdapter: IMFInitializationCallbackReceiver {
}

extension MobilefuseAdapter: IMFAdCallbackReceiver {
    public func onAdLoaded(_ ad: MFAd) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else { return }
            if ad is MFBannerAd,
                let bannerView = self.bannerView
            {
                MSPLogger.shared.info(message: "[Adapter: Mobilefuse] successfully loaded Mobilefuse Banner ad")
                let bannerAd = MobilefuseBannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mobilefuse.rawValue
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                bannerAd.show()
                self.handleAdLoaded(
                    ad: bannerAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
            } else if ad is MFInterstitialAd,
                let interstitialAdItem = self.interstitialAdItem
            {
                MSPLogger.shared.info(message: "[Adapter: Mobilefuse] successfully loaded Mobilefuse Interstitial ad")
                let interstitialAd = MobilefuseInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mobilefuse.rawValue
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                self.handleAdLoaded(
                    ad: interstitialAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
            } else if ad is MFRewardedAd,
                let rewardedAdItem = self.rewardedAdItem
            {
                MSPLogger.shared.info(message: "[Adapter: Mobilefuse] successfully loaded Mobilefuse Rewarded ad")

                // Create reward from adRequest or use default
                let reward = self.adRequest?.reward ?? Reward(type: "reward", amount: 1)

                let rewardedAd = MobilefuseRewardedAd(
                    adNetworkAdapter: self,
                    reward: reward,
                    mfRewardedAd: rewardedAdItem
                )
                self.rewardedAd = rewardedAd

                rewardedAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mobilefuse.rawValue
                rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId

                self.handleAdLoaded(
                    ad: rewardedAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
            } else if ad is MFNativeAd,
                let nativeAdItem = self.nativeAdItem
            {
                MSPLogger.shared.info(message: "[Adapter: Mobilefuse] successfully loaded Mobilefuse Native ad")
                DispatchQueue.main.async {
                    if let auctionBidListener = self.auctionBidListener {
                        let mobilefuseNativeAd = MobilefuseNativeAd(
                            adNetworkAdapter: self,
                            title: nativeAdItem.getTitle() ?? "",
                            body: nativeAdItem.getDescriptionText() ?? "",
                            advertiser: nativeAdItem.getSponsoredText() ?? "",
                            callToAction: nativeAdItem.getCtaButtonText() ?? "")
                        mobilefuseNativeAd.nativeAdItem = nativeAdItem
                        self.nativeAd = mobilefuseNativeAd
                        mobilefuseNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                        mobilefuseNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.mobilefuse.rawValue
                        mobilefuseNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId

                        if let adListener = self.adListener,
                            let adRequest = self.adRequest,
                            let auctionBidListener = self.auctionBidListener
                        {
                            //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                            self.handleAdLoaded(
                                ad: mobilefuseNativeAd, auctionBidListener: auctionBidListener,
                                bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
                            self.adMetricReporter?.logAdResult(
                                placementId: adRequest.placementId, ad: mobilefuseNativeAd, fill: true,
                                isFromCache: false)
                        }
                    }
                }
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }
    }

    public func onAdNotFilled(_ ad: MFAd) {
        if ad is MFBannerAd {
            MSPLogger.shared.info(message: "[Adapter: Mobilefuse] Fail to load Mobilefuse Banner ad")
        } else if ad is MFInterstitialAd {
            MSPLogger.shared.info(message: "[Adapter: Mobilefuse] Fail to load Mobilefuse Interstitial ad")
        } else if ad is MFNativeAd {
            MSPLogger.shared.info(message: "[Adapter: Mobilefuse] Fail to load Mobilefuse Native ad")
        }
        self.auctionBidListener?.onError(error: "fail to load ad")
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: nil)
        }
    }

    public func onAdRendered(_ ad: MFAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                if ad is MFBannerAd,
                    let bannerAd = self.bannerAd
                {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self)
                } else if ad is MFInterstitialAd,
                    let interstitialAd = self.interstitialAd
                {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self)
                } else if ad is MFNativeAd,
                    let nativeAd = self.nativeAd
                {
                    self.adListener?.onAdImpression(ad: nativeAd)
                    self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self)
                }
            }
        }
    }

    public func onAdClicked(_ ad: MFAd) {
        DispatchQueue.main.async {
            if ad is MFBannerAd,
                let bannerAd = self.bannerAd
            {
                self.adListener?.onAdClick(ad: bannerAd)
                self.sendClickAdEvent(ad: bannerAd)
            } else if ad is MFInterstitialAd,
                let interstitialAd = self.interstitialAd
            {
                self.adListener?.onAdClick(ad: interstitialAd)
                self.sendClickAdEvent(ad: interstitialAd)
            } else if ad is MFNativeAd,
                let nativeAd = self.nativeAd
            {
                self.adListener?.onAdClick(ad: nativeAd)
                self.sendClickAdEvent(ad: nativeAd)
            }
        }
    }

    public func onAdClosed(_ ad: MFAd) {
        DispatchQueue.main.async {
            if ad is MFInterstitialAd,
                let interstitialAd = self.interstitialAd
            {
                self.adListener?.onAdDismissed(ad: interstitialAd)
            }
        }
    }
}

// MARK: - Rewarded Ad Support Override

extension MobilefuseAdapter {
    /// Provide MobileFuse rewarded ad support
    public func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    ) {
        DispatchQueue.main.async {
            self.rewardedAdItem = MFRewardedAd(placementId: bidderPlacementId)
            self.rewardedAdItem?.register(self)

            if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                self.rewardedAdItem?.testMode = true
            }

            self.rewardedAdItem?.load()
        }
    }
}
