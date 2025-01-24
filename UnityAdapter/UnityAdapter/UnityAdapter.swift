//
//  UnityAdapter.swift
//  UnityAdapter
//
//  Created by Huanzhi Zhang on 12/23/24.
//

import Foundation
import MSPiOSCore
import IronSource

@objc public class UnityAdapter : NSObject, AdNetworkAdapter {
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    
    public weak var bannerAd: BannerAd?
    public var bannerView: LPMBannerAdView?
    
    private var interstitialAdItem: LPMInterstitialAd?
    public weak var interstitialAd: UnityInterstitialAd?
    
    private var nativeAdItem: LevelPlayNativeAd?
    public weak var nativeAd: UnityNativeAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?) {
        
        DispatchQueue.main.async {
            
            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId
            
            let adFormat = bidderFormat ?? adRequest.adFormat
            
            if adFormat == .interstitial {
                self.interstitialAdItem = LPMInterstitialAd(adUnitId: bidderPlacementId)
                self.interstitialAdItem?.setDelegate(self)
                self.interstitialAdItem?.loadAd()
            } else if adFormat == .native {
                if let rootViewController = adListener.getRootViewController() {
                    let levelPlayNativeAd: LevelPlayNativeAd = LevelPlayNativeAdBuilder()
                        .withViewController(rootViewController)
                        //.withPlacementName("o8vvkqbt8zvdv7i7") // Replace with your placement or leave empty
                        .withDelegate(self)
                        .build()
                    self.nativeAdItem = levelPlayNativeAd
                    levelPlayNativeAd.load()
                } else {
                    auctionBidListener.onError(error: "unity native no valid UIViewController")
                }
            } else {
                self.bannerView = LPMBannerAdView(adUnitId: bidderPlacementId)
                self.bannerView?.setDelegate(self)
                if let adSize = adRequest.adSize {
                    self.setBannerAdSize(adSize: adSize)
                }
                if let viewController = adListener.getRootViewController() {
                    self.bannerView?.loadAd(with: viewController)
                } else {
                    auctionBidListener.onError(error: "unity banner no valid UIViewController")
                }
            }
        }
    }
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        if let params = initParams.getParameters(),
           let appKey = params["unityAppKey"] as? String {
            let requestBuilder = LPMInitRequestBuilder(appKey: appKey)
                .withLegacyAdFormats([IS_REWARDED_VIDEO, IS_NATIVE_AD])
                .withUserId(UserDefaults.standard.string(forKey: "msp_user_id") ?? "")
            // Build the initial request
            let initRequest = requestBuilder.build()
            // Initialize LevelPlay with the prepared request
            LevelPlay.initWith(initRequest)
            { config, error in
                if let error = error {
                    adapterInitListener.onComplete(adNetwork: .unity, adapterInitStatus: .SUCCESS, message: "")
                } else {
                    adapterInitListener.onComplete(adNetwork: .unity, adapterInitStatus: .SUCCESS, message: "")
                }
            }
        }
    }
    
    public func destroyAd() {
        
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAdItem else {return}
        
        let unityNativeAdView = ISNativeAdView()
        unityNativeAdView.translatesAutoresizingMaskIntoConstraints = false
        
        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
            
            unityNativeAdView.adTitleView = nativeAdContainer.getTitle()
            unityNativeAdView.adBodyView = nativeAdContainer.getbody()
            unityNativeAdView.adAdvertiserView = nativeAdContainer.getAdvertiser()
            unityNativeAdView.adCallToActionView = nativeAdContainer.getCallToAction()
            
            if let mediaContainer = nativeAdContainer.getMedia(),
               let mediaView =  nativeAd.mediaView as? LevelPlayMediaView{
                unityNativeAdView.adMediaView = mediaView
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                ])
            }
            
            unityNativeAdView.addSubview(nativeAdContainer)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: unityNativeAdView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: unityNativeAdView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: unityNativeAdView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: unityNativeAdView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: unityNativeAdView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: unityNativeAdView.heightAnchor),
            ])
            
            unityNativeAdView.adTitleView?.text = nativeAd.title
            unityNativeAdView.adBodyView?.text = nativeAd.body
            unityNativeAdView.adAdvertiserView?.text = nativeAd.advertiser
            unityNativeAdView.adCallToActionView?.setTitle(nativeAd.callToAction, for: .normal)
            unityNativeAdView.adCallToActionView?.isUserInteractionEnabled = false
            unityNativeAdView.registerNativeAdViews(nativeAdItem)
            
            nativeAdView.addSubview(unityNativeAdView)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                unityNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                unityNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                unityNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                unityNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                unityNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                unityNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
            ])
            
            
        }
        
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    private func setBannerAdSize(adSize: AdSize) {
        if adSize.width == 320, adSize.height == 50 {
            bannerView?.setAdSize(LPMAdSize.banner())
        } else if adSize.width == 320, adSize.height == 90 {
            bannerView?.setAdSize(LPMAdSize.large())
        } else if adSize.width == 300, adSize.height == 250 {
            bannerView?.setAdSize(LPMAdSize.mediumRectangle())
        }
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "unity", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
    }
}

