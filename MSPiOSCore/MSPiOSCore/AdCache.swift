//
//  AdCache.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/22/24.
//

import Foundation

public class AdCache {
    public static let shared = AdCache()
    
    private var adCache = [String:MSPAd]()
    public var adMetricReporter: AdMetricReporter?
    
    public func peakAd(placementId: String) -> MSPAd? {
        return adCache[placementId]
    }
    
    public func getAd(placementId: String) -> MSPAd? {
        let value = adCache.removeValue(forKey: placementId)
        
        if let ad = value {
            adMetricReporter?.logGetAdFromCache(cacheKey: placementId, fill: true, ad: ad)
        } else {
            adMetricReporter?.logGetAdFromCache(cacheKey: placementId, fill: false, ad: nil)
        }
        
        return value
    }
    
    public func saveAd(placementId: String, ad: MSPAd) {
        adCache[placementId] = ad
    }
}
