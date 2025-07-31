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
    public func logAdHide(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        MESMetricReporter.shared.logAdHide(ad: ad, adRequest: adRequest, bidResponse: bidResponse, reason: reason, adScreenshot: adScreenShot, fullScreenShot: fullScreenShot)
    }
    
    public func logAdReport(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        MESMetricReporter.shared.logAdReport(ad: ad, adRequest: adRequest, bidResponse: bidResponse, reason: reason, description: description, adScreenshot: adScreenShot, fullScreenShot: fullScreenShot)
    }
    
    public func logAdImpression(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any) {
        MESMetricReporter.shared.logAdImpression(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
    }
    
    public func logAdClick(ad: MSPAd, adRequest: AdRequest, bidResponse: Any?) {
        MESMetricReporter.shared.logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
    }
    
    public func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPiOSCore.MSPAd?) {
        MESMetricReporter.shared.logGetAdFromCache(cacheKey: cacheKey, fill: fill, ad: ad)
    }
    
    public func logAdResult(placementId: String, ad: MSPiOSCore.MSPAd?, fill: Bool, isFromCache: Bool) {
        MESMetricReporter.shared.logAdResult(placementId: placementId, ad: ad, fill: fill, isFromCache: isFromCache)
    }
    
    public func logAdResponse(ad: MSPiOSCore.MSPAd?, adRequest: MSPiOSCore.AdRequest, errorCode: MSPErrorCode, errorMessage: String?) {
        MESMetricReporter.shared.logAdResponse(ad: ad, adRequest: adRequest, errorCode: errorCode, errorMessage: errorMessage)
    }
    
}
