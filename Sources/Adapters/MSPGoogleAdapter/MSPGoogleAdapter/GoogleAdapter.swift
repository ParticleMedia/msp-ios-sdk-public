//import shared
import Foundation
import GoogleMobileAds
import MSPGoogleAdsTypes
import MSPiOSCore
import PrebidMobile

@objc public class GoogleAdapter: NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        MSPGADMobileAdsSDKVersion()
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? MSPiOSCore.NativeAdView,
            let gadNativeAdItem = self.nativeAdItem
        else { return }
        let gadNativeAdView = MSPGADNativeAdView()
        gadNativeAdView.translatesAutoresizingMaskIntoConstraints = false
        gadNativeAdView.nativeAd = gadNativeAdItem

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false

            gadNativeAdView.headlineView = nativeAdContainer.getTitle()
            gadNativeAdView.bodyView = nativeAdContainer.getbody()
            gadNativeAdView.advertiserView = nativeAdContainer.getAdvertiser()
            gadNativeAdView.callToActionView = nativeAdContainer.getCallToAction()
            if let iconView = nativeAdContainer.getIcon(),
                let image = gadNativeAdItem.icon?.image
            {
                gadNativeAdView.iconView = iconView
                iconView.image = image
            }

            if let mediaContainer = nativeAdContainer.getMedia(),
                let mediaView = nativeAd.mediaView as? MSPGADMediaView
            {
                gadNativeAdView.mediaView = mediaView
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
                ])
            }

            gadNativeAdView.addSubview(nativeAdContainer)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: gadNativeAdView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: gadNativeAdView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: gadNativeAdView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: gadNativeAdView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: gadNativeAdView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: gadNativeAdView.heightAnchor),
            ])
        }

        nativeAdView.addSubview(gadNativeAdView)
        NSLayoutConstraint.activate([
            //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            gadNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            gadNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            gadNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            gadNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            gadNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
            gadNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
        ])
    }

    public func destroyAd() {
    }

    @objc public static func initializeGAD() {
        MSPGADMobileAdsStart(completionHandler: nil)
    }

    public func initialize(
        initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?
    ) {
        MSPGADMobileAdsStart(completionHandler: { _ in
            adapterInitListener.onComplete(adNetwork: .google, adapterInitStatus: .SUCCESS, message: "")
        })
    }

    public var gadBannerView: MSPGAMBannerView?
    private var adLoader: MSPGADAdLoader?
    public var nativeAdItem: MSPGADNativeAd?
    public weak var adListener: AdListener?
    public var priceInDollar: Double?

    var adRequest: AdRequest?
    var bidResponse: BidResponse?

    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    private weak var bannerAd: BannerAd?
    private weak var nativeAd: MSPiOSCore.NativeAd?
    private weak var interstitialAd: MSPiOSCore.InterstitialAd?
    private weak var rewardedAd: GoogleRewardedAd?
    public var adUnitId: String?

    var adMetricReporter: AdMetricReporter?

    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any,
        adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String: String]?
    ) {
        DispatchQueue.main.async {
            self.adRequest = adRequest
            self.auctionBidListener = auctionBidListener
            self.bidderPlacementId = bidderPlacementId
            self.adListener = adListener

            if bidResponse is BidResponse,
                let mBidResponse = bidResponse as? BidResponse
            {
                // server-to-server load ad
                self.bidResponse = mBidResponse

                guard let adString = mBidResponse.winningBid?.bid.adm,
                    let rawBidDict = self.SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
                    let bidExtDict = self.SafeAs(rawBidDict["ext"], [String: Any].self),
                    let googleExtDict = self.SafeAs(bidExtDict["google"], [String: Any].self),
                    let adUnitId = self.SafeAs(googleExtDict["ad_unit_id"], String.self),
                    let prebidExtDict = self.SafeAs(bidExtDict["prebid"], [String: Any].self),
                    let adType = self.SafeAs(prebidExtDict["type"], String.self)
                else {
                    self.handleAuctionBidError(error: "no valid response")
                    self.adMetricReporter?.logAdResult(
                        placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                    return
                }

                self.adUnitId = adUnitId
                let priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                self.priceInDollar = priceInDollar

                switch adType {
                case "banner":
                    if adRequest.adFormat == .rewarded {
                        self.loadGoogleAd(
                            adFormat: .rewarded, adUnitId: adUnitId, priceInDollar: priceInDollar,
                            adRequest: adRequest, adString: adString)
                    } else if adRequest.adFormat == .interstitial {
                        self.loadGoogleAd(
                            adFormat: .interstitial, adUnitId: adUnitId, priceInDollar: priceInDollar,
                            adRequest: adRequest, adString: adString)
                    } else {
                        self.loadGoogleAd(
                            adFormat: .banner, adUnitId: adUnitId, priceInDollar: priceInDollar, adRequest: adRequest,
                            adString: adString)
                    }

                case "native":
                    self.loadGoogleAd(
                        adFormat: .native, adUnitId: adUnitId, priceInDollar: priceInDollar, adRequest: adRequest,
                        adString: adString)

                case "video":
                    if adRequest.adFormat == .rewarded {
                        self.loadGoogleAd(
                            adFormat: .rewarded, adUnitId: adUnitId, priceInDollar: priceInDollar,
                            adRequest: adRequest, adString: adString)
                    } else if adRequest.adFormat == .interstitial {
                        self.loadGoogleAd(
                            adFormat: .interstitial, adUnitId: adUnitId, priceInDollar: priceInDollar,
                            adRequest: adRequest, adString: adString)
                    } else {
                        self.handleAuctionBidError(
                            error: "adType=video but adFormat=\(adRequest.adFormat) is unsupported",
                            bidResponse: mBidResponse)
                    }

                default:
                    self.handleAuctionBidError(error: "unknown adType: \(adType ?? "nil")", bidResponse: mBidResponse)
                }
            } else {
                // client-to-server load ad
                let priceInDollar: Double
                if let priceStr = params?["price"] {
                    priceInDollar = Double(priceStr) ?? 0.0
                } else {
                    priceInDollar = 0.0
                }
                self.priceInDollar = priceInDollar
                self.adUnitId = bidderPlacementId

                let adFormat = bidderFormat ?? adRequest.adFormat
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Google] Resolve client-to-server ad format. placementId=\(adRequest.placementId), bidderPlacementId=\(bidderPlacementId), requestFormat=\(String(describing: adRequest.adFormat)), bidderFormat=\(bidderFormat.map { String(describing: $0) } ?? "nil"), resolvedFormat=\(String(describing: adFormat)), price=\(priceInDollar)"
                )

                self.loadGoogleAd(
                    adFormat: adFormat, adUnitId: bidderPlacementId, priceInDollar: priceInDollar, adRequest: adRequest,
                    adString: nil)
            }
        }
    }

    private func loadGoogleAd(
        adFormat: MSPiOSCore.AdFormat, adUnitId: String, priceInDollar: Double, adRequest: MSPiOSCore.AdRequest,
        adString: String?
    ) {
        MSPLogger.shared.info(
            message:
                "[Adapter: Google] Enter loadGoogleAd. placementId=\(adRequest.placementId), bidderPlacementId=\(self.bidderPlacementId ?? adRequest.placementId), adUnitId=\(adUnitId), resolvedFormat=\(String(describing: adFormat)), requestHasAdString=\(adString != nil)"
        )
        switch adFormat {
        case .banner:
            MSPLogger.shared.info(
                message:
                    "[Adapter: Google] Routing request to Banner load. placementId=\(adRequest.placementId), bidderPlacementId=\(self.bidderPlacementId ?? adRequest.placementId), adUnitId=\(adUnitId)"
            )

            self.priceInDollar = priceInDollar
            let gadBannerView = MSPGAMBannerView(adSize: self.getGADAdSize(adRequest: adRequest))
            self.gadBannerView = gadBannerView
            gadBannerView.isAutoloadEnabled = false
            let request = MSPGADRequest()
            MSPGADRequestSetAdString(request, adString: adString)
            gadBannerView.adUnitID = adUnitId
            gadBannerView.delegate = self
            gadBannerView.rootViewController = self.adListener?.getRootViewController()
            gadBannerView.load(request)

        case .native, .multi_format:
            MSPLogger.shared.info(
                message:
                    "[Adapter: Google] Routing request to Native/Multi-Format load. placementId=\(adRequest.placementId), bidderPlacementId=\(self.bidderPlacementId ?? adRequest.placementId), adUnitId=\(adUnitId), resolvedFormat=\(String(describing: adFormat))"
            )

            self.priceInDollar = priceInDollar

            let adTypes: [MSPGADAdLoaderAdType]
            if adFormat == .native {
                adTypes = [.native]
            } else {
                adTypes = MSPGADAdLoaderAdTypesForMultiFormat()
            }
            let videoOptions = MSPGADVideoOptions()
            MSPGADVideoOptionsSetStartMuted(videoOptions, muted: true)
            let adLoader = MSPGADAdLoader(
                adUnitID: adUnitId,
                rootViewController: self.adListener?.getRootViewController(),
                adTypes: adTypes,
                options: [videoOptions])
            adLoader.delegate = self
            self.adLoader = adLoader
            let gamRequest = MSPGADRequest()
            MSPGADRequestSetAdString(gamRequest, adString: adString)
            adLoader.load(gamRequest)


        case .interstitial:
            MSPLogger.shared.info(
                message:
                    "[Adapter: Google] Routing request to Interstitial load. placementId=\(adRequest.placementId), bidderPlacementId=\(self.bidderPlacementId ?? adRequest.placementId), adUnitId=\(adUnitId)"
            )
            let request = MSPGADRequest()
            MSPGADRequestSetAdString(request, adString: adString)
            MSPGADInterstitialAdLoad(adUnitID: adUnitId, request: request) { [weak self] ad, error in
                guard let self else { return }

                if let error {
                    MSPLogger.shared.info(message: "[Adapter: Google] Fail to load Google Interstitial ad")
                    self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
                    self.adMetricReporter?.logAdResult(
                        placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                    self.adMetricReporter?.logAdResponse(
                        ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                        errorMessage: error.localizedDescription)
                    return
                }

                guard let ad else {
                    MSPLogger.shared.info(message: "[Adapter: Google] Fail to load Google Interstitial ad")
                    self.handleAuctionBidError(error: "missing ad", bidResponse: self.bidResponse)
                    self.adMetricReporter?.logAdResult(
                        placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                    return
                }

                MSPLogger.shared.info(message: "[Adapter: Google] successfully loaded Google Interstitial ad")

                DispatchQueue.main.async {
                    self.priceInDollar = priceInDollar
                    var googleInterstitialAd = GoogleInterstitialAd(adNetworkAdapter: self)
                    googleInterstitialAd.interstitialAdItem = ad
                    ad.fullScreenContentDelegate = self
                    googleInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                    self.interstitialAd = googleInterstitialAd
                    googleInterstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                    googleInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
                    googleInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
                    googleInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] =
                        self.bidResponse?.winningBid?.bid.crid
                    if let requestId = self.bidResponse?.rawResponse?.requestID {
                        googleInterstitialAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
                    }
                    if let adListener = self.adListener,
                        let adRequest = self.adRequest,
                        let auctionBidListener = self.auctionBidListener
                    {
                        //handleAdLoaded(ad: googleInterstitialAd, listener: adListener, adRequest: adRequest)
                        self.handleAdLoaded(
                            ad: googleInterstitialAd, auctionBidListener: auctionBidListener,
                            bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                        self.adMetricReporter?.logAdResult(
                            placementId: adRequest.placementId, ad: googleInterstitialAd, fill: true, isFromCache: false
                        )
                    }
                }
            }
        case .rewarded:
            MSPLogger.shared.info(
                message:
                    "[Adapter: Google] Start loading Google Rewarded ad. placementId=\(adRequest.placementId), bidderPlacementId=\(self.bidderPlacementId ?? adRequest.placementId), adUnitId=\(adUnitId), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), reward=\(adRequest.reward?.type ?? "nil"):\(adRequest.reward?.amount.description ?? "nil")"
            )
            let request = MSPGADRequest()
            MSPGADRequestSetAdString(request, adString: adString)
            MSPGADRewardedAdLoad(adUnitID: adUnitId, request: request) { [weak self] ad, error in
                guard let self else { return }

                if let error {
                    MSPLogger.shared.error(
                        message:
                            "[Adapter: Google] Fail to load Google Rewarded ad. placementId=\(adRequest.placementId), adUnitId=\(adUnitId), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), error=\(error.localizedDescription)"
                    )
                    self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
                    self.adMetricReporter?.logAdResult(
                        placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
                    self.adMetricReporter?.logAdResponse(
                        ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                        errorMessage: error.localizedDescription)
                    return
                }

                guard let ad else {
                    MSPLogger.shared.error(
                        message:
                            "[Adapter: Google] Rewarded load returned nil ad without error. placementId=\(adRequest.placementId), adUnitId=\(adUnitId), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
                    )
                    self.handleAuctionBidError(error: "missing rewarded ad", bidResponse: self.bidResponse)
                    self.adMetricReporter?.logAdResult(
                        placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
                    return
                }

                // SSV options are set on the ad object after load (not on the request).
                if let options = Self.serverSideVerificationOptions(for: adRequest.reward) {
                    MSPLogger.shared.info(
                        message:
                            "[Adapter: Google] Applying rewarded SSV options. placementId=\(adRequest.placementId), reward=\(adRequest.reward?.type ?? "nil"):\(adRequest.reward?.amount.description ?? "nil")"
                    )
                    MSPGADRewardedAdSetServerSideVerificationOptions(ad, options: options)
                } else {
                    MSPLogger.shared.info(
                        message:
                            "[Adapter: Google] Rewarded load has no SSV options. placementId=\(adRequest.placementId)")
                }
                self.handleLoadedRewardedAd(ad, priceInDollar: priceInDollar, adRequest: adRequest)
            }
        @unknown default:
            self.handleAuctionBidError(error: "unknown ad format", bidResponse: self.bidResponse)
        }
    }

    static func customRewardString(for reward: Reward) -> String {
        "\(reward.type):\(reward.amount)"
    }

    static func serverSideVerificationOptions(for reward: Reward?) -> MSPGADServerSideVerificationOptions? {
        guard let reward else { return nil }
        let options = MSPGADServerSideVerificationOptions()
        MSPGADServerSideVerificationOptionsSetCustomRewardString(
            options,
            customRewardString: customRewardString(for: reward)
        )
        return options
    }

    private func handleLoadedRewardedAd(
        _ ad: MSPGADRewardedAd,
        priceInDollar: Double,
        adRequest: MSPiOSCore.AdRequest
    ) {
        MSPLogger.shared.info(
            message:
                "[Adapter: Google] successfully loaded Google Rewarded ad. placementId=\(adRequest.placementId), adUnitId=\(self.adUnitId), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), reward=\(adRequest.reward?.type ?? "nil"):\(adRequest.reward?.amount.description ?? "nil")"
        )

        DispatchQueue.main.async {
            self.priceInDollar = priceInDollar
            let reward = self.resolveReward(for: ad, adRequest: adRequest)
            let googleRewardedAd = GoogleRewardedAd(
                adNetworkAdapter: self,
                reward: reward,
                rewardedAdItem: ad,
                rootViewController: self.adListener?.getRootViewController(),
                adListener: self.adListener
            )
            ad.fullScreenContentDelegate = self
            self.rewardedAd = googleRewardedAd
            googleRewardedAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
            googleRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
            googleRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
            googleRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                googleRewardedAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }

            if let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                self.handleAdLoaded(
                    ad: googleRewardedAd,
                    auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId
                )
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: googleRewardedAd, fill: true, isFromCache: false)
            }
        }
    }

    private func resolveReward(for ad: MSPGADRewardedAd, adRequest: AdRequest) -> Reward {
        if let requestReward = adRequest.reward {
            return requestReward
        }

        if let networkReward = MSPGADRewardedAdReward(ad) {
            return Reward(type: networkReward.type, amount: MSPGADAdRewardAmount(networkReward))
        }

        return Reward(type: "", amount: 0)
    }

    public func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }


    private func getGADAdSize(adRequest: AdRequest) -> MSPGADAdSize {
        if let adaptiveBannerAdSize = adRequest.adaptiveBannerSize {
            if adaptiveBannerAdSize.isAnchorAdaptiveBanner {
                return MSPGADCurrentOrientationAnchoredAdaptiveBanner(width: CGFloat(adaptiveBannerAdSize.width))
            } else if adaptiveBannerAdSize.isInlineAdaptiveBanner {
                return MSPGADInlineAdaptiveBanner(
                    width: CGFloat(adaptiveBannerAdSize.width), maxHeight: CGFloat(adaptiveBannerAdSize.height))
            }
        }
        if let width = adRequest.adSize?.width,
            let height = adRequest.adSize?.height
        {
            if width == 300, height == 250 {
                return MSPGADAdSizeMediumRectangle
            }
        }
        return MSPGADAdSizeBanner
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .google
    }

    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = ((self.bannerAd ?? self.nativeAd) ?? self.interstitialAd) ?? self.rewardedAd
            {
                self.adMetricReporter?.logAdHide(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot,
                    fullScreenShot: fullScreenShot)
            }
        }
    }

    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = ((self.bannerAd ?? self.nativeAd) ?? self.interstitialAd) ?? self.rewardedAd
            {
                self.adMetricReporter?.logAdReport(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description,
                    adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
            }
        }
    }

    public func sendClickAdEvent(ad: MSPAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: self.bidResponse)
            }
        }
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
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
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
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

