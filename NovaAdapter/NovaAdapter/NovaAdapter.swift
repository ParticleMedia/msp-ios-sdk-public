import Foundation
//import shared
import MSPiOSCore
import PrebidMobile
import NovaCore
import UIKit

public class NovaAdapter: AdNetworkAdapter {
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    
    public weak var adListener: AdListener?
    public var priceInDollar: Double?
    public var adUnitId: String?
    
    public var nativeAd: MSPAd?
    public var nativeAdItem: NovaNativeAdItem?
    
    public var interstitialAd: InterstitialAd?
    
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
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
            return
        }
 
        self.adListener = adListener
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
        parseNovaAdString(adString: adString, adType: novaAdType, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        let adOpenActionHandler = NovaAdOpenActionHandler()
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
                
                nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
                
                novaNativeAdView.addSubview(nativeAdContainer)
                novaNativeAdView.tappableViews = [UIView]()
                novaNativeAdView.tappableViews?.append(mediaView)
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
                    nativeAd.priceInDollar = self.priceInDollar
                    nativeAd.adInfo["price"] = self.priceInDollar
                    nativeAd.adInfo["isVideo"] = (nativeAdItem.creativeType == .nativeVideo)
                    nativeAd.nativeAdItem = nativeAdItem
                    self.nativeAdItem = nativeAdItem
                    self.nativeAd = nativeAd
                    nativeAdItem.delegate = self
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest {
                        handleAdLoaded(ad: nativeAd, listener: adListener, adRequest: adRequest)
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nativeAd, fill: true, isFromCache: false)
                    }
                }
                
            case "app_open":
                let appOpenAds = NovaAdBuilder.buildAppOpenAds(adItems: ads, adUnitId: adUnitId)
                let appOpenAd = appOpenAds.first
                
                var novaInterstitialAd = NovaInterstitialAd(adNetworkAdapter: self)
                novaInterstitialAd.interstitialAdItem = appOpenAd
                //ad.fullScreenContentDelegate = self
                DispatchQueue.main.async {
                    novaInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                
                    self.interstitialAd = novaInterstitialAd
                    novaInterstitialAd.adInfo["price"] = self.priceInDollar
                    appOpenAd?.delegate = self
                
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest {
                        if appOpenAd?.creativeType == .nativeImage {
                            appOpenAd?.preloadAdImage() { image in
                                DispatchQueue.main.async {
                                    if let image = image {
                                        handleAdLoaded(ad: novaInterstitialAd, listener: adListener, adRequest: adRequest)
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: novaInterstitialAd, fill: true, isFromCache: false)
                                    } else {
                                        self.adListener?.onError(msg: "fail to load ad media")
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                handleAdLoaded(ad: novaInterstitialAd, listener: adListener, adRequest: adRequest)
                            }
                        }
                    }
                }
                
            default:
                self.adListener?.onError(msg: "unknown adType")
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            }
        } catch {
            self.adListener?.onError(msg: "error decode nova ad string")
            self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
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
}

extension NovaAdapter: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
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
                self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }
    
    public func appOpenAdDidLogClick(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
        }
    }
}


