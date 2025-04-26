import Foundation
//import shared
import MSPiOSCore
import PrebidMobile
import NovaCore
import UIKit

public class NovaAdapter: AdNetworkAdapter {
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
    public var novaNativeAdView: NovaNativeAdView?
    
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
 
        self.adListener = adListener
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        self.adRequest = adRequest
        self.bidResponse = mBidResponse
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let novaExtDict = SafeAs(bidExtDict["nova"], [String: Any].self),
              let adUnitId = SafeAs(novaExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: nil, fill: false, isFromCache: false)
            return
        }
        DispatchQueue.main.async {
            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        }
        self.adUnitId = adUnitId
        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        let novaAdType: String
        if adRequest.adFormat == .interstitial {
            novaAdType = "app_open"
        } else {
            novaAdType = "native"
        }
        parseNovaAdString(adString: testAdString, adType: novaAdType, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        let adOpenActionHandler = NovaAdOpenActionHandler(viewController: adListener?.getRootViewController())
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
        DispatchQueue.main.async {
            guard let nativeAdView = nativeAdView as? NativeAdView,
                  let mediaView = nativeAd.mediaView as? NovaNativeAdMediaView,
                  let novaNativeAdItem = self.nativeAdItem else {
                self.adListener?.onError(msg: "fail to render native view")
                return
            }
            let novaNativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster,
                                                    mediaView: mediaView)
            
            if let nativeAdViewBinder = nativeAdView.nativeAdViewBinder {
                novaNativeAdView.titleLabel = nativeAdView.nativeAdViewBinder?.titleLabel
                novaNativeAdView.bodyLabel = nativeAdView.nativeAdViewBinder?.bodyLabel
                novaNativeAdView.advertiserLabel = nativeAdView.nativeAdViewBinder?.advertiserLabel
                novaNativeAdView.callToActionButton = nativeAdView.nativeAdViewBinder?.callToActionButton
                novaNativeAdView.prepareViewForInteraction(nativeAd: novaNativeAdItem)
                
                let novaSubViews: [UIView?] = [novaNativeAdView.titleLabel, novaNativeAdView.bodyLabel, novaNativeAdView.advertiserLabel, novaNativeAdView.callToActionButton, mediaView]
                novaNativeAdView.tappableViews = [UIView]()
                for view in novaSubViews {
                    if let view = view {
                        novaNativeAdView.addSubview(view)
                        novaNativeAdView.tappableViews?.append(view)
                    }
                }
                novaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                nativeAdView.nativeAdViewBinder?.setUpViews(parentView: novaNativeAdView)
            } else if let nativeAdContainer = nativeAdView.nativeAdContainer {
                novaNativeAdView.titleLabel = nativeAdContainer.getTitle()
                novaNativeAdView.bodyLabel = nativeAdContainer.getbody()
                novaNativeAdView.advertiserLabel = nativeAdContainer.getAdvertiser()
                novaNativeAdView.callToActionButton = nativeAdContainer.getCallToAction()
                novaNativeAdView.prepareViewForInteraction(nativeAd: novaNativeAdItem)
                
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
                
                nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false
                
                novaNativeAdView.addSubview(nativeAdContainer)
                novaNativeAdView.tappableViews = [UIView]()
                novaNativeAdView.tappableViews?.append(mediaView)
                novaNativeAdView.tappableViews?.append(nativeAdContainer)
                if let button = novaNativeAdView.callToActionButton {
                    novaNativeAdView.tappableViews?.append(button)
                }
                novaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    nativeAdContainer.leadingAnchor.constraint(equalTo: novaNativeAdView.leadingAnchor),
                    nativeAdContainer.trailingAnchor.constraint(equalTo: novaNativeAdView.trailingAnchor),
                    nativeAdContainer.topAnchor.constraint(equalTo: novaNativeAdView.topAnchor),
                    nativeAdContainer.bottomAnchor.constraint(equalTo: novaNativeAdView.bottomAnchor),
                    nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: novaNativeAdView.widthAnchor),
                    nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: novaNativeAdView.heightAnchor),
                ])
            }
            
            nativeAdView.addSubview(novaNativeAdView)
            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                novaNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                novaNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                novaNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                novaNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                novaNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                novaNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
            ])
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
                let nativeAdItem = NovaAdBuilder.buildNativeAd(adItem: adItem, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
                let nativeAd = NovaNativeAd(adNetworkAdapter: self,
                                            title: nativeAdItem.headline ?? "",
                                            body: nativeAdItem.body ?? "",
                                            advertiser: nativeAdItem.advertiser ?? "",
                                            callToAction:nativeAdItem.callToAction ?? "")
                DispatchQueue.main.async{
                    let mediaView = {
                        let view = NovaNativeAdMediaView()
                        view.accessibilityIdentifier = "media"
                        view.translatesAutoresizingMaskIntoConstraints = false
                        return view
                    }()
                    nativeAd.mediaView = mediaView
                    nativeAd.priceInDollar = self.priceInDollar
                    nativeAd.adInfo["price"] = self.priceInDollar
                    nativeAd.adInfo["isVideo"] = (nativeAdItem.creativeType == .nativeVideo)
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
                
            case "app_open":
                MSPLogger.shared.info(message: "[Adapter: Nova] successfully loaded Nova Interstitial ad")
                let appOpenAds = NovaAdBuilder.buildAppOpenAds(adItems: ads, adUnitId: adUnitId)
                let appOpenAd = appOpenAds.first
                
                var novaInterstitialAd = NovaInterstitialAd(adNetworkAdapter: self)
                novaInterstitialAd.interstitialAdItem = appOpenAd
                //ad.fullScreenContentDelegate = self
                DispatchQueue.main.async {
                    novaInterstitialAd.rootViewController = self.adListener?.getRootViewController()
                
                    self.interstitialAd = novaInterstitialAd
                    novaInterstitialAd.adInfo["price"] = self.priceInDollar
                    appOpenAd?.delegate = self
                
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest,
                       let auctionBidListener = self.auctionBidListener {
                        if appOpenAd?.creativeType == .nativeImage {
                            appOpenAd?.preloadAdImage() { image in
                                DispatchQueue.main.async {
                                    if let image = image {
                                       
                                        self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: novaInterstitialAd, fill: true, isFromCache: false)
                                    } else {
                                        self.adListener?.onError(msg: "fail to load ad media")
                                        self.adMetricReporter?.logAdResult(placementId: adRequest.placementId ?? "", ad: nil, fill: false, isFromCache: false)
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.handleAdLoaded(ad: novaInterstitialAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId  ?? adRequest.placementId)
                            }
                        }
                    }
                }
                
            default:
                MSPLogger.shared.info(message: "[Adapter: Nova] Fail to load Nova ad")
                self.adListener?.onError(msg: "unknown adType")
                self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            }
        } catch {
            MSPLogger.shared.info(message: "[Adapter: Nova] Fail to load Nova ad")
            self.adListener?.onError(msg: "error decode nova ad string")
            self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
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
        let adType = adRequest.adFormat == .interstitial ? "app_open" : "native"
        parseNovaAdString(adString: adString, adType: adType, adUnitId: "dummy_id", eCPMInDollar: eCPMInDollar)
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "msp", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
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
}

extension NovaAdapter: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: nativeAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }
    
    public func nativeAdDidLogClick(_ nativeAd: NovaCore.NovaNativeAdItem, clickAreaName: String) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
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

