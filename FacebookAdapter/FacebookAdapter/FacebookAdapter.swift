
//import shared
import MSPiOSCore
import FBAudienceNetwork
import AppTrackingTransparency
import PrebidMobile

import Foundation

@objc public class FacebookAdapter : NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        return "6.15.0"
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
              let mediaView = nativeAd.mediaView as? FBMediaView,
              let fbNativeAdItem = self.nativeAdItem else {return}
        //let fbNativeAdView = UIView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        if let nativeAdViewBinder = nativeAdView.nativeAdViewBinder {
            let fbSubViews = [nativeAdView.nativeAdViewBinder?.titleLabel, nativeAdView.nativeAdViewBinder?.bodyLabel, nativeAdView.nativeAdViewBinder?.advertiserLabel, nativeAdView.nativeAdViewBinder?.callToActionButton, mediaView]
            for view in fbSubViews {
                if let view = view {
                    nativeAdView.addSubview(view)
                }
            }
            nativeAdView.nativeAdViewBinder?.setUpViews(parentView: nativeAdView)
            
            fbNativeAdItem.registerView(forInteraction: nativeAdView,
                                        mediaView: mediaView,
                                        iconImageView: nil,
                                        viewController: nil,
                                        clickableViews: fbSubViews.compactMap{ $0 })
        } else if let nativeAdContainer = nativeAdView.nativeAdContainer {
            
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
            
            nativeAdView.addSubview(nativeAdContainer)
            
            if let mediaContainer = nativeAdContainer.getMedia() {
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor)
                ])
            }
            
            if let iconView = nativeAdContainer.getIcon(),
               let image = fbNativeAdItem.iconImage {
                //gadNativeAdView.iconView = iconView
                iconView.image = image
            }
            
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
            ])
            
            let fbSubViews = [nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getAdvertiser(), nativeAdContainer.getCallToAction(), nativeAdContainer.getIcon(), mediaView]
            fbNativeAdItem.registerView(forInteraction: nativeAdView,
                                        mediaView: mediaView,
                                        iconImageView: nativeAdContainer.getIcon(),
                                        viewController: nil,
                                        clickableViews: fbSubViews.compactMap{ $0 })
        }
        
        let fbAdOptionsView = FBAdOptionsView(frame: .zero)
        fbAdOptionsView.backgroundColor = .clear
        fbAdOptionsView.translatesAutoresizingMaskIntoConstraints = false

        nativeAdView.addSubview(fbAdOptionsView)
        NSLayoutConstraint.activate([
            fbAdOptionsView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            fbAdOptionsView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            fbAdOptionsView.widthAnchor.constraint(equalToConstant: FBAdOptionsViewWidth),
            fbAdOptionsView.heightAnchor.constraint(equalToConstant: FBAdOptionsViewHeight)
        ])
        fbAdOptionsView.nativeAd = fbNativeAdItem
    }
    
    public weak var adListener: AdListener?
    public var priceInDollar: Double?
    
    private var nativeAdItem: FBNativeAd?
    private weak var facebookNativeAd: FacebookNativeAd?
    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?
    
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    
    private weak var facebookInterstitialAd: FacebookInterstitialAd?
    private var interstitialAdItem: FBInterstitialAd?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        FBAdSettings.setAdvertiserTrackingEnabled(isIDFAAuthorized())
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: {_ in
            adapterInitListener.onComplete(adNetwork: .facebook, adapterInitStatus: .SUCCESS, message: "")
        })
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any, adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {
        self.adListener = adListener
        self.adRequest = adRequest
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        
        self.bidResponse = mBidResponse
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        
        switch adType {
        case "native":
            guard let placementId = self.getFBPlacementId(from: adString) else {
                self.adListener?.onError(msg: "Missing FB payload or placementId")
                return
            }
            nativeAdItem = FBNativeAd(placementID: placementId)
            nativeAdItem?.delegate = self

            DispatchQueue.main.async {
                self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                self.nativeAdItem?.loadAd(withBidPayload: adString)
            }
        case "banner":
            if adRequest.adFormat == .interstitial {
                guard let placementId = self.getFBPlacementId(from: adString) else {
                    self.adListener?.onError(msg: "Missing FB payload or placementId")
                    return
                }
                let facebookInterstitialAdItem = FBInterstitialAd(placementID: placementId)
                self.interstitialAdItem = facebookInterstitialAdItem
                facebookInterstitialAdItem.delegate = self
                DispatchQueue.main.async {
                    self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
                    facebookInterstitialAdItem.load(withBidPayload: adString)
                }
                
            }
        default:
            self.adListener?.onError(msg: "unknown adType")
        }
    }
    
    public func loadTestAdCreative() {
        nativeAdItem = FBNativeAd(placementID: "placementId#IMG_16_9_LINK")
        nativeAdItem?.delegate = self
        
        self.nativeAdItem?.loadAd(withBidPayload: "placementId#IMG_16_9_LINK")
        
    }
    
    public func isIDFAAuthorized() -> Bool {
        if #available(iOS 14, *), case .authorized = ATTrackingManager.trackingAuthorizationStatus {
            return true
        } else {
            return false
        }
    }
    
    private func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
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
    
    private func getFBPlacementId(from payload: String) -> String? {
        guard let data = payload.data(using: .utf8) else {
            self.adListener?.onError(msg: "Failed to get data from FB payload")
            return nil
        }

        do {
            guard let dict = SafeAs(try JSONSerialization.jsonObject(with: data), [String: Any].self) else {
                self.adListener?.onError(msg: "Failed to convert FB payload to json dict")
                return nil
            }
            return SafeAs(dict["resolved_placement_id"], String.self)
        } catch {
            self.adListener?.onError(msg: "Failed to json serialize FB payload, error = \(error.localizedDescription)")
            return nil
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
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .facebook
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?)
    {
        if let adRequest = self.adRequest,
           let ad = self.facebookNativeAd ?? self.facebookInterstitialAd {
            self.adMetricReporter?.logAdHide(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = self.facebookNativeAd ?? self.facebookInterstitialAd {
            self.adMetricReporter?.logAdReport(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    private func sendClickAdEvent(ad: MSPAd) {
        if let adRequest = adRequest,
           let bidResponse = bidResponse {
            self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
        }
    }
}


extension FacebookAdapter: FBNativeAdDelegate {
    public func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
        MSPLogger.shared.info(message: "[Adapter: Facebook] successfully loaded Facebook Native ad")
        DispatchQueue.main.async {
            let mediaView = FBMediaView(frame: .zero)
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            
            let facebookNativeAd = FacebookNativeAd(adNetworkAdapter: self,
                                                    title: nativeAd.headline ?? "",
                                                    body: nativeAd.bodyText ?? "",
                                                    advertiser: nativeAd.advertiserName ?? "",
                                                    callToAction:nativeAd.callToAction ?? "")
            self.facebookNativeAd = facebookNativeAd
            facebookNativeAd.priceInDollar = self.priceInDollar
            facebookNativeAd.nativeAdItem = nativeAd
            facebookNativeAd.mediaView = mediaView
            facebookNativeAd.icon = nativeAd.iconImage
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.facebook.rawValue
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = nativeAd.placementID
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            self.nativeAdItem = nativeAd
            if let adListener = self.adListener,
               let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                //handleAdLoaded(ad: facebookNativeAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(ad: facebookNativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
            }
        }
    }
    
    public func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Facebook] Fail to load Facebook Native ad")
        self.adListener?.onError(msg: error.localizedDescription)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: error.localizedDescription)
        }
    }
    
    public func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
        if let facebookNativeAd = self.facebookNativeAd {
            self.adListener?.onAdImpression(ad: facebookNativeAd)
            
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: facebookNativeAd, adRequest: adRequest, bidResponse: bidResponse)
            }
        }
    }
    
    public func nativeAdDidClick(_ nativeAd: FBNativeAd) {
        if let facebookNativeAd = self.facebookNativeAd {
            self.adListener?.onAdClick(ad: facebookNativeAd)
            self.sendClickAdEvent(ad: facebookNativeAd)
        }
    }
}

