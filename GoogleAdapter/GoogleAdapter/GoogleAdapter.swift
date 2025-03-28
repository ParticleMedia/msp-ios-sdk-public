import Foundation
import GoogleMobileAds
import MSPiOSCore
//import shared
import PrebidMobile

@objc public class GoogleAdapter : NSObject, AdNetworkAdapter {
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? MSPiOSCore.NativeAdView,
              let gadNativeAdItem = self.nativeAdItem else {return}
        let gadNativeAdView = GoogleMobileAds.NativeAdView()
        gadNativeAdView.translatesAutoresizingMaskIntoConstraints = false
        gadNativeAdView.nativeAd = gadNativeAdItem
        
        if let nativeAdViewBinder = nativeAdView.nativeAdViewBinder {
            gadNativeAdView.headlineView = nativeAdView.nativeAdViewBinder?.titleLabel
            gadNativeAdView.bodyView = nativeAdView.nativeAdViewBinder?.bodyLabel
            gadNativeAdView.advertiserView = nativeAdView.nativeAdViewBinder?.advertiserLabel
            gadNativeAdView.callToActionView = nativeAdView.nativeAdViewBinder?.callToActionButton
            gadNativeAdView.mediaView = nativeAdView.nativeAdViewBinder?.mediaView as? GoogleMobileAds.MediaView
            
            let gadSubViews = [gadNativeAdView.headlineView, gadNativeAdView.bodyView, gadNativeAdView.advertiserView, gadNativeAdView.callToActionView, gadNativeAdView.mediaView]
            for view in gadSubViews {
                if let view = view {
                    gadNativeAdView.addSubview(view)
                }
            }
            nativeAdView.nativeAdViewBinder?.setUpViews(parentView: gadNativeAdView)
        } else if let nativeAdContainer = nativeAdView.nativeAdContainer {
            
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
            
            gadNativeAdView.headlineView = nativeAdContainer.getTitle()
            gadNativeAdView.bodyView = nativeAdContainer.getbody()
            gadNativeAdView.advertiserView = nativeAdContainer.getAdvertiser()
            gadNativeAdView.callToActionView = nativeAdContainer.getCallToAction()
            
            if let mediaContainer = nativeAdContainer.getMedia(),
               let mediaView =  nativeAd.mediaView as? GoogleMobileAds.MediaView {
                gadNativeAdView.mediaView = mediaView
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                ])
            }
            
            gadNativeAdView.addSubview(nativeAdContainer)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: gadNativeAdView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: gadNativeAdView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: gadNativeAdView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: gadNativeAdView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: gadNativeAdView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: gadNativeAdView.heightAnchor),
            ])
            
        }
        
        nativeAdView.addSubview(gadNativeAdView)
        NSLayoutConstraint.activate([
            //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            gadNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            gadNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            gadNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            gadNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            gadNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
            gadNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
        ])
    }
    
    public func destroyAd() {
        
    }
    
    @objc public static func initializeGAD() {
        MobileAds.shared.start()
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?) {
        MobileAds.shared.start(completionHandler: {_ in
            adapterInitListener.onComplete(adNetwork: .google, adapterInitStatus: .SUCCESS, message: "")
        })
    }
    
    public var gadBannerView: AdManagerBannerView?
    public weak var adListener: AdListener?
    public var priceInDollar: Double?
    
    private var adLoader: GoogleMobileAds.AdLoader?
    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?
    
    private var bannerAd: BannerAd?
    private var nativeAd: MSPiOSCore.NativeAd?
    private var interstitialAd: MSPiOSCore.InterstitialAd?
    
    public var nativeAdItem: GoogleMobileAds.NativeAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        
        self.adRequest = adRequest
        
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            return
        }
        
        self.adListener = adListener
        self.bidResponse = mBidResponse
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let googleExtDict = SafeAs(bidExtDict["google"], [String: Any].self),
              let adUnitId = SafeAs(googleExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            return
        }
        
        switch adType {
        case "banner":
            if adRequest.adFormat == .interstitial {
                let request = AdManagerRequest()
                request.adString = adString
                
                GoogleMobileAds.InterstitialAd.load(with: adUnitId, request: request) { [weak self] ad, error in
                    guard let self else { return }

                    if let error {
                        self.adListener?.onError(msg: error.localizedDescription)
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                        return
                    }

                    guard let ad else {
                        self.adListener?.onError(msg: "Missing ad")
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                        return
                    }

                    DispatchQueue.main.async {
                        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                        var googleInterstitialAd = GoogleInterstitialAd(adNetworkAdapter: self)
                        googleInterstitialAd.interstitialAdItem = ad
                        ad.fullScreenContentDelegate = self
                        googleInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                        self.interstitialAd = googleInterstitialAd
                        googleInterstitialAd.adInfo["price"] = self.priceInDollar
                        if let adListener = self.adListener,
                           let adRequest = self.adRequest {
                            handleAdLoaded(ad: googleInterstitialAd, listener: adListener, adRequest: adRequest)
                            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: googleInterstitialAd, fill: true, isFromCache: false)
                        }
                    }
                }
                
            } else {
                DispatchQueue.main.async {
                    self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                    let gadBannerView = AdManagerBannerView(adSize: self.getGADAdSize(adRequest: adRequest))
                    self.gadBannerView = gadBannerView
                    gadBannerView.isAutoloadEnabled = false
                    let request = AdManagerRequest()
                    request.adString = adString
                    gadBannerView.adUnitID = adUnitId
                    gadBannerView.delegate = self
                    gadBannerView.rootViewController = self.adListener?.getRootViewController()
                    gadBannerView.load(request)
                }
            }

        case "native":
            DispatchQueue.main.async {
                self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                let adTypes: [AdLoaderAdType]
                if adRequest.adFormat == .native {
                    adTypes = [.native]
                } else {
                    adTypes = [.native, .adManagerBanner]
                }
                let videoOptions = VideoOptions()
                videoOptions.shouldStartMuted = true
                let adLoader = GoogleMobileAds.AdLoader(
                    adUnitID: adUnitId,
                    rootViewController: self.adListener?.getRootViewController(),
                    adTypes: adTypes,
                    options: [videoOptions])
                adLoader.delegate = self
                self.adLoader = adLoader
                let gamRequest = AdManagerRequest()
                gamRequest.adString = adString
                adLoader.load(gamRequest)
            }
            
        default:
            self.adListener?.onError(msg: "unknown adType")
        }
    }
    
    public func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }

    
    private func getGADAdSize(adRequest: AdRequest) -> GoogleMobileAds.AdSize {
        if let adaptiveBannerAdSize = adRequest.adaptiveBannerSize {
            if adaptiveBannerAdSize.isAnchorAdaptiveBanner {
                return currentOrientationAnchoredAdaptiveBanner(width: CGFloat(adaptiveBannerAdSize.width))
            } else if adaptiveBannerAdSize.isInlineAdaptiveBanner {
                return inlineAdaptiveBanner(width: CGFloat(adaptiveBannerAdSize.width), maxHeight: CGFloat(adaptiveBannerAdSize.height))
            }
        }
        if let width = adRequest.adSize?.width,
           let height = adRequest.adSize?.height {
            if width == 300, height == 250 {
                return AdSizeMediumRectangle
            }
        }
        return AdSizeBanner
    }
}

