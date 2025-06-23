//
//  AdRequest.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public class AdRequest {
    public var customParams: [String:Any]
    public var geo: Geo?
    public var context: Any?
    public var adaptiveBannerSize: AdSize?
    public var adSize: AdSize?
    public var placementId: String
    public var adFormat: AdFormat
    public var testParams: [String:Any]
    
    public var requestId = UUID().uuidString
    
    public var requestStartTime: Double?
    
    public init(customParams: [String : Any], geo: Geo?, context: Any?, adaptiveBannerSize: AdSize?, adSize: AdSize?, placementId: String, adFormat: AdFormat, testParams: [String:Any] = [:] ) {
        self.customParams = customParams
        self.geo = geo
        self.context = context
        self.adaptiveBannerSize = adaptiveBannerSize
        self.adSize = adSize
        self.placementId = placementId
        self.adFormat = adFormat
        self.testParams = testParams
    }
}

public struct AdSize {
    public let width: Int
    public let height: Int
    public let isInlineAdaptiveBanner: Bool
    public let isAnchorAdaptiveBanner: Bool
    
    public init(width: Int, height: Int, isInlineAdaptiveBanner: Bool = false, isAnchorAdaptiveBanner: Bool = false) {
        self.width = width
        self.height = height
        self.isInlineAdaptiveBanner = isInlineAdaptiveBanner
        self.isAnchorAdaptiveBanner = isAnchorAdaptiveBanner
    }
}