extension NovaAdapter: NovaAppOpenAdDelegate {
    public func appOpenAdDidDismiss(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdDismissed(ad: interstitialAd)
        }
    }
    
    public func appOpenAdDidDisplay(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdImpression(ad: interstitialAd)
            if let adRequest = adRequest,
               let bidResponse = bidResponse {
                self.adMetricReporter?.logAdImpression(ad: interstitialAd, adRequest: adRequest, bidResponse: bidResponse, params: nil)
            }
        }
    }
    
    public func appOpenAdDidLogClick(_ appOpenAd: NovaCore.NovaAppOpenAd) {
        if let interstitialAd = self.interstitialAd {
            self.adListener?.onAdClick(ad: interstitialAd)
        }
    }
}


public let testAdString = """
{
"ad": [
{
  "creative": {
    "ctrUrl": "https://webuyhouses.housebuyernetwork.com/cash-offer/?utm_source=NEWSB&newsbreak_cid=nvss_16829F56A1F042EFBAA048A4A08C0183_1801672399553355778&sub_id_1=1801672386409779201&is_nova=true&utm_content=nvss_16829F56A1F042EFBAA048A4A08C0183_1801672399553355778&nb_cid=16829F56A1F042EFBAA048A4A08C0183_1801672399553355778",
    "headline": "Sell your Santa Clara house fast. In any condition. Get your cash offer today.",
    "body": "If you own a Santa Clara house that you want sold fast, we can help by giving you a FAIR offer",
    "callToAction": "Get started",
    "imageUrl": "https://img.particlenews.com/image.php?type=webp_1200x000&limit=40&url=https%3A%2F%2Fstatic.particlenews.com%2Fnova%2Fassets%2F1781396718885908481%2F0dfe4fd25d67ff7d8e1dd1d9fba7300040ed3a5f.png",
    "address": "",
    "creativeType": "IMAGE",
    "image": "",
    "thirdPartyImpressionTrackingUrls": [],
    "thirdPartyViewTrackingUrls": [],
    "thirdPartyClickTrackingUrls": [],
    "launchOption": "LAUNCH_WEBVIEW",
    "advertiser": "House Buyer Network",
    "adm": "",
    "carouselItems": [],
    "iconUrl": "https://static.particlenews.com/nova/assets/1781396718885908481/5fb577f408aa05afa4cc53dce1f7941dc0512298.png",
    "channelId": "",
    "isVerticalImage": false,
    "isImageClickable": true
  },
  "expirationMs": "1719020011378",
  "encryptedAdToken": "16829F56-A1F0-42EF-BAA0-48A4A08C0183.CjII7Yrg5YMyFYLYqMAaJDE2ODI5RjU2LUExRjAtNDJFRi1CQUEwLTQ4QTRBMDhDMDE4MxCB4PbJityy3BgYgaDXjNbvtIAZIIGg17Li77SAGSiBwIOAh/C0gBkwgsCDiIfwtIAZOgVDTElDS0CcSkgBUhVOQVRJVkVfRU5EX09GX0FSVElDTEVaJG5vdmEtaW9zLWFydGljbGUtaHVnZS1uYXRpdmUtcHJvZC1vYmq6Amh0dHBzOi8vd2VidXlob3VzZXMuaG91c2VidXllcm5ldHdvcmsuY29tL2Nhc2gtb2ZmZXIvP3V0bV9zb3VyY2U9TkVXU0ImbmV3c2JyZWFrX2NpZD1udnNzXzE2ODI5RjU2QTFGMDQyRUZCQUEwNDhBNEEwOEMwMTgzXzE4MDE2NzIzOTk1NTMzNTU3Nzgmc3ViX2lkXzE9MTgwMTY3MjM4NjQwOTc3OTIwMSZpc19ub3ZhPXRydWUmdXRtX2NvbnRlbnQ9bnZzc18xNjgyOUY1NkExRjA0MkVGQkFBMDQ4QTRBMDhDMDE4M18xODAxNjcyMzk5NTUzMzU1Nzc4Jm5iX2NpZD0xNjgyOUY1NkExRjA0MkVGQkFBMDQ4QTRBMDhDMDE4M18xODAxNjcyMzk5NTUzMzU1Nzc4cTPJluXET9A/kQEAAACgz3teP5kBAAAAQBtngz+gAaCcAagBqKqF6IEysAHy/s7sgzK6AQQIARAKwgEFREFJTFnKASQzQjA2QzQ3OC04NDNGLTQ4NDktQTYwMy0yRjZFOTkxQjY0N0PSAQ5NQVhfQ09OVkVSU0lPTtkB/II/MS9SYEDiAQhQUkVfUEFJROgBgeD2yYrcstwY8AH///////////8BiQIAAADgulpfP5ECAAAAYFbMgD+ZAjPJluXET9A/",
  "startTimeMs": "1718473545000",
  "requestId": "16829F56-A1F0-42EF-BAA0-48A4A08C0183",
  "adId": "1801672399553355778",
  "adsetId": "1801672389710696449",
  "price": 2.5486872120667954
}
],
"status": "success",
"code": 0,
"abConfig": {}
}
"""
public let testAdImmersiveString = """
{
"ad": [
{
  "creative": {
    "ctrUrl": "https://go.policyratecut.com/66425981dc881000015afc3b?sub1=1790795014683475970&sub2=Auto+1&sub3=1790797296852135937&sub4=AUTO2&sub5=1790802978053681154&sub6=ad2&sub7=ios&sub8=0&ref_id=nvss_8E24B110A57B410A86E2FE40E0C0C8CE_1790802978053681154&is_nova=true&utm_content=nvss_8E24B110A57B410A86E2FE40E0C0C8CE_1790802978053681154&nb_cid=8E24B110A57B410A86E2FE40E0C0C8CE_1790802978053681154",
    "headline": "CA Drivers Shocked! Pay 70% Less on Car Insurance With Secret Hack",
    "body": "I used to pay $193/mo, but Now I only pay $22/mo using this Car Insurance hack.",
    "callToAction": "Learn More",
    "imageUrl": "https://static.particlenews.com/nova/assets/1790058089464029185/99f569348e959a785611c7bbf927773e33a1ac91_trans.mp4/720_30_6mbps_h264.mp4",
    "address": "",
    "creativeType": "VIDEO",
    "image": "",
    "thirdPartyImpressionTrackingUrls": [],
    "thirdPartyViewTrackingUrls": [],
    "thirdPartyClickTrackingUrls": [],
    "launchOption": "LAUNCH_WEBVIEW",
    "advertiser": "Lisa Write",
    "adm": "",
    "carouselItems": [],
    "iconUrl": "https://static.particlenews.com/nova/assets/1790058089464029185/b1098dfe756c3ab4f9d0c8e52c22f8850995fc03.png",
    "videoItem": {
      "videoUrl": "https://static.particlenews.com/nova/assets/1790058089464029185/99f569348e959a785611c7bbf927773e33a1ac91_trans.mp4/720_30_6mbps_h264.mp4",
      "coverUrl": "",
      "isPlayAutomatically": true,
      "isLoop": true,
      "isMute": false,
      "isVideoClickable": true,
      "isVertical": true,
      "isPlayOnLandingPage": false
    },
    "channelId": "",
    "isImageClickable": false
  },
  "expirationMs": "1719449896205",
  "encryptedAdToken": "8E24B110-A57B-410A-86E2-FE40E0C0C8CE.CjIIipbesoUyFcOcqMAaJDhFMjRCMTEwLUE1N0ItNDEwQS04NkUyLUZFNDBFMEMwQzhDRRCBwMWukovk6xgYgoD/3b7Si+0YIIHg57z0lIztGCiCwIPitJeggRkwguDnzKC6je0YOgVDTElDS0gBUg9JTU1FUlNJVkVfVklERU9aJm5vdmEtaW9zLWltbWVyc2l2ZS1mbG93LW5hdGl2ZS1wcm9kLW9iaoADaHR0cHM6Ly9nby5wb2xpY3lyYXRlY3V0LmNvbS82NjQyNTk4MWRjODgxMDAwMDE1YWZjM2I/c3ViMT0xNzkwNzk1MDE0NjgzNDc1OTcwJnN1YjI9QXV0bysxJnN1YjM9MTc5MDc5NzI5Njg1MjEzNTkzNyZzdWI0PUFVVE8yJnN1YjU9MTc5MDgwMjk3ODA1MzY4MTE1NCZzdWI2PWFkMiZzdWI3PWlvcyZzdWI4PTAmcmVmX2lkPW52c3NfOEUyNEIxMTBBNTdCNDEwQTg2RTJGRTQwRTBDMEM4Q0VfMTc5MDgwMjk3ODA1MzY4MTE1NCZpc19ub3ZhPXRydWUmdXRtX2NvbnRlbnQ9bnZzc184RTI0QjExMEE1N0I0MTBBODZFMkZFNDBFMEMwQzhDRV8xNzkwODAyOTc4MDUzNjgxMTU0Jm5iX2NpZD04RTI0QjExMEE1N0I0MTBBODZFMkZFNDBFMEMwQzhDRV8xNzkwODAyOTc4MDUzNjgxMTU0cVTAQoPSYwJAkQEAAADAceWtP5kBAAAAIAX2qj+gAcC1A6gBgOHzi/gxsAGNis25hTK6AQQIARABwgEFREFJTFnKASQzQjA2QzQ3OC04NDNGLTQ4NDktQTYwMy0yRjZFOTkxQjY0N0PSAQ5NQVhfQ09OVkVSU0lPTtkBa/DbzkFUQ0DiAQhQUkVfUEFJROgBgcDFrpKL5OsY8AH///////////8BiQIAAABAIdmtP5ECAAAAwBuVqj+ZAlTAQoPSYwJA",
  "startTimeMs": "1715864400000",
  "requestId": "8E24B110-A57B-410A-86E2-FE40E0C0C8CE",
  "adId": "1790802978053681154",
  "adsetId": "1790797296852135937",
  "price": 22.987413649316668
}
],
"status": "success",
"code": 0,
"abConfig": {}
}
"""