extension GoogleAdapter : GoogleMobileAds.BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo["price"] = priceInDollar
            }
            
            if let adListener = self.adListener,
               let adRequest = self.adRequest {
                handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }
    
    public func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
        self.adListener?.onError(msg: error.localizedDescription)
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
    }
    
    public func bannerViewDidRecordClick(_ bannerView: GoogleMobileAds.BannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdClick(ad: googleAd)
        }
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: GoogleMobileAds.BannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdImpression(ad: googleAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: googleAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }
}

extension GoogleAdapter: GoogleMobileAds.NativeAdLoaderDelegate {
    public func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        DispatchQueue.main.async {
            let mediaView = GoogleMobileAds.MediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            mediaView.contentMode = .scaleAspectFill
            mediaView.mediaContent = nativeAd.mediaContent
            
            let googleNativeAd = GoogleNativeAd(adNetworkAdapter: self,
                                                title: nativeAd.headline ?? "",
                                                body: nativeAd.body ?? "",
                                                advertiser: nativeAd.advertiser ?? "",
                                                callToAction:nativeAd.callToAction ?? "")
            
            googleNativeAd.nativeAdItem = nativeAd
            googleNativeAd.mediaView = mediaView
            googleNativeAd.priceInDollar = self.priceInDollar
            googleNativeAd.adInfo["price"] = self.priceInDollar
            nativeAd.delegate = self
            self.nativeAdItem = nativeAd
            self.nativeAd = googleNativeAd
            googleNativeAd.priceInDollar = self.priceInDollar
            if let adListener = self.adListener,
               let adRequest = self.adRequest {
                handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: googleNativeAd, fill: true, isFromCache: false)
            }
        }
    }
    
    public func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didFailToReceiveAdWithError error: any Error) {
        self.adListener?.onError(msg: error.localizedDescription)
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
    }
}

extension GoogleAdapter: GoogleMobileAds.NativeAdDelegate {

    public func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }

    public func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
        }
    }
}

extension GoogleAdapter: FullScreenContentDelegate {
    
    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdImpression(ad: interstitialAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }

    public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
        }
    }
    
    public func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }

}

extension GoogleAdapter: AdManagerBannerAdLoaderDelegate {
    public func validBannerSizes(for adLoader: GoogleMobileAds.AdLoader) -> [NSValue] {
        if let adRequest = adRequest {
            let adSize = self.getGADAdSize(adRequest: adRequest)
            return [nsValue(for: adSize)]
        }
        return [nsValue(for: AdSizeMediumRectangle)] //default size: 300 * 250
    }
    
    public func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didReceive bannerView: AdManagerBannerView) {
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo["price"] = priceInDollar
            }
            
            if let adListener = self.adListener,
               let adRequest = self.adRequest {
                handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }
}

                            