extension GoogleAdapter: MSPGADBannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: MSPGADBannerView) {
        MSPLogger.shared.info(message: "[Adapter: Google] successfully loaded Google Banner ad")
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }

            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                bannerAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }
            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: bannerAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }

    public func bannerView(_ bannerView: MSPGADBannerView, didFailToReceiveAdWithError error: Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Google] Fail to load Google Banner ad")
            self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error.localizedDescription)
            }
        }
    }

    public func bannerViewDidRecordClick(_ bannerView: MSPGADBannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdClick(ad: googleAd)
            self.sendClickAdEvent(ad: googleAd)
        }
    }

    public func bannerViewDidRecordImpression(_ bannerView: MSPGADBannerView) {
        DispatchQueue.main.async {
            if let googleAd = self.bannerAd {
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdImpression(
                        ad: googleAd, adRequest: adRequest, bidResponse: self.bidResponse)
                }
                self.adListener?.onAdImpression(ad: googleAd)
            }
        }
    }
}

extension GoogleAdapter: MSPGADNativeAdLoaderDelegate {
    public func adLoader(_ adLoader: MSPGADAdLoader, didReceive nativeAd: MSPGADNativeAd) {
        MSPLogger.shared.info(message: "[Adapter: Google] successfully loaded Google Native ad")
        DispatchQueue.main.async {
            let mediaView = MSPGADMediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            mediaView.contentMode = .scaleAspectFill
            mediaView.mediaContent = nativeAd.mediaContent

            let googleNativeAd = GoogleNativeAd(
                adNetworkAdapter: self,
                title: nativeAd.headline ?? "",
                body: nativeAd.body ?? "",
                advertiser: nativeAd.advertiser ?? "",
                callToAction: nativeAd.callToAction ?? "")

            googleNativeAd.nativeAdItem = nativeAd
            googleNativeAd.mediaView = mediaView
            googleNativeAd.icon = nativeAd.icon?.image
            googleNativeAd.priceInDollar = self.priceInDollar
            googleNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
            googleNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
            googleNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
            googleNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                googleNativeAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }
            nativeAd.delegate = self
            self.nativeAdItem = nativeAd
            self.nativeAd = googleNativeAd
            googleNativeAd.priceInDollar = self.priceInDollar
            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: googleNativeAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: googleNativeAd, fill: true, isFromCache: false)
            }
        }
    }

    public func adLoader(_ adLoader: MSPGADAdLoader, didFailToReceiveAdWithError error: any Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Google] Fail to load Google Native ad")
            self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error.localizedDescription)
            }
        }
    }
}

