//
//  AdMetricReporter.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

import Foundation


public protocol AdMetricReporter: AnyObject {
    
    func logAdImpression(ad: MSPAd, adRequest: AdRequest, bidResponse: Any, params: [String: Any?]?)
    
    func logGetAdFromCache(cacheKey: String, fill: Bool ,ad: MSPAd?)
    
    func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool)
    
    func logAdHide(ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, adScreenShot: Data?, fullScreenShot: Data?)
    
    func logAdReport(ad: MSPAd, adRequest: AdRequest, bidResponse: Any, reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?)
    
}
