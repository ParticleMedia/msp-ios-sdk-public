//
//  LiftoffAdapter.swift
//  LiftoffAdapter
//
//  Created by Mingming Luo on 2025/12/9.
//

import Foundation
import VungleAdsSDK
import MSPiOSCore
import UIKit
import PrebidMobile
import SnapKit

@objc public class LiftoffAdapter: NSObject, AdNetworkAdapter {
    
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?

    public weak var interstitialAd: LiftoffInterstitialAd?

    public weak var nativeAd: LiftoffNativeAd?

    public var nativeAdView: NativeAdView?

    private var adMetricReporter: AdMetricReporter?
    
    private var priceInDollar: Double?
    
    private var bidResponse: BidResponse?
    
    /// Retains the VungleBannerView to ensure delegate callbacks are received.
    /// Without this reference, the view may be deallocated before `bannerAdDidLoad(_:)` is called.
    private var bannerView: VungleBannerView?
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        VungleAds.setIntegrationName("vunglehbs", version: "67")
        let liftoffInitKey = MSPiOSCore.InitializationParametersCustomKeys.LIFTOFF_APP_ID
        let liftoffAppId = initParams.getParameters()?[liftoffInitKey] as? String ?? ""
        VungleAds.initWithAppId(liftoffAppId) { error in
            if let error = error {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] Liftoff SDK initialization failed with error: \(error.localizedDescription)")
            } else {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] Liftoff SDK initialization successful")
            }
            adapterInitListener.onComplete(adNetwork: .liftoff, adapterInitStatus: .SUCCESS, message: "")
        }
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String : String]?) {
        DispatchQueue.main.async {
            guard bidResponse is BidResponse,
                  let mBidResponse = bidResponse as? BidResponse else {
                auctionBidListener.onError(error: "Failed to load Liftoff ad: invalid bidResponse")
                return
            }
            
            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId
            self.bidResponse = mBidResponse
            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0.0)

            let rootViewController = adListener.getRootViewController()
            
            guard let bidResponse = bidResponse as? BidResponse,
                  let winningBid = bidResponse.winningBid else {
                auctionBidListener.onError(error: "Failed to load Liftoff ad: no winning bid")
                return
            }
            
            let adFormat = bidderFormat ?? adRequest.adFormat
            
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Start to load Liftoff creative ad. AdFormat = \(adFormat), placementId = \(bidderPlacementId)")
            
            switch adFormat {
            case .interstitial:
                self.loadInterstitialAd(bidderPlacementId, winningBid, rootViewController, auctionBidListener)
            case .native:
                self.loadNativeAd(bidderPlacementId, winningBid, auctionBidListener)
            case .banner:
                self.loadBannerAd(bidderPlacementId, winningBid, adRequest, auctionBidListener)
            case .multi_format:
                self.loadMultiformatAd(bidderPlacementId, winningBid, adRequest, auctionBidListener)
            @unknown default:
                auctionBidListener.onError(error: "Failed to load liftoff ad: unknown ad format: \(adFormat)")
            }
        }
    }
    
    private func loadInterstitialAd(_ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?, _ auctionBidListener: AuctionBidListener) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)
        guard let placementReferenceId = placementReferenceId else {
            auctionBidListener.onError(error: "Failed to load liftoff interstitial ad: placementReferenceId is nil")
            return
        }
        
        let interstitialAdItem = VungleInterstitial(placementId: placementReferenceId)
        
        interstitialAdItem.delegate = self
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load liftoff interstitial ad: adm is nil")
            return
        }
        
        interstitialAdItem.load(adm)
    }
    
    private func loadNativeAd(_ placementId: String, _ winningBid: Bid, _ auctionBidListener: AuctionBidListener) {
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)
        
        guard let placementReferenceId = placementReferenceId else {
            auctionBidListener.onError(error: "Failed to load liftoff native ad: placementReferenceId is nil")
            return
        }
        
        let nativeAdItem = VungleNative(placementId: placementReferenceId)
        
        nativeAdItem.delegate = self
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load liftoff native ad: adm is nil")
            return
        }
                
        nativeAdItem.load(adm)
    }
    
    private func loadBannerAd(_ placementId: String, _ winningBid: Bid, _ adRequest: MSPiOSCore.AdRequest, _ auctionBidListener: AuctionBidListener) {
        
        let placementReferenceId = getPlacementReferenceId(winner: winningBid)
        
        guard let placementReferenceId = placementReferenceId else {
            auctionBidListener.onError(error: "Failed to load liftoff banner ad: placementReferenceId is nil")
            return
        }
        
        let bannerSize: VungleAdSize? = adRequest.adSize.flatMap {
            switch ($0.width, $0.height) {
            case (320, 50):  return VungleAdSize.VungleAdSizeBannerRegular
            case (300, 250): return VungleAdSize.VungleAdSizeMREC
            case (728, 90):  return VungleAdSize.VungleAdSizeLeaderboard
            case (300, 50):  return VungleAdSize.VungleAdSizeBannerShort
            default: return VungleAdSize.VungleAdSizeFromCGSize(CGSize(width: $0.width, height: $0.height))
            }
        }
        
        guard let bannerSize = bannerSize else {
            auctionBidListener.onError(error: "Failed to load liftoff banner ad: invalid ad size")
            return
        }
        
        self.bannerView = VungleBannerView(placementId: placementReferenceId, vungleAdSize: bannerSize)
        
        self.bannerView?.delegate = self
        self.bannerView?.translatesAutoresizingMaskIntoConstraints = false
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load liftoff banner ad: adm is nil")
            return
        }
        
        self.bannerView?.load(adm)
    }
    
    private func loadMultiformatAd(_ placementId: String, _ winningBid: Bid, _ adRequest: MSPiOSCore.AdRequest, _ auctionBidListener: any MSPiOSCore.AuctionBidListener) {
        if let type = winningBid.bid.ext.prebid?.type {
            switch type {
            case "native":
                self.loadNativeAd(placementId, winningBid, auctionBidListener)
            case "banner":
                self.loadBannerAd(placementId, winningBid, adRequest, auctionBidListener)
            default:
                auctionBidListener.onError(error: "Failed to load liftoff ad: unsupported ad type: \(type)")
            }
        } else {
            auctionBidListener.onError(error: "Failed to load liftoff ad: prebid type is nil")
        }
    }
    
    private func getPlacementReferenceId(winner: Bid) -> String? {
        let ext = winner.bid.rawJsonDictionary?["ext"] as? NSDictionary
        let vungle = ext?["vungle"] as? NSDictionary
        let placementReferenceId = vungle?["placement_reference_id"] as? String
        return placementReferenceId
    }
    
    public func destroyAd() {
        interstitialAd?.interstitialAdItem?.delegate = nil
        interstitialAd?.interstitialAdItem = nil
        
        interstitialAd?.destroy()
        interstitialAd = nil
        
        if let bannerView = bannerAd?.adView as? VungleBannerView {
            bannerView.delegate = nil
        }
        
        bannerView?.removeFromSuperview()
        bannerView?.delegate = nil 
        bannerView = nil
        bannerAd?.destroy()
        bannerAd = nil
        
        nativeAd?.nativeAdItem?.unregisterView()
        nativeAd?.nativeAdItem?.delegate = nil
        nativeAd?.nativeAdItem = nil
        
        nativeAd?.destroy()
        nativeAd = nil 
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAd?.nativeAdItem else { return }
        
        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
            
            // Get media view from native ad
            if let iconImage = nativeAdItem.iconImage {
                nativeAdContainer.getIcon()?.image = iconImage
            }
            
            
            // Create a MediaView for the native ad
            let mediaView = MediaView()
            if let mediaContainer = nativeAdContainer.getMedia() {
                mediaContainer.addSubview(mediaView)
                mediaView.snp.makeConstraints { make in
                    make.edges.equalTo(mediaContainer)
                }
            }
            
            let nilableClickableViews = [
                nativeAdContainer.getTitle(),
                nativeAdContainer.getbody(),
                nativeAdContainer.getMedia(),
                nativeAdContainer.getAdvertiser(),
                nativeAdContainer.getCallToAction(),
                nativeAdContainer.getIcon()
            ] + (nativeAdContainer.getCustomClickableViews() ?? [])
            nativeAdItem.registerViewForInteraction(
                view: nativeAdView,
                mediaView: mediaView,
                iconImageView: nativeAdContainer.getIcon(),
                viewController: adListener?.getRootViewController(),
                clickableViews: nilableClickableViews.compactMap { $0 }
            )

            nativeAdView.addSubview(nativeAdContainer)
            nativeAdContainer.snp.makeConstraints{ make in
                make.edges.equalTo(nativeAdView)
                make.width.lessThanOrEqualTo(nativeAdView)
                make.height.lessThanOrEqualTo(nativeAdView)
            }
        }
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .liftoff
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = (self.bannerAd ?? self.nativeAd) ?? self.interstitialAd {
            self.adMetricReporter?.logAdHide(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = (self.bannerAd ?? self.nativeAd) ?? self.interstitialAd {
            self.adMetricReporter?.logAdReport(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func getSDKVersion() -> String {
        return VungleAds.sdkVersion
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "liftoff", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }
    
    private func getMSPAd(ad: Any) -> MSPAd? {
        return switch ad {
        case is VungleInterstitial:
            self.interstitialAd
        case is VungleBannerView:
            self.bannerAd
        case is VungleNative:
            self.nativeAd
        default:
            nil
        }
    }
}

// MARK: - VungleInterstitialDelegate
extension LiftoffAdapter: VungleInterstitialDelegate {
    
    public func interstitialAdDidLoad(_ interstitial: VungleInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff interstitial ad")
                
                let interstitialAd = LiftoffInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = interstitial
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                
                self.performHandleAdLoaded(
                    mspAd: interstitialAd,
                    creativeId: interstitial.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }
    
    public func interstitialAdDidFailToLoad(_ interstitial: VungleInterstitial, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to load Liftoff interstitial ad: \(withError.localizedDescription)")
            
            self.auctionBidListener?.onError(error: "fail to load interstitial ad: \(withError.localizedDescription)")
            
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )
            
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }
    
    public func interstitialAdDidTrackImpression(_ interstitial: VungleInterstitial) {
        handleAdImpressed(interstitial)
    }
    
    public func interstitialAdDidFailToPresent(_ interstitial: VungleInterstitial, withError: NSError) {
        MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to present Liftoff interstitial ad: \(withError.localizedDescription)")
    }
    
    public func interstitialAdDidClose(_ interstitial: VungleInterstitial) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
    
    public func interstitialAdDidClick(_ interstitial: VungleInterstitial) {
        handleAdClicked(interstitial)
    }
    
    private func handleAdImpressed(_ ad: Any) {
        let mspAd = getMSPAd(ad: ad)
        
        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Show Liftoff ad successfully")
            self.adListener?.onAdImpression(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                   let bidResponse = self.bidResponse {
                    self.adMetricReporter?.logAdImpression(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }
    
    private func handleAdClicked(_ ad: Any) {
        let mspAd = getMSPAd(ad: ad)
        
        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] liftoff ad clicked")
            self.adListener?.onAdClick(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                   let bidResponse = self.bidResponse {
                    self.adMetricReporter?.logAdClick(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }
    
    private func performHandleAdLoaded(mspAd: MSPAd, creativeId: String?, placementId: String, auctionBidListener: AuctionBidListener) {
        mspAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = "liftoff"
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
        if let creativeId = creativeId {
            mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = creativeId
        }
        
        self.handleAdLoaded(
            ad: mspAd,
            auctionBidListener: auctionBidListener,
            bidderPlacementId: self.bidderPlacementId ?? "liftoff"
        )
        
        self.adMetricReporter?.logAdResult(
            placementId: placementId,
            ad: mspAd,
            fill: true,
            isFromCache: false
        )
    }
}

// MARK: - VungleBannerViewDelegate
extension LiftoffAdapter: VungleBannerViewDelegate {
    
    public func bannerAdDidLoad(_ banner: VungleBannerView) {
        let item = DispatchWorkItem {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {

                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff banner ad")

                // IMPORTANT: VungleBannerView contains a WebView subview that gets removed when
                // removeFromSuperview() is called, resulting in no content being displayed.
                // Solution: Wrap VungleBannerView in a container view to prevent direct removal.
                let containerView = UIView()
                containerView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(banner)
                banner.snp.makeConstraints { make in
                    make.edges.equalTo(containerView)
                }

                let bannerAd = BannerAd(adView: containerView, adNetworkAdapter: self)
                self.bannerAd = bannerAd

                self.performHandleAdLoaded(
                    mspAd: bannerAd,
                    creativeId: banner.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }

        DispatchQueue.main.async(execute: item)
    }
    
    public func bannerAdDidFail(_ banner: VungleBannerView, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to load Liftoff banner ad: \(withError.localizedDescription)")
            
            self.auctionBidListener?.onError(error: "fail to load banner ad: \(withError.localizedDescription)")
            
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )
            
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }
    
    public func bannerAdDidFailToPresent(_ banner: VungleBannerView, withError: NSError) {
        MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to present Liftoff banner ad: \(withError.localizedDescription)")
    }
    
    public func bannerAdDidClick(_ banner: VungleBannerView) {
        handleAdClicked(banner)
    }
    
    public func bannerAdDidTrackImpression(_ bannerView: VungleBannerView) {
        handleAdImpressed(bannerView)
    }
}

// MARK: - VungleNativeDelegate
extension LiftoffAdapter: VungleNativeDelegate {
    
    public func nativeAdDidLoad(_ native: VungleNative) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                MSPLogger.shared.info(message: "[Adapter: Liftoff] successfully loaded Liftoff native ad")
                
                let builder = NativeAd.Builder(adNetworkAdapter: self)
                    .title(native.title)
                    .body(native.bodyText)
                    .advertiser(native.sponsoredText)
                    .callToAction(native.callToAction)
                    .icon(native.iconImage as Any)
                
                let nativeAd = LiftoffNativeAd(adNetworkAdapter: self, builder: builder)
                
                nativeAd.nativeAdItem = native
                self.nativeAd = nativeAd
                
                self.performHandleAdLoaded(
                    mspAd: nativeAd,
                    creativeId: native.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }
    
    public func nativeAdDidFailToLoad(_ native: VungleNative, withError: NSError) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to load Liftoff native ad: \(withError.localizedDescription)")
            
            self.auctionBidListener?.onError(error: "fail to load native ad: \(withError.localizedDescription)")
            
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "",
                ad: nil,
                fill: false,
                isFromCache: false
            )
            
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil,
                    adRequest: adRequest,
                    errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: withError.localizedDescription
                )
            }
        }
    }
    
    public func nativeAdDidFailToPresent(_ native: VungleNative, withError: NSError) {
        MSPLogger.shared.info(message: "[Adapter: Liftoff] Fail to present Liftoff native ad: \(withError.localizedDescription)")
    }
    
    public func nativeAdDidTrackImpression(_ native: VungleNative) {
        handleAdImpressed(native)
    }
    
    public func nativeAdDidClick(_ native: VungleNative) {
        handleAdClicked(native)
    }
}
