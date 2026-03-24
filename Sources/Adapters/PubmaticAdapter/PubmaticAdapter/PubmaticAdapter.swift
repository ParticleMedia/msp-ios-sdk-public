//
//  PubmaticAdapter.swift
//  PubmaticAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

//import shared
import Foundation
import MSPiOSCore
import OpenWrapSDK
import PrebidMobile

@objc public class PubmaticAdapter: NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        OpenWrapSDK.version()
    }


    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: POBBannerView?

    private var interstitialAdItem: POBInterstitial?
    public weak var interstitialAd: PubmaticInterstitialAd?

    private var rewardedAdItem: POBRewardedAd?
    public weak var rewardedAd: PubmaticRewardedAd?

    private var pubmaticNativeAdLoader: POBNativeAdLoader?
    private var nativeAdItem: POBNativeAd?
    public weak var nativeAd: PubmaticNativeAd?

    public var priceInDollar: Double?

    private var adMetricReporter: AdMetricReporter?

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

            let adFormat = bidderFormat ?? adRequest.adFormat

            let publisherId = params?["pubmaticPublisherId"] as? String ?? ""
            var profileId = NSNumber(value: 0)

            if let profileIdString = params?["pubmaticProfileId"] as? String,
                let profileIdInt = Int(profileIdString)
            {
                profileId = NSNumber(value: profileIdInt)
            }

            if adFormat == .interstitial {
                self.interstitialAdItem = POBInterstitial(
                    publisherId: publisherId,
                    profileId: profileId,
                    adUnitId: bidderPlacementId)
                self.interstitialAdItem?.delegate = self
                self.interstitialAdItem?.loadAd()
            } else if adFormat == .native {
                self.pubmaticNativeAdLoader = POBNativeAdLoader(
                    publisherId: publisherId, profileId: profileId, adUnitId: bidderPlacementId,
                    templateType: POBNativeTemplateType.medium)

                self.pubmaticNativeAdLoader?.delegate = self
                self.pubmaticNativeAdLoader?.bidEventDelegate = self
                self.pubmaticNativeAdLoader?.loadAd()
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
                self.bannerView = POBBannerView(
                    publisherId: publisherId, profileId: profileId, adUnitId: bidderPlacementId,
                    adSizes: [
                        POBAdSizeMake(CGFloat(adRequest.adSize?.width ?? 320), CGFloat(adRequest.adSize?.height ?? 50))
                    ])
                self.bannerView?.delegate = self
                self.bannerView?.loadAd()
            }
        }
    }

    public func initialize(
        initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener,
        context: Any?
    ) {
        let openWrapSDKConfig = OpenWrapSDKConfig(
            publisherId: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_PUBLISHER_ID]
                as? String ?? "",
            andProfileIds: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_PROFILE_IDS]
                as? [NSNumber] ?? [NSNumber]())

        OpenWrapSDK.initialize(with: openWrapSDKConfig) { (success, error) in
            if success {
                print("OpenWrap SDK initialization successful")
            } else if let error = error {
                print("OpenWrap SDK initialization failed with error : \(error.localizedDescription)")
            }

            // Set a valid App Store URL, containing the app id of your iOS app.
            let appInfo = POBApplicationInfo()
            if let storeUrl = URL(
                string: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_STORE_URL] as? String
                    ?? "")
            {
                appInfo.storeURL = storeUrl
            }
            // This application information is a global configuration & you
            // need not set this for every ad request(of any ad type)
            OpenWrapSDK.setApplicationInfo(appInfo)
            //OpenWrapSDK.setDSAComplianceStatus(.required)
            adapterInitListener.onComplete(adNetwork: .pubmatic, adapterInitStatus: .SUCCESS, message: "")
        }
    }

    public func destroyAd() {
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
            let nativeAdItem = self.nativeAdItem
        else { return }

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false

            let templateView = POBNativeAdMediumTemplateView()
            templateView.titleLabel = nativeAdContainer.getTitle()
            templateView.descriptionLabel = nativeAdContainer.getbody()
            templateView.ctaButton = nativeAdContainer.getCallToAction()
            let mediaView = UIImageView()
            templateView.mainImgView = mediaView

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
                    mediaView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor),
                ])
            }
            templateView.translatesAutoresizingMaskIntoConstraints = false
            templateView.addSubview(nativeAdContainer)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: templateView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: templateView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: templateView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: templateView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: templateView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: templateView.heightAnchor),
            ])

            nativeAdItem.renderAd(
                with: templateView,
                andCompletion: { [weak self] (nativeAd: POBNativeAd, error: Error?) in
                    guard let self = self else { return }
                    if let error = error {
                        print("Native : Failed to render ad with error - \(error.localizedDescription)")
                    } else {
                        // Attach native ad view.
                        let adView = nativeAd.adView()
                        adView.translatesAutoresizingMaskIntoConstraints = false
                        nativeAdView.addSubview(adView)
                        NSLayoutConstraint.activate([
                            //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                            adView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                            adView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                            adView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                            adView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                            adView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                            adView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
                        ])
                        print("Native : Ad rendered.")
                    }
                })
        }
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "pubmatic", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .pubmatic
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

