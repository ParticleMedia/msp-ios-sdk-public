//
//  NovaAdLandingWebContext.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/12.
//

import Foundation

struct AdWebExtraInfo {
    let adCtrType: AdCtrType
    let advertiser: String?
}

struct NovaAdsLandingWebContext {
    let url: URL
    let tracingInfo: AdActionTracingInfo
    let extraInfo: AdWebExtraInfo
    let clickTime: TimeInterval

    init(url: URL, tracingInfo: AdActionTracingInfo, extraInfo: AdWebExtraInfo, clickTime: TimeInterval) {
        self.url = url
        self.tracingInfo = tracingInfo
        self.extraInfo = extraInfo
        self.clickTime = clickTime
    }
}
