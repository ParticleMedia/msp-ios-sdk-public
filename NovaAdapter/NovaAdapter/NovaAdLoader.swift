//
//  NovaAdLoader.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/12/24.
//

import Foundation
import shared
import PrebidMobile
import NovaCore

public class NovaAdLoader: AdNetworkAdapter {
    
    public var adListener: AdListener?
    public var priceInDollar: Double?
    public var adUnitId: String?
    
    public var nativeAd: MSPAd?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        //guard bidResponse is BidResponse,
        //      let mBidResponse = bidResponse as? BidResponse else {
        //    self.adListener?.onError(msg: "no valid response")
        //    return
        //}
        
       
        
        self.adListener = adListener
        /*
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let novaExtDict = SafeAs(bidExtDict["nova"], [String: Any].self),
              let adUnitId = SafeAs(novaExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
         */
        //self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        self.adUnitId = "12345"//adUnitId
        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        parseNovaAdString(adString: testAdString, adType: "native", adUnitId: "12345", eCPMInDollar: eCPMInDollar)
    }
    
    public func prepareViewForInteraction(nativeAd: shared.NativeAd, nativeAdView: Any) {
        
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
                return
            }
            
            switch adType {
            case "banner":
                return
                //let bannerAd = NovaAdBuilder.buildBannerAd(adItem: ads.first!, adUnitId: adUnitId)
                //delegate?.novaAdLoader?(self, didReceiveBannerAd: bannerAd)

            case "native":
                /*
                let nativeAd = NovaNativeAd(adNetworkAdapter: self,
                                            builder: shared.NativeAd.Builder(adNetworkAdapter: self)
                                                        .title(title: adItem.creative.headline ?? "")
                                                        .body(body: adItem.creative.body ?? "")
                                                        .advertiser(advertiser: adItem.creative.advertiser ?? "")
                                                        .callToAction(callToAction: adItem.creative.callToAction ?? ""))
                 */
                let nativeAd = NovaNativeAd(adNetworkAdapter: self)
                let nativeAdItem = NovaAdBuilder.buildNativeAd(adItem: adItem, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
                nativeAd.priceInDollar = self.priceInDollar
                nativeAd.nativeAdItem = nativeAdItem
                self.nativeAd = nativeAd
                nativeAdItem.delegate = self
                self.adListener?.onAdLoaded(ad: nativeAd)
            default:
                self.adListener?.onError(msg: "unknown adType")
            }
        } catch {
            self.adListener?.onError(msg: "error decode nova ad string")
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
}

extension NovaAdLoader: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
        }
    }
    
    public func nativeAdDidLogClick(_ nativeAd: NovaCore.NovaNativeAdItem, clickAreaName: String) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
        }
    }
    
    public func nativeAdDidFinishRender(_ nativeAd: NovaCore.NovaNativeAdItem) {
        
    }
}
