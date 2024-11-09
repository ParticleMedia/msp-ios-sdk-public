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
        parseNovaAdString(adString: testadString, adType: novaAdType, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
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
                
                let novaSubViews = [novaNativeAdView.titleLabel, novaNativeAdView.bodyLabel, novaNativeAdView.advertiserLabel, novaNativeAdView.callToActionButton, mediaView]
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
                        handleAdLoaded(ad: novaInterstitialAd, listener: adListener, adRequest: adRequest)
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: novaInterstitialAd, fill: true, isFromCache: false)
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
            self.adMetricReporter?.logAdImpression(ad: nativeAd)
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
            self.adMetricReporter?.logAdImpression(ad: interstitialAd)
        }
    }
    
    public func appOpenAdDidLogClick(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
        }
    }
    
}


public let testadString = """
{
"ad": [
{
  "creative": {
    "ctrUrl": "https://pirmtrack.com/index.php?route=jgo29b3fiwnt1ddzxoy9&clickid=nvss_3664BB667F894370844B9574C4E58ABF_1797565827727880193&os=ios&cpid=1790759981782003714&cpname=NW01+-+Squaredance+-++Ozempic+&adsetid=1797565377049915394&adsname=US%28OG%29+Male&adid=1797565827727880193&adname=VIDOld&is_nova=true&utm_content=nvss_3664BB667F894370844B9574C4E58ABF_1797565827727880193&nb_cid=3664BB667F894370844B9574C4E58ABF_1797565827727880193",
    "headline": "Join OVER 1,500,000 weight loss patients with Ozempic!",
    "body": "Get approved with this 3-min quiz, no insurance needed 🔥",
    "callToAction": "Shop Now",
    "imageUrl": "https://static.particlenews.com/nova/assets/1790462451202519041/74bce18f018c86e9f019dd6463b8596ea8868730_trans.mp4/360_30_3mbps_h264.mp4",
    "address": "",
    "creativeType": "VIDEO",
    "image": "",
    "thirdPartyImpressionTrackingUrls": [],
    "thirdPartyViewTrackingUrls": [],
    "thirdPartyClickTrackingUrls": [],
    "launchOption": "LAUNCH_WEBVIEW",
    "advertiser": "Ozempic",
    "adm": "",
    "carouselItems": [],
    "iconUrl": "https://static.particlenews.com/nova/assets/1790462451202519041/6219b00517e90abe135dda3502e85b2ff3cf017d.jpg",
    "videoItem": {
      "videoUrl": "https://static.particlenews.com/nova/assets/1790462451202519041/74bce18f018c86e9f019dd6463b8596ea8868730_trans.mp4/360_30_3mbps_h264.mp4",
      "coverUrl": "",
      "isPlayAutomatically": true,
      "isLoop": true,
      "isMute": false,
      "isVideoClickable": true,
      "isVertical": true,
      "isPlayOnLandingPage": false
    },
    "channelId": "",
    "isImageClickable": false
  },
  "expirationMs": "1719452171875",
  "encryptedAdToken": "3664BB66-7F89-4370-844B-9574C4E58ABF.CjII4Ijps4UyFUK1qMAaJDM2NjRCQjY2LTdGODktNDM3MC04NDRCLTk1NzRDNEU1OEFCRhCB4Oecz4PA7BgYguDngPPWg+0YIILg5/z7hY/5GCiC4OfqipOP+RgwgeDn8IqTj/kYOgVDTElDS0CQTkgBUg9JTU1FUlNJVkVfVklERU9aJm5vdmEtaW9zLWltbWVyc2l2ZS1mbG93LW5hdGl2ZS1wcm9kLW9iaqwDaHR0cHM6Ly9waXJtdHJhY2suY29tL2luZGV4LnBocD9yb3V0ZT1qZ28yOWIzZml3bnQxZGR6eG95OSZjbGlja2lkPW52c3NfMzY2NEJCNjY3Rjg5NDM3MDg0NEI5NTc0QzRFNThBQkZfMTc5NzU2NTgyNzcyNzg4MDE5MyZvcz1pb3MmY3BpZD0xNzkwNzU5OTgxNzgyMDAzNzE0JmNwbmFtZT1OVzAxKy0rU3F1YXJlZGFuY2UrLSsrT3plbXBpYysmYWRzZXRpZD0xNzk3NTY1Mzc3MDQ5OTE1Mzk0JmFkc25hbWU9VVMlMjhPRyUyOStNYWxlJmFkaWQ9MTc5NzU2NTgyNzcyNzg4MDE5MyZhZG5hbWU9VklET2xkJmlzX25vdmE9dHJ1ZSZ1dG1fY29udGVudD1udnNzXzM2NjRCQjY2N0Y4OTQzNzA4NDRCOTU3NEM0RTU4QUJGXzE3OTc1NjU4Mjc3Mjc4ODAxOTMmbmJfY2lkPTM2NjRCQjY2N0Y4OTQzNzA4NDRCOTU3NEM0RTU4QUJGXzE3OTc1NjU4Mjc3Mjc4ODAxOTNxPJZ4h52wAECRAQAAAIB0Gq0/mQEAAACA2P5uP6ABkMsBqAHgwvPr/TGwAeP817qFMroBBAgBEAHCAQVEQUlMWcoBJDNCMDZDNDc4LTg0M0YtNDg0OS1BNjAzLTJGNkU5OTFCNjQ3Q9IBCkNPTlZFUlNJT07ZAZ7S2gpib0FA4gEIUFJFX1BBSUToAYHg55zPg8DsGPAB////////////AYkCAAAAYBsIrj+RAgAAAODhJGU/mQI8lniHnbAAQA==",
  "startTimeMs": "1717407900000",
  "requestId": "3664BB66-7F89-4370-844B-9574C4E58ABF",
  "adId": "1797565827727880193",
  "adsetId": "1797565377049915394",
  "price": 20.86237963073272
}
],
"status": "success",
"code": 0,
"abConfig": {}
}
"""
