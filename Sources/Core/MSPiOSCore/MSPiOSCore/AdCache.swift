//
//  AdCache.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/22/24.
//

import Foundation

public class AdCache {
    public static let shared = AdCache()

    private var adCache: [String: MSPAd] = [:]
    public var adMetricReporter: AdMetricReporter?

    public func peakAd(placementId: String) -> MSPAd? {
        guard let ad = adCache[placementId] else {
            return nil
        }
        if ad.isValid() {
            return ad
        } else {
            adCache.removeValue(forKey: placementId)
            return nil
        }
    }

    public func getAd(placementId: String) -> MSPAd? {
        let value = adCache.removeValue(forKey: placementId)

        if let ad = value,
            ad.isValid()
        {
            adMetricReporter?.logGetAdFromCache(cacheKey: placementId, fill: true, ad: ad)
            return ad
        } else {
            adMetricReporter?.logGetAdFromCache(cacheKey: placementId, fill: false, ad: nil)
            return nil
        }
    }

    public func saveAd(placementId: String, ad: MSPAd) {
        adCache[placementId] = ad
    }
}
