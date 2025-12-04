//
//  MolocoAdapter.swift
//  MolocoAdapter
//
//  Created by Mingming Luo on 2025/11/19.
//

import Foundation
import MolocoSDK
import MSPiOSCore
import UIKit
import PrebidMobile
import SnapKit

fileprivate typealias BannerCreator = (MolocoSDK.MolocoCreateAdParams, UIViewController) -> MolocoSDK.MolocoBannerAdView?

@objc public class MolocoAdapter: NSObject, AdNetworkAdapter {
    
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    public weak var bannerAd: BannerAd?
    public var bannerView: MolocoBannerAdView?

    private var interstitialAdItem: MolocoInterstitial?
    public weak var interstitialAd: MolocoInterstitialAd?

    private var nativeAdItem: MolocoNativeAd?
    public weak var nativeAd: MoNativeAd?

    public var nativeAdView: NativeAdView?

    private var adMetricReporter: AdMetricReporter?
    
    private var priceInDollar: Double?
    
    private var bidResponse: BidResponse?
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        let molocoInitKey = MSPiOSCore.InitializationParametersCustomKeys.MOLOCO_APP_KEY
        let appKey = initParams.getParameters()?[molocoInitKey] as? String ?? ""
        let molocoInitParams = MolocoInitParams.init(appKey: appKey, mediation: "")
        Moloco.shared.initialize(params: molocoInitParams) { success, error in
            if success {
                MSPLogger.shared.info(message: "[Adapter: Moloco] Moloco SDK initialization successful")
            } else if let error = error {
                MSPLogger.shared.info(message: "[Adapter: Moloco] Moloco SDK initialization failed with error: \(error.localizedDescription)")
            }
            adapterInitListener.onComplete(adNetwork: .moloco, adapterInitStatus: .SUCCESS, message: "")
        }
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String : String]?) {
        DispatchQueue.main.async {
            guard bidResponse is BidResponse,
                  let mBidResponse = bidResponse as? BidResponse else {
                auctionBidListener.onError(error: "Failed to load Moloco ad: invalid bidResponse")
                return
            }
            
            self.auctionBidListener = auctionBidListener
            self.adListener = adListener
            self.adRequest = adRequest
            self.bidderPlacementId = bidderPlacementId
            self.bidResponse = mBidResponse

            let rootViewController = adListener.getRootViewController()
            
            guard let bidResponse = bidResponse as? BidResponse,
                  let winningBid = bidResponse.winningBid else {
                auctionBidListener.onError(error: "Failed to load Moloco ad: no winning bid")
                return
            }
            
            let adFormat = bidderFormat ?? adRequest.adFormat
            
            MSPLogger.shared.info(message: "[Adapter: Moloco] Start to load Moloco creative ad. AdFormat = \(adFormat), placementId = \(bidderPlacementId)")
            
            switch adFormat {
            case .interstitial:
                self.loadInterstitialAd(bidderPlacementId, winningBid, rootViewController, auctionBidListener)
            case .native:
                self.loadNativeAd(bidderPlacementId, winningBid, auctionBidListener)
            case .banner:
                self.loadBannerAd(bidderPlacementId, winningBid, rootViewController, adRequest, auctionBidListener)
            case .multi_format:
                self.loadMultiformatAd(bidderPlacementId, winningBid, rootViewController, adRequest, auctionBidListener)
            @unknown default:
                auctionBidListener.onError(error: "Failed to load moloco ad: unknown ad format: \(adFormat)")
            }
        }
    }
    
    @MainActor
    private func loadInterstitialAd(_ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?, _ auctionBidListener: AuctionBidListener) {
        let adUnitId = getOriginalAdUnitId(winner: winningBid)
        guard let adUnitId = adUnitId else {
            auctionBidListener.onError(error: "Failed to load moloco interstitial ad: adUnitId is nil")
            return
        }
        
        self.interstitialAdItem = Moloco.shared.createInterstitial(params: .init(adUnit: adUnitId, mediation: ""))
        
        guard let interstitialAdItem = self.interstitialAdItem else {
            auctionBidListener.onError(error: "Failed to load moloco interstitial ad: invalid configuration")
            return
        }
        
        interstitialAdItem.interstitialDelegate = self
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load moloco interstitial ad: adm is nil")
            return
        }
        
        interstitialAdItem.load(bidResponse: adm)
    }
    
    @MainActor
    private func loadNativeAd(_ placementId: String, _ winningBid: Bid, _ auctionBidListener: AuctionBidListener) {
        let adUnitId = getOriginalAdUnitId(winner: winningBid)
        
        guard let adUnitId = adUnitId else {
            auctionBidListener.onError(error: "Failed to load moloco native ad: adUnitId is nil")
            return
        }
        
        self.nativeAdItem = Moloco.shared.createNativeAd(params: .init(adUnit: adUnitId, mediation: ""))
        
        guard let nativeAdItem = self.nativeAdItem else {
            auctionBidListener.onError(error: "Failed to load moloco native ad: invalid configuration")
            return
        }
        
        self.nativeAd?.nativeAdItem = nativeAdItem
        nativeAdItem.delegate = self
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load moloco native ad: adm is nil")
            return
        }
                
        nativeAdItem.load(bidResponse: adm)
    }
    
    @MainActor
    private func loadBannerAd(_ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?, _ adRequest: MSPiOSCore.AdRequest, _ auctionBidListener: AuctionBidListener) {
        guard let viewController = viewController else {
            auctionBidListener.onError(error: "Failed to load moloco banner ad: rootViewController is nil")
            return
        }
        
        let adUnitId = getOriginalAdUnitId(winner: winningBid)
        
        guard let adUnitId = adUnitId else {
            auctionBidListener.onError(error: "Failed to load moloco banner ad: adUnitId is nil")
            return
        }
        
        let bannerCreator: BannerCreator? = switch adRequest.adSize {
        case let it where it?.width == 320 && it?.height == 50:
            Moloco.shared.createBanner
        case let it where it?.width == 300 && it?.height == 250:
            Moloco.shared.createMREC
        default:
            nil
        }
        
        guard let bannerCreator = bannerCreator else {
            auctionBidListener.onError(error: "Failed to load moloco banner ad: invalid ad size")
            return
        }
        
        self.bannerView = bannerCreator(.init(adUnit: adUnitId, mediation: ""), viewController)
        
        guard let bannerView = bannerView else {
            auctionBidListener.onError(error: "Failed to load moloco banner ad: invalid configuration")
            return
        }
        
        bannerView.delegate = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        guard let adm = winningBid.adm else {
            auctionBidListener.onError(error: "Failed to load moloco banner ad: adm is nil")
            return
        }
        
        bannerView.load(bidResponse: adm)
    }
    
    @MainActor
    private func loadMultiformatAd(_ placementId: String, _ winningBid: Bid, _ viewController: UIViewController?, _ adRequest: MSPiOSCore.AdRequest, _ auctionBidListener: any MSPiOSCore.AuctionBidListener) {
        if let type = winningBid.bid.ext.prebid?.type {
            switch type {
            case "native":
                self.loadNativeAd(placementId, winningBid, auctionBidListener)
            case "banner":
                self.loadBannerAd(placementId, winningBid, viewController, adRequest, auctionBidListener)
            default:
                auctionBidListener.onError(error: "Failed to load moloco ad: unsupported ad type: \(type)")
            }
        } else {
            auctionBidListener.onError(error: "Failed to load moloco ad: prebid type is nil")
        }
    }
    
    private func getOriginalAdUnitId(winner: PrebidMobile.Bid) -> String? {
        let ext = winner.bid.rawJsonDictionary?["ext"] as? NSDictionary
        let moloco = ext?["moloco"] as? NSDictionary
        let adUnitId = moloco?["ad_unit_id"] as? String
        return adUnitId
    }
    
    public func destroyAd() {
        interstitialAdItem?.destroy()
        interstitialAdItem?.interstitialDelegate = nil
        interstitialAdItem = nil
        
        interstitialAd?.destroy()
        interstitialAd = nil
        
        bannerView?.destroy()
        bannerView?.delegate = nil
        bannerView = nil
        
        bannerAd?.destroy()
        bannerAd = nil
        
        nativeAdItem?.delegate = nil
        nativeAdItem = nil
        
        nativeAd?.destroy()
        nativeAd = nil 
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let nativeAdItem = self.nativeAdItem else {return}
        
        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.layoutIfNeeded()
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let assets = nativeAdItem.assets
            
            var mediaView = assets?.videoView
            if mediaView == nil && assets?.mainImage != nil {
                mediaView = UIImageView(image: assets?.mainImage)
            }
            
            nativeAdContainer.getIcon()?.image = assets?.appIcon

            if let mediaContainer = nativeAdContainer.getMedia(),
               let mediaView = mediaView {
                mediaContainer.addSubview(mediaView)
                mediaView.snp.makeConstraints{ make in
                    make.edges.equalTo(mediaContainer)
                }
            }

            for view in [nativeAdView, nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getMedia(), nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction()] {
                if let view = view {
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeAdClick))
                    view.addGestureRecognizer(tapGesture)
                }
            }

            nativeAdView.addSubview(nativeAdContainer)
            nativeAdContainer.snp.makeConstraints{ make in
                make.edges.equalTo(nativeAdView)
                make.width.lessThanOrEqualTo(nativeAdView)
                make.height.lessThanOrEqualTo(nativeAdView)
            }
        }
    }
    
    @objc private func handleNativeAdClick() {
        self.nativeAdItem?.handleClick()
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .moloco
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
        return Moloco.shared.sdkVersion
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "moloco", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }
}

