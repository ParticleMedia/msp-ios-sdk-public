import PrebidMobile
import Foundation
//import shared
import MSPiOSCore
import UIKit

@objc public class PrebidAdapter : NSObject, AdNetworkAdapter {
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
    
    @objc public var rootViewController: UIViewController?
    public var adListener: AdListener?
    
    public var bannerView: BannerView?
    public var priceInDollar: Double?
    
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            return
        }
        if context is UIViewController {
            self.rootViewController = context as? UIViewController
        }
        guard let rootViewController else {
            adListener.onError(msg: "missing rootViewController")
            return
        }
        
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
    
    public func registerRootViewController(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
    }
}

extension PrebidAdapter: BannerViewDelegate {
    public func bannerViewPresentationController() -> UIViewController? {
        return rootViewController
    }
    
    @objc public func bannerViewDidReceiveBidResponse(_ bannerView: BannerView) {
        self.bannerView?.loadAdContent()
    }
    
    @objc public func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        var prebidAd = PrebidAd(adNetworkAdapter: self)
        prebidAd.adView = self.bannerView
        if let priceInDollar = self.priceInDollar {
            prebidAd.adInfo["priceInDollar"] = priceInDollar
            prebidAd.priceInDollar = priceInDollar
        }
        adListener?.onAdLoaded(ad: prebidAd)
    }
    
    @objc public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        adListener?.onError(msg: error.localizedDescription)
    }
    
    @objc public func bannerViewWillPresentModal(_ bannerView: BannerView) {
        var prebidAd = PrebidAd(adNetworkAdapter: self)
        prebidAd.adView = self.bannerView
        adListener?.onAdClick(ad: prebidAd)
    }
    
    @objc public func bannerViewDidDismissModal(_ bannerView: BannerView) {
        var prebidAd = PrebidAd(adNetworkAdapter: self)
        prebidAd.adView = self.bannerView
        adListener?.onAdClick(ad: prebidAd)
    }
}

public class PrebidAd: MSPAd {
    public var adView: UIView?
    public var priceInDollar: Double?
}

extension PrebidAdapter: BannerEventHandler {
    
    public func requestAd(with bidResponse: BidResponse?) {
        loadingDelegate?.prebidDidWin()
    }

    public func trackImpression() {
        var prebidAd = PrebidAd(adNetworkAdapter: self)
        prebidAd.adView = self.bannerView
        adListener?.onAdImpression(ad: prebidAd)
    }
}



        


 