extension UnityAdapter: LPMBannerAdViewDelegate, LPMInterstitialAdDelegate {
    public func didLoadAd(with adInfo: LPMAdInfo) {
        DispatchQueue.main.async {
            self.bannerView?.pauseAutoRefresh()
            if let bannerView = self.bannerView,
               let auctionBidListener = self.auctionBidListener {
                let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo["price"] = adInfo.revenue
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "unity_placement_id")
            } else if let interstitialAdItem = self.interstitialAdItem,
                      let auctionBidListener = self.auctionBidListener {
                let interstitialAd = UnityInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo["price"] = adInfo.revenue
                self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "unity_placement_id")
            }
        }
    }
    
    public func didFailToLoadAd(withAdUnitId adUnitId: String, error: any Error) {
        self.bannerView?.pauseAutoRefresh()
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func didClickAd(with adInfo: LPMAdInfo) {
        if let bannerAd = self.bannerAd {
            adListener?.onAdClick(ad: bannerAd)
        } else if let interstitialAd = self.interstitialAd {
            adListener?.onAdClick(ad: interstitialAd)
        }
    }
    
    public func didDisplayAd(with adInfo: LPMAdInfo) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "unity"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = adInfo.revenue
                if let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self, params: params)
                } else if let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func didCloseAd(with adInfo: LPMAdInfo) {
        if let interstitialAd = self.interstitialAd {
            adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
}

extension UnityAdapter: LevelPlayNativeAdDelegate {
    public func didLoad(_ nativeAd: LevelPlayNativeAd, with adInfo: ISAdInfo) {
        DispatchQueue.main.async {
            self.nativeAdItem = nativeAd
            if let auctionBidListener = self.auctionBidListener {
                let unityNativeAd = UnityNativeAd(adNetworkAdapter: self,
                                                  title: nativeAd.title ?? "",
                                                  body: nativeAd.body ?? "",
                                                  advertiser: nativeAd.advertiser ?? "",
                                                  callToAction: nativeAd.callToAction ?? "")
                unityNativeAd.nativeAdItem = nativeAd
                self.nativeAd = unityNativeAd
                unityNativeAd.adInfo["price"] = adInfo.revenue
                
                let mediaView = LevelPlayMediaView()
                mediaView.translatesAutoresizingMaskIntoConstraints = false
                unityNativeAd.mediaView = mediaView
                
                if let adListener = self.adListener,
                   let adRequest = self.adRequest,
                   let auctionBidListener = self.auctionBidListener {
                    //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                    self.handleAdLoaded(ad: unityNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                    self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: unityNativeAd, fill: true, isFromCache: false)
                }
                
            }
        }
    }
    
    public func didFail(toLoad nativeAd: LevelPlayNativeAd, withError error: any Error) {
        print(error.localizedDescription)
    }
    
    public func didRecordImpression(_ nativeAd: LevelPlayNativeAd, with adInfo: ISAdInfo) {
        DispatchQueue.main.async {
            if let nativeAd = self.nativeAd,
               let adRequest = self.adRequest {
                self.adListener?.onAdImpression(ad: nativeAd)
                var params = [String:Any?]()
                params["seat"] = "unity"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = adInfo.revenue
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
            }
        }
    }
    
    public func didClick(_ nativeAd: LevelPlayNativeAd, with adInfo: ISAdInfo) {
        if let nativeAd = self.nativeAd {
            adListener?.onAdClick(ad: nativeAd)
        }
    }
    
}

