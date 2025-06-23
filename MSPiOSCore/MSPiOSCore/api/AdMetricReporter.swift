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
    
    func logAdResponse(ad: MSPiOSCore.MSPAd?, adRequest: MSPiOSCore.AdRequest, errorCode: MSPErrorCode, errorMessage: String?)
    
}

public enum MSPErrorCode: Int {
    case ERROR_CODE_UNSPECIFIED = 0
    case ERROR_CODE_SUCCESS = 1
    case ERROR_CODE_NO_FILL = 2
    case ERROR_CODE_INVALID_REQUEST = 3
    case ERROR_CODE_INTERNAL_ERROR = 4
    case ERROR_CODE_NETWORK_ERROR = 5
}

