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
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        
       
        
        self.adListener = adListener
        
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
        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        self.adUnitId = adUnitId
        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        parseNovaAdString(adString: adString, adType: "native", adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
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
}