extension FacebookAdapter: FBInterstitialAdDelegate {
    public func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Facebook] successfully loaded Facebook Interstitial ad")
            var facebookInterstitialAd = FacebookInterstitialAd(adNetworkAdapter: self)
            facebookInterstitialAd.interstitialAdItem = interstitialAd
            interstitialAd.delegate = self
            self.interstitialAdItem = interstitialAd
            self.facebookInterstitialAd = facebookInterstitialAd
            if let priceInDollar = self.priceInDollar {
                facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.facebook.rawValue
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = interstitialAd.placementID
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            
            if let adListener = self.adListener,
               let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                //handleAdLoaded(ad: facebookInterstitialAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(ad: facebookInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: facebookInterstitialAd, fill: true, isFromCache: false)
            }
        }
    }
    
    public func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Facebook] Fail to load Facebook Interstitial ad")
        self.adListener?.onError(msg: error.localizedDescription)
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: error.localizedDescription)
        }
    }
    
    public func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        if let facebookInterstitialAd = self.facebookInterstitialAd {
            self.adListener?.onAdClick(ad: facebookInterstitialAd)
            self.sendClickAdEvent(ad: facebookInterstitialAd)
        }
    }
    
    public func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        if let facebookInterstitialAd = self.facebookInterstitialAd {
            self.adListener?.onAdDismissed(ad: facebookInterstitialAd)
        }
    }
    
    public func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
        if let facebookInterstitialAd = self.facebookInterstitialAd {
            self.adListener?.onAdImpression(ad: facebookInterstitialAd)
            
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: facebookInterstitialAd, adRequest: adRequest, bidResponse: bidResponse)
            }
        }
    }
}