extension GoogleAdapter: MSPGADNativeAdDelegate {
    public func nativeAdDidRecordImpression(_ nativeAd: MSPGADNativeAd) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdImpression(
                        ad: nativeAd, adRequest: adRequest, bidResponse: self.bidResponse)
                }
                self.adListener?.onAdImpression(ad: nativeAd)
            }
        }
    }

    public func nativeAdDidRecordClick(_ nativeAd: MSPGADNativeAd) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
            self.sendClickAdEvent(ad: nativeAd)
        }
    }
}

extension GoogleAdapter: MSPGADFullScreenContentDelegate {
    public func adDidRecordImpression(_ ad: MSPGADFullScreenPresentingAd) {
        DispatchQueue.main.async {
            if let rewardedAd = self.rewardedAd {
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Google] Rewarded impression callback. placementId=\(self.adRequest?.placementId ?? "nil"), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
                )
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdImpression(
                        ad: rewardedAd, adRequest: adRequest, bidResponse: self.bidResponse)
                }
                self.adListener?.onAdImpression(ad: rewardedAd)
                rewardedAd.markDisplayed()
            } else if let interstitialAd = self.interstitialAd {
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdImpression(
                        ad: interstitialAd, adRequest: adRequest, bidResponse: self.bidResponse)
                }
                self.adListener?.onAdImpression(ad: interstitialAd)
            }
        }
    }

    public func adDidRecordClick(_ ad: MSPGADFullScreenPresentingAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let rewardedAd = self.rewardedAd {
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Google] Rewarded click callback. placementId=\(self.adRequest?.placementId ?? "nil"), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
                )
                rewardedAd.markClicked()
                self.adListener?.onAdClick(ad: rewardedAd)
                self.sendClickAdEvent(ad: rewardedAd)
            } else if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
                self.sendClickAdEvent(ad: interstitialAd)
            }
        }
    }

    public func adDidDismissFullScreenContent(_ ad: any MSPGADFullScreenPresentingAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let rewardedAd = self.rewardedAd {
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Google] Rewarded dismiss callback. placementId=\(self.adRequest?.placementId ?? "nil"), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
                )
                rewardedAd.markDismissed()
            } else if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdDismissed(ad: interstitialAd)
            }
        }
    }

    public func ad(_ ad: any MSPGADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if let rewardedAd = self.rewardedAd {
            MSPLogger.shared.error(
                message:
                    "[Adapter: Google] Rewarded failed to present. placementId=\(self.adRequest?.placementId ?? "nil"), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), error=\(error.localizedDescription)"
            )
            rewardedAd.handlePresentError(error)
        } else {
            MSPLogger.shared.error(
                message: "[Adapter: Google] Interstitial failed to present. error=\(error.localizedDescription)")
        }
    }
}

extension GoogleAdapter: MSPGAMBannerAdLoaderDelegate {
    public func validBannerSizes(for adLoader: MSPGADAdLoader) -> [NSValue] {
        if let adRequest = adRequest {
            let adSize = self.getGADAdSize(adRequest: adRequest)
            return [MSPNSValueFromGADAdSize(adSize)]
        }
        return [MSPNSValueFromGADAdSize(MSPGADAdSizeMediumRectangle)]  //default size: 300 * 250
    }

    public func adLoader(_ adLoader: MSPGADAdLoader, didReceive bannerView: MSPGAMBannerView) {
        MSPLogger.shared.info(message: "[Adapter: Google] successfully loaded Google Banner ad")
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                bannerAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }

            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: bannerAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }
}
