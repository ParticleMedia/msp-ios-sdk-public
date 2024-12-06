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