public let testAdString = "{\n \"ad\": [\n  {\n   \"creative\": {\n    \"ctrUrl\": \"https://track.igtsmts.space/cf/r/6693b87a226495001263b679?CALLBACK_PARAM=nvss_29971B64EA204EE6BDA9A0A76A81F322_1812453003195670530&OS=ios&CAMPAIGN_ID=1812451571012820994&CAMPAIGN_NAME=ring&FLIGHT_ID=1812452996103102465&FLIGHT_NAME=ring+%28copy%29&CREATIVE_ID=1812453003195670530&CREATIVE_NAME=ring-1%28copy%29+%28copy%29&is_nova=true&utm_content=nvss_29971B64EA204EE6BDA9A0A76A81F322_1812453003195670530&nb_cid=29971B64EA204EE6BDA9A0A76A81F322_1812453003195670530\",\n    \"headline\": \"Harrisburg Today only! 💍How to buy a ring for $20?\",\n    \"body\": \"✨We are closing the store and selling everything. Tap below and  Check price!⬇️\",\n    \"callToAction\": \"See Details✅ \\u003e\\u003e\",\n    \"imageUrl\": \"https://static.particlenews.com/nova/assets/1807749340644192257/3ea4917e1b293031e45573210ff31d4dde4154db_trans.mp4/360_30_3mbps_h264.mp4\",\n    \"address\": \"\",\n    \"creativeType\": \"VIDEO\",\n    \"image\": \"\",\n    \"thirdPartyImpressionTrackingUrls\": [],\n    \"thirdPartyViewTrackingUrls\": [],\n    \"thirdPartyClickTrackingUrls\": [],\n    \"launchOption\": \"LAUNCH_WEBVIEW\",\n    \"advertiser\": \"Search results\",\n    \"adm\": \"\",\n    \"carouselItems\": [],\n    \"iconUrl\": \"https://static.particlenews.com/nova/assets/1807749340644192257/fe69d6780dd697024221c1eb084860f481035cd6.jpg\",\n    \"videoItem\": {\n     \"videoUrl\": \"https://static.particlenews.com/nova/assets/1807749340644192257/3ea4917e1b293031e45573210ff31d4dde4154db_trans.mp4/360_30_3mbps_h264.mp4\",\n     \"coverUrl\": \"\",\n     \"isPlayAutomatically\": true,\n     \"isLoop\": true,\n     \"isMute\": true,\n     \"isVideoClickable\": true,\n     \"isVertical\": true,\n     \"isPlayOnLandingPage\": false\n    },\n    \"channelId\": \"\",\n    \"isImageClickable\": false,\n    \"isVerticalImage\": true,\n    \"imageUrls\": [],\n    \"imageScaleMode\": \"\",\n    \"layout\": \"\"\n   },\n   \"expirationMs\": \"1733366873177\",\n   \"encryptedAdToken\": \"29971B64-EA20-4EE6-BDA9-A0A76A81F322.CjII1oTvnrkyFcFeqMAaJDI5OTcxQjY0LUVBMjAtNEVFNi1CREE5LUEwQTc2QTgxRjMyMhCB4KzgqM6aixkYgsDF9p3jx5MZIIHAxebajMiTGSiC4L+Vm4uRrxkwgsDFnPWMyJMZOgVDTElDS0gBUhFOQVRJVkVfSU5fQVJUSUNMRVombm92YS1pb3MtYXJ0aWNsZS1pbnNpZGUtbmF0aXZlLXByb2Qtb2JqzwNodHRwczovL3RyYWNrLmlndHNtdHMuc3BhY2UvY2Yvci82NjkzYjg3YTIyNjQ5NTAwMTI2M2I2Nzk/Q0FMTEJBQ0tfUEFSQU09bnZzc18yOTk3MUI2NEVBMjA0RUU2QkRBOUEwQTc2QTgxRjMyMl8xODEyNDUzMDAzMTk1NjcwNTMwJk9TPWlvcyZDQU1QQUlHTl9JRD0xODEyNDUxNTcxMDEyODIwOTk0JkNBTVBBSUdOX05BTUU9cmluZyZGTElHSFRfSUQ9MTgxMjQ1Mjk5NjEwMzEwMjQ2NSZGTElHSFRfTkFNRT1yaW5nKyUyOGNvcHklMjkmQ1JFQVRJVkVfSUQ9MTgxMjQ1MzAwMzE5NTY3MDUzMCZDUkVBVElWRV9OQU1FPXJpbmctMSUyOGNvcHklMjkrJTI4Y29weSUyOSZpc19ub3ZhPXRydWUmdXRtX2NvbnRlbnQ9bnZzc18yOTk3MUI2NEVBMjA0RUU2QkRBOUEwQTc2QTgxRjMyMl8xODEyNDUzMDAzMTk1NjcwNTMwJm5iX2NpZD0yOTk3MUI2NEVBMjA0RUU2QkRBOUEwQTc2QTgxRjMyMl8xODEyNDUzMDAzMTk1NjcwNTMwcYUPUBG+N+E/egNHU1CRAQAAAAA71Z0/mQEAAAAAmD/dP6ABkOQBqAHQ59OxizKwAdn43aW5MroBBAgBEArCAQVEQUlMWdIBDk1BWF9DT05WRVJTSU9O2QE4iKXcC546QOIBCVBPU1RfUEFJROgBgeCs4KjOmosZ8AH///////////8BiQIAAACAxnCeP5ECAAAAQPZl3D+ZAoUPUBG+N+E/sQI4iKXcC546QA==\",\n   \"startTimeMs\": \"1721043842000\",\n   \"requestId\": \"29971B64-EA20-4EE6-BDA9-A0A76A81F322\",\n   \"adId\": \"1812453003195670530\",\n   \"adsetId\": \"1812452996103102465\",\n   \"price\": 5.3805449849504381\n  }\n ],\n \"status\": \"success\",\n \"code\": 0,\n \"abConfig\": {}\n}\n"
