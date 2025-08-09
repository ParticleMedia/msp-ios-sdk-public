//
//  AmazonAdapter.swift
//  AmazonAdapter
//
//  Created by Huanzhi Zhang on 8/8/25.
//
import MSPiOSCore
import Foundation
import DTBiOSSDK
import GoogleMobileAds

@objc public class AmazonAdapter : NSObject, AdNetworkAdapter {
    private var dtbAdLoader: DTBAdLoader?
    private var dtbAdResponse: DTBAdResponse?
    
    private var bannerView: AdManagerBannerView?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    public var googlePlacementId: String? // placement id used in google banner view

    public var adRequest: AdRequest?
    private var adMetricReporter: AdMetricReporter?
    
    private var bannerAd: BannerAd?
    
    public weak var adListener: AdListener?
    public var priceInDollar: Double?
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String : String]?) {
        self.adListener = adListener
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        self.adRequest = adRequest
        if let params = params,
           let googlePlacementId = params["googlePlacementId"] {
            self.googlePlacementId = googlePlacementId
        }
        let dtbAdLoader = DTBAdLoader()
        self.dtbAdLoader = dtbAdLoader
        let dtbAdSize = DTBAdSize(bannerAdSizeWithWidth: 320, height: 50, andSlotUUID: bidderPlacementId)
        dtbAdLoader.setAdSizes([dtbAdSize])
        dtbAdLoader.loadAd(self)
    }
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        if let params = initParams.getParameters(),
           let appKey = params[InitializationParametersCustomKeys.AMAZON_APP_KEY] as? String {
            DTBAds.sharedInstance().setAppKey(appKey)
        }
        DTBAds.sharedInstance().mraidPolicy = CUSTOM_MRAID
        DTBAds.sharedInstance().mraidCustomVersions = ["1.0", "2.0", "3.0"]
        DTBAds.sharedInstance().useGeoLocation = true
    }
    
    public func destroyAd() {
        
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .amazon
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        
    }
    
    public func getSDKVersion() -> String {
        return ""
    }
    
    public func sendClickAdEvent(ad: MSPAd) {
        if let adRequest = adRequest {
            self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: self)
        }
    }
}

extension AmazonAdapter: DTBAdCallback {
    public func onSuccess(_ adResponse: DTBAdResponse!) {
        
        self.dtbAdResponse = adResponse
        let bannerView = AdManagerBannerView(adSize: AdSizeBanner)
        self.bannerView = bannerView
        bannerView.adUnitID = self.googlePlacementId
        bannerView.rootViewController = self.adListener?.getRootViewController()
        bannerView.delegate = self
        let gamRequest = AdManagerRequest()
        gamRequest.customTargeting = adResponse.customTargeting()
        bannerView.load(gamRequest)
        
    }
    
    public func onFailure(_ error: DTBAdError) {
        
    }
    
}
extension AmazonAdapter: GoogleMobileAds.BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        MSPLogger.shared.info(message: "[Adapter: Amazon] successfully loaded Google Banner ad")
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.google.rawValue
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
            if let adListener = self.adListener,
               let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                //handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }
    
    public func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Amazon] Fail to load Google Banner ad")
        self.auctionBidListener?.onError(error: error.localizedDescription)
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: error.localizedDescription)
        }
    }
    
    public func bannerViewDidRecordClick(_ bannerView: GoogleMobileAds.BannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdClick(ad: googleAd)
            self.sendClickAdEvent(ad: googleAd)
        }
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: GoogleMobileAds.BannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdImpression(ad: googleAd)
            if let adRequest = adRequest {
                self.adMetricReporter?.logAdImpression(ad: googleAd, adRequest: adRequest, bidResponse: self)
            }
        }
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
}
