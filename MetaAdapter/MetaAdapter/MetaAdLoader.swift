//
//  MetaAdLoader.swift
//  MetaAdapter
//
//  Created by Huanzhi Zhang on 6/26/24.
//
import shared
import FBAudienceNetwork
import AppTrackingTransparency
import PrebidMobile

import Foundation

@objc public class MetaAdLoder : NSObject, AdNetworkAdapter {
    
    public var rootViewController: UIViewController?
    public var adListener: AdListener?
    public var priceInDollar: Double?
    
    private var nativeAdItem: FBNativeAd?
    private var metaNativeAd: MetaNativeAd?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        FBAdSettings.setAdvertiserTrackingEnabled(isIDFAAuthorized())
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: {_ in
            adapterInitListener.onComplete(adNetwork: .facebook, adapterInitStatus: .success, message: "")
        })
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        
        switch adType {
        case "native":
            guard let placementId = self.getFBPlacementId(from: adString) else {
                self.adListener?.onError(msg: "Missing FB payload or placementId")
                return
            }
            nativeAdItem = FBNativeAd(placementID: placementId)
            nativeAdItem?.delegate = self

            DispatchQueue.main.async {
                self.nativeAdItem?.loadAd(withBidPayload: adString)
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
}


extension MetaAdLoder: FBNativeAdDelegate {
    public func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
        let metaNativeAd = MetaNativeAd(adNetworkAdapter: self)
        metaNativeAd.priceInDollar = self.priceInDollar
        metaNativeAd.nativeAdItem = nativeAd
        self.adListener?.onAdLoaded(ad: metaNativeAd)
    }
    
    public func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
        self.adListener?.onError(msg: error.localizedDescription)
    }
    
    public func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
        if let metaNativeAd = self.metaNativeAd {
            self.adListener?.onAdImpression(ad: metaNativeAd)
        }
    }
    
    public func nativeAdDidClick(_ nativeAd: FBNativeAd) {
        if let metaNativeAd = self.metaNativeAd {
            self.adListener?.onAdClick(ad: metaNativeAd)
        }
    }
}
