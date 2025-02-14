//
//  MintegralAdapter.swift
//  MintegralAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//
import Foundation
import MSPiOSCore
//import shared
import PrebidMobile
import MTGSDK
import MTGSDKBanner
import MTGSDKNewInterstitial
import MTGSDKBidding


@objc public class MintegralAdapter : NSObject, AdNetworkAdapter {

    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    
    public var adUnitId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: MTGBannerAdView?

    public var mintegralInterstitialAdManager: MTGNewInterstitialBidAdManager?
    public weak var interstitialAd: MintegralInterstitialAd?

    public var mintegralNativeAdManager: MTGBidNativeAdManager?
    public var nativeAdItem: MTGCampaign?
    public weak var nativeAd: MintegralNativeAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    private var mtgBidResponse: MTGBiddingResponse?


    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {

        DispatchQueue.main.async {

            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId

            let adFormat = bidderFormat ?? adRequest.adFormat
            self.adUnitId = params?["mintegralAdUnitAd"] as? String
            if adFormat == .interstitial {
                self.loadInterstitialAd(auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest, bidderPlacementId: bidderPlacementId, params: params)
                
            } else if adFormat == .native {
                self.loadNativeAd(auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest, bidderPlacementId: bidderPlacementId, params: params)
                
            } else {
                self.loadBanenrAd(auctionBidListener: auctionBidListener, adListener: adListener, adRequest: adRequest, bidderPlacementId: bidderPlacementId, params: params)
                
            }
        }
    }

    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        MTGSDK.sharedInstance().setAppID(initParams.getParameters()?[InitializationParametersCustomKeys.MINTEGRAL_APP_ID] as? String ?? "",
                                         apiKey: initParams.getParameters()?[InitializationParametersCustomKeys.MINTEGRAL_API_KEY] as? String ?? "")
        adapterInitListener.onComplete(adNetwork: .pubmatic, adapterInitStatus: .SUCCESS, message: "")
    }

    public func destroyAd() {

    }

    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        DispatchQueue.main.async {
            guard let nativeAdView = nativeAdView as? NativeAdView,
                  let nativeAdItem = self.nativeAdItem else {return}

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

                var clickableViews = [UIView]()

                for view in [nativeAdView, nativeAdView,nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getMedia(), nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction()] {
                    if let view = view {
                        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                        //view.addGestureRecognizer(tapGesture)
                        clickableViews.append(view)
                    }
                }
                self.mintegralNativeAdManager?.registerView(forInteraction: mediaView, withClickableViews: clickableViews, with: nativeAdItem)

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
        let auctionBid = AuctionBid(bidderName: "mintegral", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .mintegral
    }
    
    private func loadBanenrAd(auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String:String]?) {
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
        MTGBiddingRequest.getBidWith(bannerParam) {[weak self] bidResponse in
            if bidResponse.success {
                self?.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self?.bannerView = MTGBannerAdView(bannerAdViewWithAdSize: CGSize(width: adRequest.adSize?.width ?? 320, height: adRequest.adSize?.height ?? 50),
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
    
    private func loadNativeAd(auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String:String]?) {
        var floor: NSNumber?
        if let floorStr = params?["floor"] {
            floor = NumberFormatter().number(from: floorStr)
        }
        let nativeParams = MTGBiddingRequestParameter(placementId: bidderPlacementId,
                                                      unitId: self.adUnitId ?? "",
                                                      basePrice: floor ?? 0.0)
        MTGBiddingRequest.getBidWith(nativeParams) {[weak self] bidResponse in
            if bidResponse.success {
                self?.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self?.mintegralNativeAdManager = MTGBidNativeAdManager(placementId: bidderPlacementId,
                                                                       unitID: self?.adUnitId ?? "",
                                                                       presenting: adListener.getRootViewController())
                self?.mintegralNativeAdManager?.delegate = self
                self?.mintegralNativeAdManager?.load(withBidToken: bidResponse.bidToken)
            } else {
                auctionBidListener.onError(error: "Mintegral bid fail")
            }
        }
    }
    
    private func loadInterstitialAd(auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, params: [String:String]?) {
        var floor: NSNumber?
        if let floorStr = params?["floor"] {
            floor = NumberFormatter().number(from: floorStr)
        }
        
        let interstitialParams = MTGBiddingRequestParameter(placementId: bidderPlacementId,
                                                            unitId: self.adUnitId ?? "",
                                                            basePrice: floor ?? 0.0)
        
        MTGBiddingRequest.getBidWith(interstitialParams) {[weak self] bidResponse in
            guard let self  = self else {
                auctionBidListener.onError(error: "Mintegral bid fail")
                return
            }
            if bidResponse.success {
                self.mtgBidResponse = bidResponse
                bidResponse.notifyWin()
                self.mintegralInterstitialAdManager = MTGNewInterstitialBidAdManager(placementId:bidderPlacementId,
                                                                                  unitId:self.adUnitId ?? "",
                                                                                  delegate:self )
                self.mintegralInterstitialAdManager?.loadAd(withBidToken: bidResponse.bidToken)
            } else {
                auctionBidListener.onError(error: "Mintegral bid fail")
            }
        }
    }
}

extension MintegralAdapter: MTGBannerAdViewDelegate {
    public func adViewLoadSuccess(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else {return}
            if let bannerView = self.bannerView {
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo["price"] = self.mtgBidResponse?.price ?? 0.0
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "mintegral_placement_id")
            }
        }
    }

    public func adViewLoadFailedWithError(_ error: (any Error)!, adView: MTGBannerAdView!) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }

    public func adViewWillLogImpression(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "mintegral"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.mtgBidResponse?.price ?? 0.0
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }

    public func adViewDidClicked(_ adView: MTGBannerAdView!) {
        DispatchQueue.main.async {
            if let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
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
            guard let auctionBidListener = self.auctionBidListener else {return}
            
            if let mintegralInterstitialAdManager = self.mintegralInterstitialAdManager {
                let interstitialAd = MintegralInterstitialAd(adNetworkAdapter: self)
                interstitialAd.mintegralInterstitialAdManager = mintegralInterstitialAdManager
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo["price"] = self.mtgBidResponse?.price ?? 0.0
                self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "mintegral")
            }
        }
    }

    public func newInterstitialAdLoadFail(_ error: NSError, _ adManager: MTGNewInterstitialAdManager) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func newInterstitialBidAdShowSuccess(_ adManager: MTGNewInterstitialBidAdManager) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "inmobi"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.mtgBidResponse?.price ?? 0.0
                if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func newInterstitialBidAdClicked(_ adManager: MTGNewInterstitialBidAdManager) {
        // to do: investigate why it is called multiple times
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
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
            DispatchQueue.main.async{
                self.nativeAdItem = nativeAdItem
                if let auctionBidListener = self.auctionBidListener {
                    var mintegralNativeAd = MintegralNativeAd(adNetworkAdapter: self,
                                                              title:  nativeAdItem.appName,
                                                              body: nativeAdItem.appDesc,
                                                                advertiser: "",
                                                              callToAction: nativeAdItem.adCall)
                    mintegralNativeAd.nativeAdItem = nativeAdItem
                    self.nativeAd = mintegralNativeAd
                    mintegralNativeAd.adInfo["price"] = self.mtgBidResponse?.price ?? 0.0
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        self.handleAdLoaded(ad: mintegralNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)

                    }

                }
            }
        }
    }
    
    public func nativeAdsFailedToLoadWithError(_ error: Error, bidNativeManager: MTGBidNativeAdManager) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func nativeAdDidClick(_ nativeAd: MTGCampaign, bidNativeManager: MTGBidNativeAdManager) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
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
               let adRequest = self.adRequest {
                self.adListener?.onAdImpression(ad: nativeAd)
                var params = [String:Any?]()
                params["seat"] = "mintegral"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.mtgBidResponse?.price ?? 0.0
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
            }
        }
    }
}
