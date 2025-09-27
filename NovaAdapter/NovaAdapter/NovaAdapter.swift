import Foundation
//import shared
import MSPiOSCore
import PrebidMobile
import NovaCore
import Kingfisher
import UIKit
import SnapKit

public class NovaAdapter: AdNetworkAdapter {
    public func getSDKVersion() -> String {
        return "0.0.112"
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    public weak var adListener: AdListener?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    public var priceInDollar: Double?
    public var adUnitId: String?
    
    public weak var nativeAd: MSPAd?
    public var nativeAdItem: NovaNativeAdItem?
    
    public weak var interstitialAd: InterstitialAd?
    
    public var nativeAdView: NativeAdView?
    
    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?
    
    private var adMetricReporter: AdMetricReporter?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        adapterInitListener.onComplete(adNetwork: .nova, adapterInitStatus: .SUCCESS, message: "")
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any, adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String:String]?) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
            return
        }
        DispatchQueue.main.async {
            self.adListener = adListener
            self.auctionBidListener = auctionBidListener
            self.bidderPlacementId = bidderPlacementId
            self.adRequest = adRequest
            self.bidResponse = mBidResponse
            
            guard let adString = mBidResponse.winningBid?.bid.adm,
                  let rawBidDict = self.SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
                  let bidExtDict = self.SafeAs(rawBidDict["ext"], [String: Any].self),
                  let novaExtDict = self.SafeAs(bidExtDict["nova"], [String: Any].self),
                  let adUnitId = self.SafeAs(novaExtDict["ad_unit_id"], String.self),
                  let prebidExtDict = self.SafeAs(bidExtDict["prebid"], [String: Any].self),
                  let adType = self.SafeAs(prebidExtDict["type"], String.self)
            else {
                self.adListener?.onError(msg: "no valid response")
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
                return
            }

            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
            
            self.adUnitId = adUnitId
            let eCPMInDollar = Decimal(self.priceInDollar ?? 0.0)
            let novaAdType: String
            if adRequest.adFormat == .interstitial {
                novaAdType = "interstitial"
            } else {
                novaAdType = "native"
            }
            self.parseNovaAdString(adString: adString, adType: novaAdType, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
        }
    }

    // TODO: lsy, 其实我感觉这种解析逻辑应该全部扔进 nova core 里面
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        // "video_use_control": default true, for immersive-video, video will not show controller if set to false
        let videoUseControl = adRequest?.customParams["video_use_control"] as? Bool ?? true
        // TODO: lsy, 我看了下调用，这个不是已经在主线程了吗
        DispatchQueue.main.async {
            guard let nativeAdView = nativeAdView as? NativeAdView,
                  let novaNativeAd = nativeAd as? NovaNativeAd,
                  let novaNativeAdItem = novaNativeAd.nativeAdItem
            else {
                self.adListener?.onError(msg: "fail to render native view")
                return
            }

            let novaNativeAdView = NovaNativeAdView()
            let originalVideoStyle = novaNativeAdItem.videoStyle
            let newVideoStyle: NovaAdVideoView.Style = videoUseControl ? .playButtonOnLeftBottom : .playButtonOnCenter(progressBarStyle: .hide)
            if originalVideoStyle != newVideoStyle {
                novaNativeAdItem.videoStyle = newVideoStyle
                novaNativeAd.nativeAdItem = novaNativeAdItem
            }
            
            if let nativeAdViewBinder = nativeAdView.nativeAdViewBinder {
                novaNativeAdView.titleLabel = nativeAdView.nativeAdViewBinder?.titleLabel
                novaNativeAdView.bodyLabel = nativeAdView.nativeAdViewBinder?.bodyLabel
                novaNativeAdView.advertiserLabel = nativeAdView.nativeAdViewBinder?.advertiserLabel
                novaNativeAdView.callToActionButton = nativeAdView.nativeAdViewBinder?.callToActionButton

                let clickableViews: [UIView] = [
                    novaNativeAdView.titleLabel,
                    novaNativeAdView.bodyLabel,
                    novaNativeAdView.advertiserLabel,
                    novaNativeAdView.callToActionButton,
                    novaNativeAdView.icon
                ].compactMap {
                    $0
                }
                novaNativeAdView.setupViews(with: novaNativeAdItem, clickableViews: clickableViews)

                nativeAdView.nativeAdViewBinder?.setUpViews(parentView: novaNativeAdView)
            } else if let nativeAdContainer = nativeAdView.nativeAdContainer {
                novaNativeAdView.titleLabel = nativeAdContainer.getTitle()
                novaNativeAdView.bodyLabel = nativeAdContainer.getbody()
                novaNativeAdView.advertiserLabel = nativeAdContainer.getAdvertiser()
                novaNativeAdView.callToActionButton = nativeAdContainer.getCallToAction()
                novaNativeAdView.icon = nativeAdContainer.getIcon()

                let clickableViews: [UIView] = [
                    novaNativeAdView.titleLabel,
                    novaNativeAdView.bodyLabel,
                    novaNativeAdView.advertiserLabel,
                    novaNativeAdView.callToActionButton,
                    novaNativeAdView.icon
                ].compactMap {
                    $0
                }
                novaNativeAdView.setupViews(with: novaNativeAdItem, clickableViews: clickableViews)

                if let mediaContainer = nativeAdContainer.getMedia() {
                    mediaContainer.addSubview(novaNativeAdView.mediaView)
                    novaNativeAdView.mediaView.snp.makeConstraints { make in
                        make.directionalEdges.equalToSuperview()
                    }
                }

                if let iconView = nativeAdContainer.getIcon(),
                   let imageUrlStr = novaNativeAdItem.iconUrlStr,
                   let url = URL(string: imageUrlStr) {
                    iconView.kf.setImage(with: url)
                }

                novaNativeAdView.addSubview(nativeAdContainer)
                nativeAdContainer.snp.makeConstraints { make in
                    make.directionalEdges.equalToSuperview()
                    make.size.equalToSuperview()
                }
            }
            
            nativeAdView.addSubview(novaNativeAdView)
            novaNativeAdView.snp.makeConstraints { make in
                make.directionalEdges.equalToSuperview()
                make.width.lessThanOrEqualToSuperview()
                make.height.lessThanOrEqualToSuperview()
            }
        }
    }
    
    func parseNovaAdString(adString: String, adType: String, adUnitId: String, eCPMInDollar: Decimal) {
        let data = adString.data(using: .utf8)
        guard let data = data else { return }

        do {
            let decodedData = try JSONDecoder().decode(NovaResponseDataModel.self, from: data)

            guard let ads = decodedData.ads,
                    !ads.isEmpty,
                    let adItem = ads.first else {
                self.adListener?.onError(msg: "no valid response")
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                return
            }

            switch adType {
            case "banner":
                return
                

            case "native":
                MSPLogger.shared.info(message: "[Adapter: Nova] successfully loaded Nova Native ad")
                let nativeAdItem = try NovaAdBuilder.buildNativeAd(
                    adItem: adItem,
                    adUnitId: adUnitId,
                    eCPMInDollar: eCPMInDollar,
                    abConfig: decodedData.abConfig
                )
                let nativeAd = NovaNativeAd(adNetworkAdapter: self,
                                            title: nativeAdItem.headline ?? "",
                                            body: nativeAdItem.body ?? "",
                                            advertiser: nativeAdItem.advertiser ?? "",
                                            callToAction:nativeAdItem.callToAction ?? "")
                DispatchQueue.main.async{
                    nativeAd.icon = nativeAdItem.iconUrlStr
                    nativeAd.priceInDollar = self.priceInDollar
                    nativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                    nativeAd.adInfo["isVideo"] = (nativeAdItem.creativeType == .nativeVideo)
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.nova.rawValue
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
                    nativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
                    nativeAd.nativeAdItem = nativeAdItem
                    self.nativeAdItem = nativeAdItem
                    self.nativeAd = nativeAd
                    nativeAdItem.delegate = self
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        self.handleAdLoaded(ad: nativeAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nativeAd, fill: true, isFromCache: false)
                    }
                }
                
            case "interstitial":
                MSPLogger.shared.info(message: "[Adapter: Nova] successfully loaded Nova Interstitial ad")
                let interstitialAdItems = NovaAdBuilder.buildInterstitialAds(
                    adItems: ads,
                    adUnitId: adUnitId,
                    abConfig: decodedData.abConfig
                )
                let interstitialAdItem = interstitialAdItems.first
                
                var novaInterstitialAd = NovaInterstitialAd(adNetworkAdapter: self)
                novaInterstitialAd.interstitialAdItem = interstitialAdItem
                //ad.fullScreenContentDelegate = self
                DispatchQueue.main.async {
                    novaInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                
                    self.interstitialAd = novaInterstitialAd
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.nova.rawValue
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.adUnitId
                    novaInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
                    interstitialAdItem?.delegate = self
                
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        if interstitialAdItem?.creativeType == .nativeImage {
                            // TODO: - GPY check with Huanzhi if preload is needed
                            self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: novaInterstitialAd, fill: true, isFromCache: false)
                        } else {
                            DispatchQueue.main.async {
                                self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                            }
                        }
                    }
                }
                
            default:
                MSPLogger.shared.info(message: "[Adapter: Nova] Fail to load Nova ad")
                let errorMessage = "unknown adType"
                self.adListener?.onError(msg: errorMessage)
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                if let adRequest = self.adRequest {
                    self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: errorMessage)
                }
            }
        } catch {
            MSPLogger.shared
                .info(message: "[Adapter: Nova] Fail to load Nova ad with error: \(error.localizedDescription)")
            let errorMessage = "error decode nova ad string"
            self.adListener?.onError(msg: errorMessage)
            self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: errorMessage)
            }
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
    
    public func loadTestAdCreative(adString: String, adListener: any AdListener, context: Any, adRequest: AdRequest) {
 
        self.adListener = adListener
        self.adRequest = adRequest

        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        let adType = adRequest.adFormat == .interstitial ? "interstitial" : "native"
        parseNovaAdString(adString: adString, adType: adType, adUnitId: "dummy_id", eCPMInDollar: eCPMInDollar)
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "msp", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .nova
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?)
    {
        if let adRequest = self.adRequest,
           let ad = self.nativeAd ?? self.interstitialAd {
            self.adMetricReporter?.logAdHide(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = self.nativeAd ?? self.interstitialAd {
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

extension NovaAdapter: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: bidResponse)
            }
        }
    }
    
    public func nativeAdDidLogClick(_ nativeAd: NovaCore.NovaNativeAdItem, clickAreaName: String) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
            self.sendClickAdEvent(ad: nativeAd)
        }
    }
    
    public func nativeAdDidFinishRender(_ nativeAd: NovaCore.NovaNativeAdItem) {
        
    }
    
    public func nativeAdRootViewController() -> UIViewController? {
        if Thread.isMainThread {
                return self.adListener?.getRootViewController()
        } else {
            return DispatchQueue.main.sync {
                self.adListener?.getRootViewController()
            }
        }
        //return self.adListener?.getRootViewController()
    }
}

extension NovaAdapter: NovaInterstitialAdDelegate {
    public func interstitialAdDidDismiss(_ interstitialAd: NovaCore.NovaInterstitialAdItem) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
    
    public func interstitialAdDidDisplay(_ interstitialAd: NovaCore.NovaInterstitialAdItem) {
        DispatchQueue.main.async {
            if let interstitialAd = self.interstitialAd {
                if let adRequest = self.adRequest,
                   let bidResponse = self.bidResponse {
                    self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse)
                }
                self.adListener?.onAdImpression(ad: interstitialAd)
            }
        }
    }
    
    public func interstitialAdDidLogClick(_ interstitialAd: NovaCore.NovaInterstitialAdItem) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
            self.sendClickAdEvent(ad: interstitialAd)
        }
    }
}

