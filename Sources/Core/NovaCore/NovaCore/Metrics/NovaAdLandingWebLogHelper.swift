//
//  NovaAdLandingWebLogHelper.swift
//  NovaCore
//
//  Created by Auto on 2025/01/XX.
//

import Foundation
import QuartzCore

class NovaAdLandingWebLogHelper {
    
    private static func durationMS(_ clickTime: TimeInterval) -> Int {
        return Int((CACurrentMediaTime() - clickTime) * 1000)
    }
    
    private static func baseParams(webContext: NovaAdsLandingWebContext) -> [String: String] {
        return [
            "ad_id": webContext.tracingInfo.adId,
            "request_id": webContext.tracingInfo.requestId,
            "ad_unit_id": webContext.tracingInfo.adUnitId,
            "duration_ms": String(durationMS(webContext.clickTime)),
            "web_type": "unified"
        ]
    }
    
    static func logStart(webContext: NovaAdsLandingWebContext) {
        let params = baseParams(webContext: webContext)
        NovaAdMetricReporter.logWebEvent(
            .novaLandingPageStart,
            encryptedAdToken: webContext.tracingInfo.encryptedAdToken,
            params: params
        )
    }
    
    static func logClose(
        webContext: NovaAdsLandingWebContext,
        status: NovaAdOpenLandingStatus,
        scrollDepth: Double? = nil,
        pageIndex: Int? = nil
    ) {
        var params = baseParams(webContext: webContext)
        params["reason"] = "close"
        params["status"] = String(status.rawValue)
        
        if let scrollDepth = scrollDepth {
            params["scroll_depth"] = String(scrollDepth)
        }
        if let pageIndex = pageIndex {
            params["page_index"] = String(pageIndex)
        }
        
        NovaAdMetricReporter.logWebEvent(
            .novaLandingPageClose,
            encryptedAdToken: webContext.tracingInfo.encryptedAdToken,
            params: params
        )
    }
    
    static func logJumpOut(
        webContext: NovaAdsLandingWebContext,
        scrollDepth: Double? = nil,
        pageIndex: Int? = nil
    ) {
        var params = baseParams(webContext: webContext)
        
        if let scrollDepth = scrollDepth {
            params["scroll_depth"] = String(scrollDepth)
        }
        if let pageIndex = pageIndex {
            params["page_index"] = String(pageIndex)
        }
        
        NovaAdMetricReporter.logWebEvent(
            .novaLandingPageJumpOut,
            encryptedAdToken: webContext.tracingInfo.encryptedAdToken,
            params: params
        )
    }
    
    static func logJumpIn(
        webContext: NovaAdsLandingWebContext,
        scrollDepth: Double? = nil,
        pageIndex: Int? = nil
    ) {
        var params = baseParams(webContext: webContext)
        
        if let scrollDepth = scrollDepth {
            params["scroll_depth"] = String(scrollDepth)
        }
        if let pageIndex = pageIndex {
            params["page_index"] = String(pageIndex)
        }
        
        NovaAdMetricReporter.logWebEvent(
            .novaLandingPageJumpIn,
            encryptedAdToken: webContext.tracingInfo.encryptedAdToken,
            params: params
        )
    }
    
    static func logLoaded(
        webContext: NovaAdsLandingWebContext,
        success: Bool,
        error: Error? = nil,
        pageIndex: Int? = nil
    ) {
        var params = baseParams(webContext: webContext)
        params["success"] = String(success)
        
        if let error = error {
            params["error"] = error.localizedDescription
        }
        if let pageIndex = pageIndex {
            params["page_index"] = String(pageIndex)
        }
        
        NovaAdMetricReporter.logWebEvent(
            .novaLandingPageAllLoad,
            encryptedAdToken: webContext.tracingInfo.encryptedAdToken,
            params: params
        )
    }
}

