//
//  AdMetricReporterImp.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

import Foundation
import MSPiOSCore
import PrebidMobile

public class AdMetricReporterImp: AdMetricReporter {
    public func logAdImpression(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, params: [String : Any?]?) {
        MESMetricReporter.shared.logAdImpression(ad: ad, adRequest: adRequest, bidResponse: bidResponse, params: params)
    }
    
    public func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPiOSCore.MSPAd?) {
        MESMetricReporter.shared.logGetAdFromCache(cacheKey: cacheKey, fill: fill, ad: ad)
    }
    
    public func logAdResult(placementId: String, ad: MSPiOSCore.MSPAd?, fill: Bool, isFromCache: Bool) {
        MESMetricReporter.shared.logAdResult(placementId: placementId, ad: ad, fill: fill, isFromCache: isFromCache)
    }
    
    
}