extension MolocoAdapter: MolocoSDK.BaseAdDelegate {
    public func didLoad(ad: any MolocoSDK.MolocoAd) {
        if let price = ad.revenue {
            self.priceInDollar = price?.doubleValue
        }
        MSPLogger.shared.info(message: "[Adapter: Moloco] successfully loaded Moloco ad")
        switch ad {
        case let molocoNativeAd as MolocoNativeAd:
            didLoadNativeAd(molocoNativeAd)
        case let molocoInterstitialAd as MolocoInterstitial:
            didLoadInterstitialAd(molocoInterstitialAd)
        case let molocoBannerAd as MolocoBannerAdView:
            didLoadBannerAd(molocoBannerAd)
        default:
            MSPLogger.shared.info(message: "[Adapter: Moloco] unknown loaded moloco ad type")
        }
    }
    
    private func didLoadNativeAd(_ ad: MolocoNativeAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                MSPLogger.shared.info(message: "[Adapter: Moloco] successfully loaded Moloco native ad")
                
                let assets = ad.assets
                let builder = NativeAd.Builder(adNetworkAdapter: self)
                    .title(assets?.title ?? "")
                    .body(assets?.description ?? "")
                    .advertiser(assets?.sponsorText ?? "")
                    .callToAction(assets?.ctaTitle ?? "")
                    .icon(assets?.appIcon ?? "")
                    .mediaView(assets?.videoView ?? UIImageView(image: assets?.mainImage))
                
                let nativeAd = MoNativeAd(adNetworkAdapter: self, builder: builder)
                
                nativeAd.nativeAdItem = ad
                self.nativeAd = nativeAd
                
                self.performHandleAdLoaded(
                    mspAd: nativeAd,
                    creativeId: ad.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
                
                nativeAd.nativeAdItem?.handleImpression()
            }
        }
    }
    
    private func didLoadInterstitialAd(_ ad: MolocoInterstitial) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                MSPLogger.shared.info(message: "[Adapter: Moloco] successfully loaded Moloco interstitial ad")
                
                let interstitialAd = MolocoInterstitialAd(adNetworkAdapter: self)
                interstitialAd.interstitialAdItem = ad
                interstitialAd.rootViewController = self.adListener?.getRootViewController()
                self.interstitialAd = interstitialAd
                
                self.performHandleAdLoaded(
                    mspAd: interstitialAd,
                    creativeId: ad.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }
    
    private func didLoadBannerAd(_ ad: MolocoBannerAdView) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                
                guard let bannerAdView = self.bannerView else {
                    MSPLogger.shared.info(message: "[Adapter: Moloco] failed to load Moloco banner ad")
                    return
                }
                
                MSPLogger.shared.info(message: "[Adapter: Moloco] successfully loaded Moloco banner ad")
                
                let bannerAd = BannerAd(adView: bannerAdView, adNetworkAdapter: self)
                self.bannerAd = bannerAd
                
                self.performHandleAdLoaded(
                    mspAd: bannerAd,
                    creativeId: ad.creativeId,
                    placementId: adRequest.placementId,
                    auctionBidListener: auctionBidListener
                )
            }
        }
    }
    
    private func performHandleAdLoaded(mspAd: MSPAd, creativeId: NSString??, placementId: String, auctionBidListener: AuctionBidListener) {
        mspAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.moloco.rawValue
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
        if let creativeId = creativeId {
            mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = creativeId
        }
        
        self.handleAdLoaded(
            ad: mspAd,
            auctionBidListener: auctionBidListener,
            bidderPlacementId: self.bidderPlacementId ?? "moloco"
        )
        
        self.adMetricReporter?.logAdResult(
            placementId: placementId,
            ad: mspAd,
            fill: true,
            isFromCache: false
        )
    }
    
    public func failToLoad(ad: any MolocoSDK.MolocoAd, with error: (any Error)?) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Moloco] Fail to load Moloco ad")
            
            self.auctionBidListener?.onError(error: "fail to load ad")
            
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
                    errorMessage: error?.localizedDescription
                )
            }
        }
    }
    
    private func getMSPAd(ad: any MolocoSDK.MolocoAd) -> MSPAd? {
        let mspAd: MSPAd? = switch ad {
        case is MolocoNativeAd:
            self.nativeAd
        case is MolocoInterstitial:
            self.interstitialAd
        case is MolocoBannerAdView:
            self.bannerAd
        default:
            nil
        }
        return mspAd
    }
    
    public func didShow(ad: any MolocoSDK.MolocoAd) {
        handleAdImpressed(ad: ad)
    }
    
    private func handleAdImpressed(ad: any MolocoAd) {
        let mspAd = self.getMSPAd(ad: ad)
        
        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Moloco] Show Moloco ad successfully")
            self.adListener?.onAdImpression(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                   let bidResponse = self.bidResponse {
                    self.adMetricReporter?.logAdImpression(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }
    
    public func failToShow(ad: any MolocoSDK.MolocoAd, with error: (any Error)?) {
        
    }
    
    public func didHide(ad: any MolocoSDK.MolocoAd) {
        let mspAd = self.getMSPAd(ad: ad)
        
        if let interstitialAd = mspAd as? MolocoInterstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
    
    public func didClick(on ad: any MolocoSDK.MolocoAd) {
        handleAdClicked(ad: ad)
    }
    
    private func handleAdClicked(ad: any MolocoAd) {
        let mspAd = self.getMSPAd(ad: ad)
        
        if let mspAd = mspAd {
            MSPLogger.shared.info(message: "[Adapter: Moloco] moloco ad clicked")
            self.adListener?.onAdClick(ad: mspAd)
            DispatchQueue.main.async {
                if let adRequest = self.adRequest,
                   let bidResponse = self.bidResponse {
                    self.adMetricReporter?.logAdClick(ad: mspAd, adRequest: adRequest, bidResponse: bidResponse)
                }
            }
        }
    }
}

extension MolocoAdapter: MolocoNativeAdDelegate {
    public func didHandleClick(ad: any MolocoAd) {
        handleAdClicked(ad: ad)
    }
    
    public func didHandleImpression(ad: any MolocoAd) {
        handleAdImpressed(ad: ad)
    }
}

extension MolocoAdapter: MolocoInterstitialDelegate {
    
}

extension MolocoAdapter: MolocoBannerDelegate {
    
}
