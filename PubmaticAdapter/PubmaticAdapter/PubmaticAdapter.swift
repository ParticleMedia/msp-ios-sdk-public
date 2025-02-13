//
//  PubmaticAdapter.swift
//  PubmaticAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
//import shared
import PrebidMobile
import OpenWrapSDK


@objc public class PubmaticAdapter : NSObject, AdNetworkAdapter {

    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: POBBannerView?

    private var interstitialAdItem: POBInterstitial?
    public weak var interstitialAd: PubmaticInterstitialAd?

    private var pubmaticNativeAdLoader: POBNativeAdLoader?
    private var nativeAdItem: POBNativeAd?
    public weak var nativeAd: PubmaticNativeAd?
    
    public var priceInDollar: Double?
    
    private var adMetricReporter: AdMetricReporter?

    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {
        DispatchQueue.main.async {

            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId

            let adFormat = bidderFormat ?? adRequest.adFormat
            
            let publisherId = params?["pubmaticPublisherId"] as? String ?? ""
            var profileId = NSNumber(value: 0)
            
            if let profileIdString = params?["pubmaticProfileId"] as? String,
               let profileIdInt = Int(profileIdString){
                profileId = NSNumber(value: profileIdInt)
            }

            if adFormat == .interstitial {
                self.interstitialAdItem = POBInterstitial(publisherId: publisherId,
                                                          profileId: profileId,
                                                          adUnitId: bidderPlacementId)
                self.interstitialAdItem?.delegate = self
                self.interstitialAdItem?.loadAd()
            } else if adFormat == .native {
                self.pubmaticNativeAdLoader = POBNativeAdLoader(publisherId: publisherId, profileId: profileId, adUnitId: bidderPlacementId, templateType: POBNativeTemplateType.medium)

                self.pubmaticNativeAdLoader?.delegate = self
                self.pubmaticNativeAdLoader?.bidEventDelegate = self
                self.pubmaticNativeAdLoader?.loadAd()

            } else {
                self.bannerView = POBBannerView(publisherId: publisherId, profileId: profileId, adUnitId: bidderPlacementId, adSizes: [POBAdSizeMake(CGFloat(adRequest.adSize?.width ?? 320), CGFloat(adRequest.adSize?.height ?? 50))])
                self.bannerView?.delegate = self
                self.bannerView?.loadAd()
            }
        }
    }

    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        let openWrapSDKConfig = OpenWrapSDKConfig(publisherId: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_PUBLISHER_ID] as? String ?? "",
                                                  andProfileIds: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_PROFILE_IDS] as? [NSNumber] ?? [NSNumber]())

        OpenWrapSDK.initialize(with: openWrapSDKConfig) { (success, error) in
            if success {
                print("OpenWrap SDK initialization successful")
            } else if let error = error {
                print("OpenWrap SDK initialization failed with error : \(error.localizedDescription)")
            }

            // Set a valid App Store URL, containing the app id of your iOS app.
            let appInfo = POBApplicationInfo()
            if let storeUrl = URL(string: initParams.getParameters()?[InitializationParametersCustomKeys.PUBMATIC_STORE_URL] as? String ?? "") {
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

    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAdItem else {return}

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
                    mediaView.heightAnchor.constraint(equalTo: mediaContainer.heightAnchor)
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

            nativeAdItem.renderAd(with: templateView, andCompletion: { [weak self] (nativeAd: POBNativeAd, error: Error?) in
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
        let auctionBid = AuctionBid(bidderName: "pubmatic", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .pubmatic
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
            guard let auctionBidListener = self.auctionBidListener else {return}
            if let bannerView = self.bannerView {
                
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo["price"] = bannerView.bid().price.doubleValue
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "pubmatic_placement_id")
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }
    }


    public func bannerView(_ bannerView: POBBannerView, didFailToReceiveAdWithError error: Error) {
        self.bannerView?.pauseAutoRefresh()
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: POBBannerView) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "pubmatic"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.bannerAd?.adInfo["price"]
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func bannerViewDidClickAd(_ bannerView: POBBannerView) {
        DispatchQueue.main.async {
            if let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
            }
        }
    }
}


extension PubmaticAdapter: POBInterstitialDelegate {
    public func interstitialDidReceiveAd(_ interstitial: POBInterstitial) {

        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else {return}
            
            if let interstitialAdItem = self.interstitialAdItem {
                let interstitialAd = PubmaticInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo["price"] = interstitial.bid().price.doubleValue
                self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "pubmatic")
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }
    }

    // Notifies the delegate an error occurred while loading an ad.
    public func interstitial(_ interstitial: POBInterstitial, didFailToReceiveAdWithError error: Error) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func interstitialDidRecordImpression(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "pubmatic"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.interstitialAd?.adInfo["price"]
                if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func interstitialDidClickAd(_ interstitial: POBInterstitial) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
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
                let pubmaticNativeAd = PubmaticNativeAd(adNetworkAdapter: self,
                                                        title: "",
                                                        body: "",
                                                        advertiser: "",
                                                        callToAction: "")
                pubmaticNativeAd.nativeAdItem = nativeAd
                self.nativeAd = pubmaticNativeAd
                pubmaticNativeAd.adInfo["price"] = self.priceInDollar ?? 0.0
                
                if let adListener = self.adListener,
                   let adRequest = self.adRequest,
                   let auctionBidListener = self.auctionBidListener {
                    //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                    self.handleAdLoaded(ad: pubmaticNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                    //self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: pubmaticNativeAd, fill: true, isFromCache: false)
                }
            }
        }
    }

    public func nativeAdLoader(_ adLoader: POBNativeAdLoader, didFailToReceiveAdWithError error: Error) {
        self.auctionBidListener?.onError(error: "fail to load ad")
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
               let adRequest = self.adRequest {
                self.adListener?.onAdImpression(ad: nativeAd)
                var params = [String:Any?]()
                params["seat"] = "pubmatic"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.nativeAd?.adInfo["price"]
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
            }
        }
    }
    
    public func nativeAdDidRecordClick(_ nativeAd: POBNativeAd) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
            }
        }
    }
    
    public func nativeAd(_ nativeAd: POBNativeAd, didRecordClickForAsset assetId: Int) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
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
