//
//  MobilefuseAdapter.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore
//import shared
import PrebidMobile
import MobileFuseSDK

@objc public class MobilefuseAdapter : NSObject, AdNetworkAdapter {

    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: MFBannerAd?

    private var interstitialAdItem: MFInterstitialAd?
    public weak var interstitialAd: MobilefuseInterstitialAd?

    private var nativeAdItem: MFNativeAd?
    public weak var nativeAd: MobilefuseNativeAd?

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

            if adFormat == .interstitial {
                self.interstitialAdItem = MFInterstitialAd(placementId: bidderPlacementId)
                self.interstitialAdItem?.register(self)
                
                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.interstitialAdItem?.testMode = true
                }
                self.interstitialAdItem?.load()
            } else if adFormat == .native {
                self.nativeAdItem = MFNativeAd(placementId: bidderPlacementId)
                self.nativeAdItem?.register(self)
                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.nativeAdItem?.testMode = true
                }
                self.nativeAdItem?.load()

            } else {
                self.bannerView = MFBannerAd(placementId: bidderPlacementId, with: self.getMFBannerAdSize(adRequest: adRequest))
                self.bannerView?.register(self)
                if (adRequest.testParams["mobilefuse"] as? String) == "true" {
                    self.bannerView?.testMode = true
                }
                self.bannerView?.load()
            }
        }
    }

    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        MobileFuse.initWithDelegate(self)
        adapterInitListener.onComplete(adNetwork: .pubmatic, adapterInitStatus: .SUCCESS, message: "")
    }

    public func destroyAd() {

    }

    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAdItem else {return}

        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            //nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false


            if let mediaContainer = nativeAdContainer.getMedia(),
               let mediaView =  nativeAdItem.getMainContentView() {
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                ])
            }
            var clickableViews = [UIView]()

            for view in [nativeAdView, nativeAdView,nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getMedia(), nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction(), nativeAdItem.getMainContentView()] {
                if let view = view {
                    //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                    //view.addGestureRecognizer(tapGesture)
                    clickableViews.append(view)
                }
            }

            nativeAdItem.registerView(forInteraction: nativeAdItem.getMainContentView(), withClickableViews: clickableViews)

            //[nativeAd registerViewForInteraction:containerView withClickableViews:@[ ... ]];
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

    private func getMFBannerAdSize(adRequest: AdRequest) -> MFBannerAdSize {
        if let width = adRequest.adSize?.width,
           let height = adRequest.adSize?.height {
            if width == 300, height == 250 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_300x250
            } else if width == 320, height == 50 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_320x50
            } else if width == 300, height == 50 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_300x50
            } else if width == 728, height == 90 {
                return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_728x90
            }
        }
        return MFBannerAdSize.MOBILEFUSE_BANNER_SIZE_DEFAULT
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "mobilefuse", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .mobilefuse
    }
}

extension MobilefuseAdapter: IMFInitializationCallbackReceiver {

}

extension MobilefuseAdapter: IMFAdCallbackReceiver {

    public func onAdLoaded(_ ad: MFAd) {
        DispatchQueue.main.async {
            guard let auctionBidListener = self.auctionBidListener else {return}
            if ad is MFBannerAd,
               let bannerView = self.bannerView {
                
                let bannerAd = MobilefuseBannerAd(adView: bannerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                bannerAd.adInfo["price"] = self.price
                bannerAd.show()
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
            } else if ad is MFInterstitialAd,
                      let interstitialAdItem = self.interstitialAdItem {
                let interstitialAd = MobilefuseInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitialAdItem
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                interstitialAd.adInfo["price"] = self.price
                self.handleAdLoaded(ad: interstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
            } else if ad is MFNativeAd,
                      let nativeAdItem = self.nativeAdItem {
                DispatchQueue.main.async {
                    if let auctionBidListener = self.auctionBidListener {
                        let mobilefuseNativeAd = MobilefuseNativeAd(adNetworkAdapter: self,
                                                                    title: nativeAdItem.getTitle() ?? "",
                                                                    body: nativeAdItem.getDescriptionText() ?? "",
                                                                    advertiser: nativeAdItem.getSponsoredText() ?? "",
                                                                    callToAction: nativeAdItem.getCtaButtonText() ?? "")
                        mobilefuseNativeAd.nativeAdItem = nativeAdItem
                        self.nativeAd = mobilefuseNativeAd
                        mobilefuseNativeAd.adInfo["price"] = self.price
                        
                        if let adListener = self.adListener,
                           let adRequest = self.adRequest,
                           let auctionBidListener = self.auctionBidListener {
                            //handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                            self.handleAdLoaded(ad: mobilefuseNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? "mobilefuse_placement_id")
                            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: mobilefuseNativeAd, fill: true, isFromCache: false)
                        }
                        
                    }
                }
            } else {
                self.auctionBidListener?.onError(error: "fail to load ad")
            }
        }

    }

    public func onAdNotFilled(_ ad: MFAd) {
        self.auctionBidListener?.onError(error: "fail to load ad")
    }
    
    public func onAdRendered(_ ad: MFAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest {
                var params = [String:Any?]()
                params["seat"] = "inmobi"
                params["bidderPlacementId"] = self.bidderPlacementId
                params["price"] = self.price
                if ad is MFBannerAd,
                   let bannerAd = self.bannerAd {
                    self.adListener?.onAdImpression(ad: bannerAd)
                    self.adMetricReporter?.logAdImpression(ad: bannerAd, adRequest: adRequest, bidResponse: self, params: params)
                } else if ad is MFInterstitialAd,
                          let interstitialAd = self.interstitialAd {
                    self.adListener?.onAdImpression(ad: interstitialAd)
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: self, params: params)
                } else if ad is MFNativeAd,
                          let nativeAd = self.nativeAd {
                    self.adListener?.onAdImpression(ad: nativeAd)
                    self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: self, params: params)
                }
            }
        }
    }
    
    public func onAdClicked(_ ad: MFAd) {
        DispatchQueue.main.async {
            if ad is MFBannerAd,
               let bannerAd = self.bannerAd {
                self.adListener?.onAdClick(ad: bannerAd)
            } else if ad is MFInterstitialAd,
                      let interstitialAd = self.interstitialAd {
                self.adListener?.onAdClick(ad: interstitialAd)
            } else if ad is MFNativeAd,
                      let nativeAd = self.nativeAd {
                self.adListener?.onAdClick(ad: nativeAd)
            }
        }
    }
    
    public func onAdClosed(_ ad: MFAd) {
        DispatchQueue.main.async {
            if ad is MFInterstitialAd,
               let interstitialAd = self.interstitialAd {
                self.adListener?.onAdDismissed(ad: interstitialAd)
            }
        }
    }
}
