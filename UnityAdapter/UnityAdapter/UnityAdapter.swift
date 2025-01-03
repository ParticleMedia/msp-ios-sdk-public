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
    // to do: interstitial and native, multiformat
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    
    public weak var bannerAd: BannerAd?
    public var bannerView: LPMBannerAdView?
    
    private var interstitialAdItem: LPMInterstitialAd?
    public weak var interstitialAd: UnityInterstitialAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String) {
        self.auctionBidListener = auctionBidListener
        self.adListener = adListener
        self.adRequest = adRequest
        self.bidderPlacementId = bidderPlacementId
        
        if adRequest.adFormat == .interstitial {
            self.interstitialAdItem = LPMInterstitialAd(adUnitId: "wmgt0712uuux8ju4")
            self.interstitialAdItem?.setDelegate(self)
            self.interstitialAdItem?.loadAd()
        } else {
            self.bannerView = LPMBannerAdView(adUnitId: bidderPlacementId)
            bannerView?.setDelegate(self)
            if let adSize = adRequest.adSize {
                self.setBannerAdSize(adSize: adSize)
            }
            if let viewController = adListener.getRootViewController() {
                bannerView?.loadAd(with: viewController)
            } else {
                auctionBidListener.onError(error: "unity banner no valid UIViewController")
            }
        }
    }
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        if let params = initParams.getParameters(),
           let appKey = params["unityAppKey"] as? String {
            let requestBuilder = LPMInitRequestBuilder(appKey: appKey)
                .withLegacyAdFormats([IS_REWARDED_VIDEO])
                .withUserId(UserDefaults.standard.string(forKey: "msp_user_id") ?? "")
            // Build the initial request
            let initRequest = requestBuilder.build()
            // Initialize LevelPlay with the prepared request
            LevelPlay.initWith(initRequest)
            { config, error in
                if let error = error {
                    adapterInitListener.onComplete(adNetwork: .unity, adapterInitStatus: .SUCCESS, message: "")
                } else {
                    
                }
            }
        }
    }
    
    public func destroyAd() {
        
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        
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
        self.bannerView?.pauseAutoRefresh()
        if let bannerView = self.bannerView,
           let auctionBidListener = self.auctionBidListener {
            let bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            bannerAd.adInfo["price"] = adInfo.revenue
            self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: bidderPlacementId ?? "unity_placement_id")
        } else if let interstitialAdItem = self.interstitialAdItem,
                  let auctionBidListener = self.auctionBidListener {
            let interstitialAd = UnityInterstitialAd(adNetworkAdapter: self)
            interstitialAd.interstitialAdItem = interstitialAdItem
            interstitialAd.rootViewController = adListener?.getRootViewController()
            self.interstitialAd = interstitialAd
            interstitialAd.adInfo["price"] = adInfo.revenue
            self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: bidderPlacementId ?? "unity_placement_id")
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
        if let bannerAd = self.bannerAd {
            adListener?.onAdImpression(ad: bannerAd)
        } else if let interstitialAd = self.interstitialAd {
            adListener?.onAdImpression(ad: interstitialAd)
        }
    }
    
    public func didCloseAd(with adInfo: LPMAdInfo) {
        if let interstitialAd = self.interstitialAd {
            adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
}

