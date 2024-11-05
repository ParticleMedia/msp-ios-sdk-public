import PrebidMobile
import Foundation
//import shared
import MSPiOSCore
import UIKit

@objc public class PrebidAdapter : NSObject, AdNetworkAdapter {
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
    }
    
    // MARK: - BannerEventHandler
    public weak var loadingDelegate: BannerEventLoadingDelegate?
    public weak var interactionDelegate: BannerEventInteractionDelegate?
    public var adSizes: [CGSize] = []
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?) {
        do {
            try Prebid.shared.setCustomPrebidServer(url: initParams.getPrebidHostUrl())
            Prebid.shared.prebidServerAccountId = initParams.getPrebidAPIKey()
            Prebid.initializeSDK{ status, error in
                if status == .successed {
                    adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: "")
                } else {
                    adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: error?.localizedDescription ?? "")
                }
            }
        } catch {
            adapterInitListener.onComplete(adNetwork: .prebid, adapterInitStatus: .SUCCESS, message: "")
        }
    }
    
    public weak var adListener: AdListener?
    
    public var bannerView: BannerView?
    public var priceInDollar: Double?
    
    private var adRequest: AdRequest?
    private var bannerAd: BannerAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            return
        }
        self.adRequest = adRequest
        
        let width = Int(adRequest.adSize?.width ?? 320)
        let height = Int(adRequest.adSize?.height ?? 50)
        let adSize = CGSize(width: width, height: height)
         
        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)

        DispatchQueue.main.async {
            
            var bannerView = BannerView(frame: CGRect(origin: .zero, size: adSize),
                                        configID: adRequest.placementId,
                                        adSize: adSize,
                                        eventHandler: self)
            self.bannerView = bannerView
            
            bannerView.delegate = self
            bannerView.refreshInterval = 0
            self.adListener = adListener
            bannerView.handleBidResponse(response: mBidResponse)
        }
   }
    
}

extension PrebidAdapter: BannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController? {
        return self.adListener?.getRootViewController()
    }
    
    @objc public func bannerViewDidReceiveBidResponse(_ bannerView: BannerView) {
        self.bannerView?.loadAdContent()
    }
    
    @objc public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        var prebidAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
        self.bannerAd = prebidAd
        if let priceInDollar = self.priceInDollar {
            prebidAd.adInfo["priceInDollar"] = priceInDollar
        }
        
        if let adListener = self.adListener,
           let adRequest = self.adRequest {
            handleAdLoaded(ad: prebidAd, listener: adListener, adRequest: adRequest)
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: prebidAd, fill: true, isFromCache: false)
        }
    }
    
    @objc public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        adListener?.onError(msg: error.localizedDescription)
        adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
    }
    
    @objc public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        if let prebidAd = self.bannerAd {
            adListener?.onAdClick(ad: prebidAd)
        }
    }
    
    @objc public func bannerViewDidDismissModal(_ bannerView: BannerView) {
        if let prebidAd = self.bannerAd {
            adListener?.onAdClick(ad: prebidAd)
        }
    }
}

extension PrebidAdapter: BannerEventHandler {
    
    public func requestAd(with bidResponse: BidResponse?) {
        loadingDelegate?.prebidDidWin()
    }

    public func trackImpression() {
        if let prebidAd = self.bannerAd {
            adListener?.onAdImpression(ad: prebidAd)
            self.adMetricReporter?.logAdImpression(ad: prebidAd)
        }
    }
}
