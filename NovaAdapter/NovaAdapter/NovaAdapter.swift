import Foundation
//import shared
import MSPiOSCore
import PrebidMobile
import NovaCore
import UIKit

public class NovaAdapter: AdNetworkAdapter {
    public func getSDKVersion() -> String {
        return "0.0.112"
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    
    public weak var adListener: AdListener?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    public var priceInDollar: Double?
    public var adUnitId: String?
    
    public weak var nativeAd: MSPAd?
    public var nativeAdItem: NovaNativeAdItem?
    
    public weak var interstitialAd: InterstitialAd?
    
    public var nativeAdView: NativeAdView?
    public var novaNativeAdView: NovaNativeAdView?
    
    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        adapterInitListener.onComplete(adNetwork: .nova, adapterInitStatus: .SUCCESS, message: "")
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any, adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
            return
        }
 
        self.adListener = adListener
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        self.adRequest = adRequest
        self.bidResponse = mBidResponse
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let novaExtDict = SafeAs(bidExtDict["nova"], [String: Any].self),
              let adUnitId = SafeAs(novaExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
            return
        }
        DispatchQueue.main.async {
            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        }
        self.adUnitId = adUnitId
        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        let novaAdType: String
        if adRequest.adFormat == .interstitial {
            novaAdType = "app_open"
        } else {
            novaAdType = "native"
        }
        parseNovaAdString(adString: testAdString, adType: novaAdType, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        let adOpenActionHandler = NovaAdOpenActionHandler(viewController: adListener?.getRootViewController())
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
        DispatchQueue.main.async {
            guard let nativeAdView = nativeAdView as? NativeAdView,
                  let mediaView = nativeAd.mediaView as? NovaNativeAdMediaView,
                  let novaNativeAdItem = self.nativeAdItem else {
                self.adListener?.onError(msg: "fail to render native view")
                return
            }
            let novaNativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster,
                                                    mediaView: mediaView)
            
            if let nativeAdViewBinder = nativeAdView.nativeAdViewBinder {
                novaNativeAdView.titleLabel = nativeAdView.nativeAdViewBinder?.titleLabel
                novaNativeAdView.bodyLabel = nativeAdView.nativeAdViewBinder?.bodyLabel
                novaNativeAdView.advertiserLabel = nativeAdView.nativeAdViewBinder?.advertiserLabel
                novaNativeAdView.callToActionButton = nativeAdView.nativeAdViewBinder?.callToActionButton
                novaNativeAdView.prepareViewForInteraction(nativeAd: novaNativeAdItem)
                
                let novaSubViews: [UIView?] = [novaNativeAdView.titleLabel, novaNativeAdView.bodyLabel, novaNativeAdView.advertiserLabel, novaNativeAdView.callToActionButton, mediaView]
                novaNativeAdView.tappableViews = [UIView]()
                for view in novaSubViews {
                    if let view = view {
                        novaNativeAdView.addSubview(view)
                        novaNativeAdView.tappableViews?.append(view)
                    }
                }
                novaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                nativeAdView.nativeAdViewBinder?.setUpViews(parentView: novaNativeAdView)
            } else if let nativeAdContainer = nativeAdView.nativeAdContainer {
                novaNativeAdView.titleLabel = nativeAdContainer.getTitle()
                novaNativeAdView.bodyLabel = nativeAdContainer.getbody()
                novaNativeAdView.advertiserLabel = nativeAdContainer.getAdvertiser()
                novaNativeAdView.callToActionButton = nativeAdContainer.getCallToAction()
                novaNativeAdView.icon = nativeAdContainer.getIcon()
                novaNativeAdView.prepareViewForInteraction(nativeAd: novaNativeAdItem)
                
                if let mediaContainer = nativeAdContainer.getMedia() {
                    mediaContainer.addSubview(mediaView)
                    NSLayoutConstraint.activate([
                        //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                        mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                        mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                        mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                        mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                    ])
                }
                
                if let iconView = nativeAdContainer.getIcon(),
                   let imageUrlStr = novaNativeAdItem.iconUrlStr,
                   let url = URL(string: imageUrlStr) {
                    NovaUIUtils.setImage(from: url, to: iconView) {
                        
                    }
                }
                
                nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
                
                novaNativeAdView.addSubview(nativeAdContainer)
                novaNativeAdView.tappableViews = [UIView]()
                let novaSubViews = [novaNativeAdView.titleLabel, novaNativeAdView.bodyLabel, novaNativeAdView.advertiserLabel, novaNativeAdView.callToActionButton, novaNativeAdView.icon, mediaView]
                for view in novaSubViews {
                    if let view = view {
                        novaNativeAdView.tappableViews?.append(view)
                    }
                }
                novaNativeAdView.tappableViews?.append(nativeAdContainer)
                if let button = novaNativeAdView.callToActionButton {
                    novaNativeAdView.tappableViews?.append(button)
                }
                novaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    nativeAdContainer.leadingAnchor.constraint(equalTo: novaNativeAdView.leadingAnchor),
                    nativeAdContainer.trailingAnchor.constraint(equalTo: novaNativeAdView.trailingAnchor),
                    nativeAdContainer.topAnchor.constraint(equalTo: novaNativeAdView.topAnchor),
                    nativeAdContainer.bottomAnchor.constraint(equalTo: novaNativeAdView.bottomAnchor),
                    nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: novaNativeAdView.widthAnchor),
                    nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: novaNativeAdView.heightAnchor),
                ])
            }
            
            nativeAdView.addSubview(novaNativeAdView)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                novaNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                novaNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                novaNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                novaNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                novaNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                novaNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
            ])
        }
    }
    
    func parseNovaAdString(adString: String, adType: String, adUnitId: String, eCPMInDollar: Decimal) {
        let data = adString.data(using: .utf8)
        guard let data = data else { return }

        do {
            let decodedData = try JSONDecoder().decode(NovaResponseDataModel.self, from: data)

            guard let ads = decodedData.ads, 
                    !ads.isEmpty,
                    let adItem = ads.first else {
                self.adListener?.onError(msg: "no valid response")
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                return
            }
            
            switch adType {
            case "banner":
                return
                

            case "native":
                MSPLogger.shared.info(message: "[Adapter: Nova] successfully loaded Nova Native ad")
                let nativeAdItem = NovaAdBuilder.buildNativeAd(adItem: adItem, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
                let nativeAd = NovaNativeAd(adNetworkAdapter: self,
                                            title: nativeAdItem.headline ?? "",
                                            body: nativeAdItem.body ?? "",
                                            advertiser: nativeAdItem.advertiser ?? "",
                                            callToAction:nativeAdItem.callToAction ?? "")
                DispatchQueue.main.async{
                    let mediaView = {
                        let view = NovaNativeAdMediaView()
                        view.accessibilityIdentifier = "media"
                        view.translatesAutoresizingMaskIntoConstraints = false
                        return view
                    }()
                    nativeAd.mediaView = mediaView
                    nativeAd.icon = nativeAdItem.iconUrlStr
                    nativeAd.priceInDollar = self.priceInDollar
                    nativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                    nativeAd.adInfo["isVideo"] = (nativeAdItem.creativeType == .nativeVideo)
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.nova.rawValue
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
                    nativeAd.nativeAdItem = nativeAdItem
                    self.nativeAdItem = nativeAdItem
                    self.nativeAd = nativeAd
                    nativeAdItem.delegate = self
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        self.handleAdLoaded(ad: nativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nativeAd, fill: true, isFromCache: false)
                    }
                }
                
            case "app_open":
                MSPLogger.shared.info(message: "[Adapter: Nova] successfully loaded Nova Interstitial ad")
                let appOpenAds = NovaAdBuilder.buildAppOpenAds(adItems: ads, adUnitId: adUnitId)
                let appOpenAd = appOpenAds.first
                
                var novaInterstitialAd = NovaInterstitialAd(adNetworkAdapter: self)
                novaInterstitialAd.interstitialAdItem = appOpenAd
                //ad.fullScreenContentDelegate = self
                DispatchQueue.main.async {
                    novaInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                
                    self.interstitialAd = novaInterstitialAd
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.nova.rawValue
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
                    appOpenAd?.delegate = self
                
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        if appOpenAd?.creativeType == .nativeImage {
                            appOpenAd?.preloadAdImage() { image in
                                DispatchQueue.main.async {
                                    if let image = image {
                                       
                                        self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: novaInterstitialAd, fill: true, isFromCache: false)
                                    } else {
                                        self.adListener?.onError(msg: "fail to load ad media")
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                            }
                        }
                    }
                }
                
            default:
                MSPLogger.shared.info(message: "[Adapter: Nova] Fail to load Nova ad")
                let errorMessage = "unknown adType"
                self.adListener?.onError(msg: errorMessage)
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: errorMessage)
                }
            }
        } catch {
            MSPLogger.shared.info(message: "[Adapter: Nova] Fail to load Nova ad")
            let errorMessage = "error decode nova ad string"
            self.adListener?.onError(msg: errorMessage)
            self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: errorMessage)
            }
        }
        
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
    
    public func loadTestAdCreative(adString: String, adListener: any AdListener, context: Any, adRequest: AdRequest) {
 
        self.adListener = adListener
        self.adRequest = adRequest

        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        let adType = adRequest.adFormat == .interstitial ? "app_open" : "native"
        parseNovaAdString(adString: adString, adType: adType, adUnitId: "dummy_id", eCPMInDollar: eCPMInDollar)
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "msp", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .nova
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?)
    {
        if let adRequest = self.adRequest,
           let ad = self.nativeAd ?? self.interstitialAd {
            self.adMetricReporter?.logAdHide(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = self.nativeAd ?? self.interstitialAd {
            self.adMetricReporter?.logAdReport(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
}

extension NovaAdapter: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                var params = [String:Any?]()
                if let adUnitId = self.adUnitId {
                    params["adUnitId"] = adUnitId
                }
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: bidResponse, params: params)
            }
        }
    }
    
    public func nativeAdDidLogClick(_ nativeAd: NovaCore.NovaNativeAdItem, clickAreaName: String) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
        }
    }
    
    public func nativeAdDidFinishRender(_ nativeAd: NovaCore.NovaNativeAdItem) {
        
    }
    
    public func nativeAdRootViewController() -> UIViewController? {
        if Thread.isMainThread {
                return self.adListener?.getRootViewController()
        } else {
            return DispatchQueue.main.sync {
                self.adListener?.getRootViewController()
            }
        }
        //return self.adListener?.getRootViewController()
    }
}