extension PubmaticAdapter: POBBannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController {
        if let vc = self.adListener?.getRootViewController() ?? UIApplication.shared.keyWindow?.rootViewController {
            return vc
        }
        return UIViewController()
    }

    public func bannerViewDidReceiveAd(_ bannerView: POBBannerView) {
        DispatchQueue.main.async {
            self.bannerView?.pauseAutoRefresh()
            guard let auctionBidListener = self.auctionBidListener else { return }
            if let bannerView = self.bannerView {
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = bannerView.bid().price.doubleValue
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.pubmatic.rawValue
                bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                MSPLogger.shared.info(message: "[Adapter: Pubmatic] successfully loaded Pubmatic Banner ad")
                self.handleAdLoaded(
                    ad: bannerAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "pubmatic_placement_id")
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }
    }


    public func bannerView(_ bannerView: POBBannerView, didFailToReceiveAdWithError error: Error) {
        self.bannerView?.pauseAutoRefresh()
        MSPLogger.shared.info(message: "[Adapter: Pubmatic] Fail to load Pubmatic Banner ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error.localizedDescription)
        }
    }

    public func bannerViewDidRecordImpression(_ bannerView: POBBannerView) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self)
                }
            }
        }
    }

    public func bannerViewDidClickAd(_ bannerView: POBBannerView) {
        DispatchQueue.main.async {
            if let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
                self.sendClickAdEvent(ad: bannerAd)
            }
        }
    }
}


extension PubmaticAdapter: POBInterstitialDelegate {
    public func interstitialDidReceiveAd(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else { return }

            if let interstitialAdItem = self.interstitialAdItem {
                let interstitialAd = PubmaticInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = interstitial.bid().price.doubleValue
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.pubmatic.rawValue
                interstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
                MSPLogger.shared.info(message: "[Adapter: Pubmatic] successfully loaded Pubmatic Interstitial ad")
                self.handleAdLoaded(
                    ad: interstitialAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? "pubmatic")
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }
    }

    // Notifies the delegate an error occurred while loading an ad.
    public func interstitial(_ interstitial: POBInterstitial, didFailToReceiveAdWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Pubmatic] Fail to load Pubmatic Banner ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error.localizedDescription)
        }
    }

    public func interstitialDidRecordImpression(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self)
                }
            }
        }
    }

    public func interstitialDidClickAd(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
                self.sendClickAdEvent(ad: interstitialAd)
            }
        }
    }

    public func interstitialDidDismissAd(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdDismissed(ad: interstitialAd)
            }
        }
    }
}

