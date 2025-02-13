//
//  InmobiAdapter.swift
//  InmobiAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//
import Foundation
import MSPiOSCore
//import shared
import PrebidMobile
import InMobiSDK

@objc public class InmobiAdapter : NSObject, AdNetworkAdapter {
    // to do: check if click call back correct, check if ad price is correct
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: IMBanner?

    private var interstitialAdItem: IMInterstitial?
    public weak var interstitialAd: InmobiInterstitialAd?

    private var nativeAdItem: IMNative?
    public weak var nativeAd: InmobiNativeAd?

    public var nativeAdView: NativeAdView?

    private var adMetricReporter: AdMetricReporter?
    
    private var price: Double?


    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {

        DispatchQueue.main.async {

            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId

            if let priceStr = params?["price"] {
                self.price = Double(priceStr) ?? 0.0
            } else {
                self.price = 0.0
            }
            let adFormat = bidderFormat ?? adRequest.adFormat
            guard let numPlacementId = Int64(bidderPlacementId) else {
                auctionBidListener.onError(error: "invalid placement id")
                return
            }
            if adFormat == .interstitial {
                self.interstitialAdItem = IMInterstitial(placementId: numPlacementId, delegate: self)
                self.interstitialAdItem?.load()
            } else if adFormat == .native {
                self.nativeAdItem = IMNative(placementId: numPlacementId);
                self.nativeAdItem?.delegate = self;
                self.nativeAdItem?.load()
            } else {
                let adSize = CGSize(width: adRequest.adSize?.width ?? 320, height: adRequest.adSize?.height ?? 50)
                self.bannerView = IMBanner(frame: CGRect(origin: .zero, size: adSize),
                                           placementId: numPlacementId);
                self.bannerView?.shouldAutoRefresh(false)
                self.bannerView?.delegate = self
                self.bannerView?.load()
            }
        }
    }

    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        var conscentDict: [String:Any]? = nil
        if initParams.hasUserConsent() {
            conscentDict = [IMCommonConstants.IM_GDPR_CONSENT_AVAILABLE : "true"]
        }
        //IMSdk.setLogLevel(IMSDKLogLevel.debug)
        if let params = initParams.getParameters(),
           let accountId = params[InitializationParametersCustomKeys.INMOBI_ACCOUNT_ID] as? String {
            IMSdk.initWithAccountID(accountId,
                                    consentDictionary: conscentDict,
                                    andCompletionHandler: { (error) in
                if let err = error {
                    print("\(err.localizedDescription)")
                }
            })
        }
        adapterInitListener.onComplete(adNetwork: .pubmatic, adapterInitStatus: .SUCCESS, message: "")
    }

    public func destroyAd() {

    }

    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAdItem else {return}

        //let inmobiNativeAdView = ISNativeAdView()
        //unityNativeAdView.translatesAutoresizingMaskIntoConstraints = false

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false


            if let mediaContainer = nativeAdContainer.getMedia(),
               let mediaView =  nativeAdItem.primaryView(ofWidth: mediaContainer.frame.size.width) {
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                ])
            }

            for view in [nativeAdView, nativeAdView,nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getMedia(), nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction()] {
                if let view = view {
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                    view.addGestureRecognizer(tapGesture)
                }
            }

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

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "inmobi", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
    }

    @objc private func handleNativeAdClick() {
        self.nativeAdItem?.reportAdClickAndOpenLandingPage()
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .inmobi
    }
}

extension InmobiAdapter: IMBannerDelegate {

    public func banner(_ banner: IMBanner, didReceiveWithMetaInfo info: InMobiSDK.IMAdMetaInfo) {
        DispatchQueue.main.async {
            if let bannerView = self.bannerView,
               let auctionBidListener = self.auctionBidListener {
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                let price = info.getBid()
                self.price = info.getBid()
                bannerAd.adInfo["price"] = info.getBid()
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "inmobi_placement_id")
            }
        }
    }


    public func banner(_ banner: IMBanner, didFailToLoadWithError error: IMRequestStatus) {
        self.auctionBidListener?.onError(error: "fail to load ad")
        
    }
    
    public func bannerAdImpressed(_ banner: InMobiSDK.IMBanner) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "inmobi"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.price
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func banner(_ banner: InMobiSDK.IMBanner, didInteractWithParams params: [String : Any]?) {
        DispatchQueue.main.async {
            if let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
            }
        }
    }
    
    
}

extension InmobiAdapter: IMInterstitialDelegate {
    

    public func interstitialDidFinishLoading(_ interstitial: IMInterstitial) {
        DispatchQueue.main.async {
            if let interstitialAdItem = self.interstitialAdItem,
               let auctionBidListener = self.auctionBidListener {
                let interstitialAd = InmobiInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo["price"] = self.price
                self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "inmobi")
            }
        }
    }
    
    public func interstitial(_ interstitial: InMobiSDK.IMInterstitial, didReceiveWithMetaInfo metaInfo: InMobiSDK.IMAdMetaInfo) {
        DispatchQueue.main.async {
            self.price = metaInfo.getBid()
        }
    }

    public func interstitial(_ interstitial: IMInterstitial, didFailToLoadWithError error: IMRequestStatus) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func interstitialAdImpressed(_ interstitial: IMInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "inmobi"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.price
                if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func interstitial(_ interstitial: InMobiSDK.IMInterstitial, didInteractWithParams params: [String : Any]?) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
            }
        }
    }
    
    public func interstitialDidDismiss(_ interstitial: InMobiSDK.IMInterstitial) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdDismissed(ad: interstitialAd)
            }
        }
    }
}

extension InmobiAdapter: IMNativeDelegate {
    public func nativeDidFinishLoading(_ native: IMNative) {
        DispatchQueue.main.async {
            self.nativeAdItem = native
            if let auctionBidListener = self.auctionBidListener {
                let inmobiNativeAd = InmobiNativeAd(adNetworkAdapter: self,
                                                    title: native.adTitle ?? "",
                                                    body: native.adDescription ?? "",
                                                    advertiser: "",
                                                    callToAction: native.adCtaText ?? "")
                inmobiNativeAd.nativeAdItem = native
                self.nativeAd = inmobiNativeAd
                inmobiNativeAd.adInfo["price"] = self.price

                //let mediaView = native.primaryView(ofWidth: <#T##CGFloat#>)
                //mediaView?.translatesAutoresizingMaskIntoConstraints = false
                //inmobiNativeAd.mediaView = mediaView

                if let adListener = self.adListener,
                   let adRequest = self.adRequest,
                   let auctionBidListener = self.auctionBidListener {
                    //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                    self.handleAdLoaded(ad: inmobiNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                    self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: inmobiNativeAd, fill: true, isFromCache: false)
                }

            }
        }
    }

    public func native(_ native: IMNative, didFailToLoadWithError error: IMRequestStatus) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }

    public func nativeAdImpressed(_ native: InMobiSDK.IMNative) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd,
               let adRequest = self.adRequest {
                self.adListener?.onAdImpression(ad: nativeAd)
                var params = [String:Any?]()
                params["seat"] = "inmobi"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.price
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
            }
        }
    }

    public func native(_ native: InMobiSDK.IMNative, didInteractWithParams params: [String : Any]?) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
            }
        }
    }
}