extension NovaAdapter: NovaAppOpenAdDelegate {
    public func appOpenAdDidDismiss(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
    
    public func appOpenAdDidDisplay(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdImpression(ad: interstitialAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                var params = [String:Any?]()
                if let adUnitId = self.adUnitId {
                    params["adUnitId"] = adUnitId
                }
                self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse, params: params)
            }
        }
    }
    
    public func appOpenAdDidLogClick(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
        }
    }
}

public let testAdString = "{\"abConfig\":{},\"ad\":[{\"adId\":\"1342933800177221634\",\"adsetId\":\"1567933796853821442\",\"creative\":{\"address\":\"\",\"adm\":\"\",\"advertiser\":\"Vita Mahjong\",\"body\":\"Neurologists recommended game!\",\"callToAction\":\"Learn More\",\"carouselItems\":[],\"channelId\":\"\",\"creativeType\":\"VIDEO\",\"ctrUrl\":\"https://app.appsflyer.com/id6468921495?pid=particlemedia_int\\u0026af_siteid=NewsBreak\\u0026c=__CAMPAIGN_NAME__\\u0026af_c_id=__CAMPAIGN_ID__\\u0026af_ad=__CREATIVE_NAME__\\u0026af_ad_id=__CREATIVE_ID__\\u0026af_adset=__FLIGHT_NAME__\\u0026af_adset_id=__FLIGHT_ID__\\u0026af_click_lookback=7d\\u0026clickid=__CALLBACK_PARAM__\\u0026advertising_id=__ADID__\\u0026idfa=__IDFA__\",\"headline\":\"Vita Mahjong\",\"iconUrl\":\"https://static.particlenews.com/nova/assets/1823179166005485569/32a667a61bcae4cf393eb192b721dcea7685486e.jpg\",\"image\":\"\",\"imageUrl\":\"https://static.particlenews.com/nova/assets/1823179166005485569/cf6d0e3c01a082ffeeefcf9c7053de5d8b979c55.mp4\",\"imageUrls\":[],\"isImageClickable\":false,\"isVerticalImage\":true,\"launchOption\":\"LAUNCH_WEBVIEW\",\"thirdPartyClickTrackingUrls\":[],\"thirdPartyImpressionTrackingUrls\":[],\"thirdPartyViewTrackingUrls\":[],\"videoItem\":{\"coverUrl\":\"\",\"isLoop\":true,\"isMute\":true,\"isPlayAutomatically\":true,\"isPlayOnLandingPage\":false,\"isVertical\":true,\"isVideoClickable\":false,\"videoUrl\":\"https://static.particlenews.com/nova/assets/1823179166005485569/cf6d0e3c01a082ffeeefcf9c7053de5d8b979c55.mp4\"}},\"encryptedAdToken\":\"d650a77f-1625-411c-bd06-67085b44c55f.CjII+Luw5pQyFUEuqMAaJGQ2NTBhNzdmLTE2MjUtNDExYy1iZDA2LTY3MDg1YjQ0YzU1ZhCB4M2KzvDAwBgYgqCczJazv80YIILg9vWukO7qGCiB4Pb5i5Hu6hgwguD2gYyR7uoYOgVDTElDS0D4VUgBUg9JTU1FUlNJVkVfVklERU9aKm5vdmEtYW5kcm9pZC1pbW1lcnNpdmUtZmxvdy1uYXRpdmUtcHJvZC1vYmrOA2h0dHBzOi8vY2xhaW0uYWNhaGVhbHRocHJvLmNvbS9jbGljay5waHA/a2V5PTBvOW13N2t2dXdzaXByZGdpcjVlJm5iY2lkPW52c3NfZDY1MGE3N2YxNjI1NDExY2JkMDY2NzA4NWI0NGM1NWZfMTc4OTUzOTMyNDQyOTk3MTQ1OCZjYW1wYWlnbl9pZD0xNzczMDA4MjM4NjY1OTk0MjQyJmNhbXBhaWduX25hbWU9MjI0MjIrRlMrVVMxJmFkc2V0X2lkPTE3ODk1MzkyOTk0NDAzMDgyMjYmYWRzZXRfbmFtZT1BZHNldCs0MStWaWRlbytUQ1BBK1JJQ0UrVFMmYWRfaWQ9MTc4OTUzOTMyNDQyOTk3MTQ1OCZhZF9uYW1lPVZpZDQ0UislMjhjb3B5JTI5Jm9zPWFuZHJvaWQmaXNfbm92YT10cnVlJnV0bV9jb250ZW50PW52c3NfZDY1MGE3N2YxNjI1NDExY2JkMDY2NzA4NWI0NGM1NWZfMTc4OTUzOTMyNDQyOTk3MTQ1OCZuYl9jaWQ9ZDY1MGE3N2YxNjI1NDExY2JkMDY2NzA4NWI0NGM1NWZfMTc4OTUzOTMyNDQyOTk3MTQ1OHHlHsEPe533P5EBAAAA4HAkrD+ZAQAAAEBCN2U/oAGg9Q2oAeDDu9v2MbAB+6+f7ZQyugEECAEQAcIBBURBSUxZ0gEKQ09OVkVSU0lPTtkBgFWQ1yJWOUDiAQlQT1NUX1BBSUToAYHgzYrO8MDAGPAB////////////AYkCAAAAoLw9rT+RAgAAAMB0zGE/mQLlHsEPe533Pw==\",\"expirationMs\":\"2039016266000\",\"price\":1000.2685368708022,\"requestId\":\"0202343H-8E5A-46B6-912F-90ECC8732417\",\"secondPrice\":1005.3752379452937,\"startTimeMs\":\"1755494380000\"}],\"code\":0,\"status\":\"success\",\"supported_web_format\":[\"native\",\"banner\"]}"