extension PubmaticAdapter: POBNativeAdLoaderDelegate {
    public func nativeAdLoader(_ adLoader: POBNativeAdLoader, didReceive nativeAd: POBNativeAd) {
        DispatchQueue.main.async {
            self.nativeAdItem = nativeAd
            self.nativeAdItem?.setAdDelegate(self)

            if let auctionBidListener = self.auctionBidListener {
                let pubmaticNativeAd = PubmaticNativeAd(
                    adNetworkAdapter: self,
                    title: "",
                    body: "",
                    advertiser: "",
                    callToAction: "")
                pubmaticNativeAd.nativeAdItem = nativeAd
                self.nativeAd = pubmaticNativeAd
                pubmaticNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar ?? 0.0
                pubmaticNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.pubmatic.rawValue
                pubmaticNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId

                if let adListener = self.adListener,
                    let adRequest = self.adRequest,
                    let auctionBidListener = self.auctionBidListener
                {
                    MSPLogger.shared.info(message: "[Adapter: Pubmatic] successfully loaded Pubmatic Native ad")
                    self.handleAdLoaded(
                        ad: pubmaticNativeAd, auctionBidListener: auctionBidListener,
                        bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                }
            }
        }
    }

    public func nativeAdLoader(_ adLoader: POBNativeAdLoader, didFailToReceiveAdWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Pubmatic] Fail to load Pubmatic Native ad")
        self.auctionBidListener?.onError(error: "fail to load ad")
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error.localizedDescription)
        }
    }

    public func viewControllerForPresentingModal() -> UIViewController {
        if let vc = self.adListener?.getRootViewController() ?? UIApplication.shared.keyWindow?.rootViewController {
            return vc
        }
        return UIViewController()
    }
}

extension PubmaticAdapter: POBNativeAdDelegate {
    public func nativeAdDidRecordImpression(_ nativeAd: POBNativeAd) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd,
                let adRequest = self.adRequest
            {
                self.adListener?.onAdImpression(ad: nativeAd)
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self)
            }
        }
    }

    public func nativeAdDidRecordClick(_ nativeAd: POBNativeAd) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
                self.sendClickAdEvent(ad: nativeAd)
            }
        }
    }

    public func nativeAd(_ nativeAd: POBNativeAd, didRecordClickForAsset assetId: Int) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
                self.sendClickAdEvent(ad: nativeAd)
            }
        }
    }
}


extension PubmaticAdapter: POBBidEventDelegate {
    public func bidEvent(_ bidEventObject: (any POBBidEvent)!, didReceive bid: POBBid!) {
        DispatchQueue.main.async {
            self.priceInDollar = bid.price.doubleValue
        }
        bidEventObject.proceedToLoadAd()
    }

    public func bidEvent(_ bidEventObject: (any POBBidEvent)!, didFailToReceiveBidWithError error: (any Error)!) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
}

// MARK: - Rewarded Ad Support Override

extension PubmaticAdapter {
    /// Provide PubMatic rewarded ad support
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
            let publisherId = params?["pubmaticPublisherId"] as? String ?? ""
            var profileId = NSNumber(value: 0)

            if let profileIdString = params?["pubmaticProfileId"] as? String,
                let profileIdInt = Int(profileIdString)
            {
                profileId = NSNumber(value: profileIdInt)
            }

            self.rewardedAdItem = POBRewardedAd(
                publisherId: publisherId,
                profileId: profileId,
                adUnitId: bidderPlacementId)
            self.rewardedAdItem?.delegate = self
            self.rewardedAdItem?.loadAd()
        }
    }
}

// MARK: - POBRewardedAdDelegate

extension PubmaticAdapter: POBRewardedAdDelegate {
    public func rewardedAdDidReceive(_ rewardedAd: POBRewardedAd) {
        MSPLogger.shared.info(message: "[Adapter: PubMatic] Successfully loaded PubMatic rewarded ad")

        DispatchQueue.main.async {
            guard let adListener = self.adListener,
                let auctionBidListener = self.auctionBidListener,
                let bidderPlacementId = self.bidderPlacementId
            else {
                return
            }

            // Create reward from adRequest or use default
            let reward = self.adRequest?.reward ?? Reward(type: "reward", amount: 1)

            let rewardedAd = PubmaticRewardedAd(
                adNetworkAdapter: self,
                reward: reward,
                pobRewardedAd: rewardedAd
            )
            self.rewardedAd = rewardedAd

            // Set ad info
            rewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.pubmatic.rawValue
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

    public func rewardedAdDidFailToReceive(_ rewardedAd: POBRewardedAd, error: Error) {
        MSPLogger.shared.info(
            message: "[Adapter: PubMatic] Fail to load PubMatic rewarded ad: \(error.localizedDescription)")

        self.auctionBidListener?.onError(error: "Failed to load pubmatic rewarded ad: \(error.localizedDescription)")

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
}
