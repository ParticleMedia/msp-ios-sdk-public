//
//  MESMetricReporter.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

import Foundation
import MSPiOSCore
import PrebidMobile
//import SwiftProtobuf

@objc public class MESMetricReporter: NSObject {
    @objc public static let shared = MESMetricReporter()
    
    
    enum AdEventType: String {
        case adImpression = "ad_impression"
        case sdkInit = "sdk_init"
        case adRequest = "ad_request"
        case getAdFromCache = "get_ad_from_cache"
        case loadAdResult = "load_ad_result"
        case adHide = "ad_hide"
        case adReport = "ad_report"
        case adResponse = "ad_response"
        case adClick = "ad_click"
        case loadAd = "load_ad"
        case getAd = "get_ad"
    }
    
    func report(event type: AdEventType, with data: Data, completion: @escaping (Bool, Error?) -> Void) {
        let host = MSP.shared.mesHost ?? "mes.newsbreak.com"
        let urlStr =  host + "/v1/event/" + type.rawValue
        guard let url = URL(string: urlStr) else {
            return
        }
        var request = try URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        //_ = try await URLSession.shared.data(for: request)
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, error)
            } else if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                completion(true, nil)
            } else {
                completion(false, NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to report event"]))
            }
        }
        
        task.resume()
    }
    
    public func logSDKInit(totalCompleteTimeInMs: Int32?, blockLatencyInMs: Int32?, adNetworkCompleteTimeInMs: [String: Int32]) {
        var eventModel = Com_Newsbreak_Mes_Events_SdkInitEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        if let blockLatencyInMs = blockLatencyInMs {
            eventModel.latency = blockLatencyInMs
        }
        
        if let totalCompleteTimeInMs = totalCompleteTimeInMs {
            eventModel.totalCompleteTime = totalCompleteTimeInMs
        }
        
        eventModel.completeTimeByAdNetwork = adNetworkCompleteTimeInMs
        
        eventModel.mspSdkVersion = MSP.shared.version
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .sdkInit, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logGetAdFromCache(cacheKey: String, fill: Bool ,ad: MSPAd?) {
        var eventModel = Com_Newsbreak_Mes_Events_GetAdFromCacheEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.fill = fill
        eventModel.placementID = cacheKey
        if let ad = ad,
           let seat = ad.adInfo["seat"] as? String {
            eventModel.seat = seat
        }
        
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .getAdFromCache, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logAdImpression(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any) {
        var eventModel = Com_Newsbreak_Mes_Events_AdImpressionEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if bidResponse is BidResponse,
           let mBidResponse = bidResponse as? BidResponse {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
            eventModel.ad = generateAdContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
        } else {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
            eventModel.ad = generateAdContext(ad: ad)
        }
        
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adImpression, with: tracingData) { success, error in
               
            }
        } catch {
        }
    }
    
    public func logAdClick(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdClickEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if let bidResponse = bidResponse,
           bidResponse is BidResponse,
           let mBidResponse = bidResponse as? BidResponse {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
            eventModel.ad = generateAdContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
        } else {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
            eventModel.ad = generateAdContext(ad: ad)
        }
        
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adClick, with: tracingData) { success, error in
               
            }
        } catch {
        }
    }
    
    public func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool) {
        var eventModel = Com_Newsbreak_Mes_Events_LoadAdResult()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.placementID = placementId
        eventModel.fill = fill
        eventModel.isFromCache = isFromCache
        
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .loadAdResult, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logAdResponse(ad: MSPiOSCore.MSPAd?, adRequest: MSPiOSCore.AdRequest, errorCode: MSPErrorCode, errorMessage: String?) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_AdResponse()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        eventModel.errorCode = Com_Newsbreak_Monetization_Common_ErrorCode(rawValue: errorCode.rawValue) ?? .unspecified
        
        if let errorMessage = errorMessage {
            eventModel.errorMessage = errorMessage
        }
        if let ad = ad {
            eventModel.ad = generateAdContext(ad: ad)
        }
        eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        
        if let adUnitId = ad?.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String {
            eventModel.requestContext.ext.placementID = adUnitId
        }
        
        if let requestStartTime = adRequest.requestStartTime {
            eventModel.latency = Int32((Date().timeIntervalSince1970 - requestStartTime) * 1000)
        }
        
        eventModel.mspSdkVersion = MSP.shared.version
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adResponse, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logLoadAd(adRequest: AdRequest, ad: MSPAd?, filledFromCache: Bool, latency: Double, errorMessage: String?) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_LoadAd()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        eventModel.filledFromCache = filledFromCache
        
        if let ad = ad {
            eventModel.ad = generateAdContext(ad: ad)
            eventModel.errorCode = .success
        }
        if let errorMessage = errorMessage {
            eventModel.errorMessage = errorMessage
        }
        if latency.isFinite, !latency.isNaN {
            eventModel.latency = Int32(latency)
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .loadAd, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logGetAd(ad: MSPAd?, placementId: String, errorMessage: String? = nil) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_GetAdEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        
        if let ad = ad {
            eventModel.ad = generateAdContext(ad: ad)
            eventModel.errorCode = .success
        } else {
            eventModel.errorCode = .noFill
        }
        
        if let errorMessage = errorMessage {
            eventModel.errorMessage = errorMessage
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .getAd, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logAdRequest(adRequest: AdRequest) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_AdRequest()
        
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        eventModel.requestContext = generateRequestContext(ad: nil, request: adRequest)
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adRequest, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    public func logAdHide(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, adScreenshot: Data?, fullScreenShot: Data?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdHideEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.reason = reason
        eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        eventModel.ad = generateAdContext(ad: ad, adScreenShot: adScreenshot, fullScreenShot: fullScreenShot)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adHide, with: tracingData) { success, error in
               
            }
        } catch {
        }
    }
    
    public func logAdReport(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, description: String?, adScreenshot: Data?, fullScreenShot: Data?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdReportEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.reason = reason
        if let description = description {
            eventModel.description_p = description
        }
        eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        eventModel.ad = generateAdContext(ad: ad, adScreenShot: adScreenshot, fullScreenShot: fullScreenShot)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .adReport, with: tracingData) { success, error in
               
            }
        } catch {
        }
    }
    
    func generateRequestContext(ad: MSPAd, request: AdRequest, bidResponse: BidResponse) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = generateBidRequest(request: request, bidResponse: bidResponse)
        eventModel.ext = generateRequestContextExt(ad: ad, request: request, bidResponse: bidResponse)
        
        return eventModel
    }
    
    func generateRequestContext(ad: MSPAd?, request: AdRequest) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = Com_Google_Openrtb_BidRequest()
        eventModel.ext = Com_Newsbreak_Monetization_Common_RequestContextExt()
        
        eventModel.bidRequest.id = request.requestId
        eventModel.ext.source = request.placementId
        eventModel.ext.placementID = ad?.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String ?? ""
        eventModel.ext.userID = UserDefaults.standard.string(forKey: "msp_user_id") ?? ""
         
        return eventModel
    }
    
    func generateBidRequest(request: AdRequest, bidResponse: BidResponse) -> Com_Google_Openrtb_BidRequest {
        var eventModel = Com_Google_Openrtb_BidRequest()
        
        eventModel.id = bidResponse.winningBid?.bid.impid ?? ""
        
        return eventModel
    }
    
    func generateRequestContextExt(ad: MSPAd, request: AdRequest, bidResponse: BidResponse) -> Com_Newsbreak_Monetization_Common_RequestContextExt {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContextExt()
        eventModel.source = request.placementId
        if let adUnitId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String,
           !adUnitId.isEmpty {
            eventModel.placementID = adUnitId
        } else {
            eventModel.placementID = bidResponse.adUnitId ?? request.placementId
        }
        eventModel.userID = UserDefaults.standard.string(forKey: "msp_user_id") ?? ""
        
        if let rawResponseJson = bidResponse.rawResponseInJson,
           let extDict = rawResponseJson["ext"] as? [String:Any],
           let bucketInfoDict = extDict["msp_exp_bucket_info"] as? [String:Any],
           let bucketList = bucketInfoDict["exp_bucket_list"] as? [String] {
            eventModel.buckets = bucketList
        }
        
        return eventModel
    }
    
    func generateAdContext(ad: MSPAd, request: AdRequest, bidResponse: BidResponse) -> Com_Newsbreak_Monetization_Common_Ad {
        var eventModel = Com_Newsbreak_Monetization_Common_Ad()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if ad is MSPiOSCore.NativeAd,
           let nativeAd = ad as? MSPiOSCore.NativeAd {
            eventModel.title = nativeAd.title
            eventModel.body = nativeAd.body
            eventModel.advertiser = nativeAd.advertiser
            eventModel.type = .native
        } else if ad is InterstitialAd {
            eventModel.type = .interstitial
        } else if ad is BannerAd {
            eventModel.type = .display
        }
        
        eventModel.seatBid = generateSeatBid(ad: ad, request: request, bidResponse: bidResponse)
        
        return eventModel
    }
    
    func generateAdContext(ad: MSPAd, adScreenShot: Data? = nil, fullScreenShot: Data? = nil) -> Com_Newsbreak_Monetization_Common_Ad {
        var eventModel = Com_Newsbreak_Monetization_Common_Ad()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if ad is MSPiOSCore.NativeAd,
           let nativeAd = ad as? MSPiOSCore.NativeAd {
            eventModel.title = nativeAd.title
            eventModel.body = nativeAd.body
            eventModel.advertiser = nativeAd.advertiser
            eventModel.type = .native
        } else if ad is InterstitialAd {
            eventModel.type = .interstitial
        } else if ad is BannerAd {
            eventModel.type = .display
        }
        
        if let adScreenShot = adScreenShot {
            eventModel.adScreenshot = adScreenShot
        }
        if let fullScreenShot = fullScreenShot {
            eventModel.fullScreenshot = fullScreenShot
        }
        
        var seatBid = Com_Google_Openrtb_BidResponse.SeatBid()
        if let seat = ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String {
            seatBid.seat = seat
        } else {
            seatBid.seat = ad.adNetworkAdapter?.getAdNetwork().rawValue ?? ""
        }
        var bid = Com_Google_Openrtb_BidResponse.SeatBid.Bid()
        bid.adid = ""
        bid.adm = ""
        bid.crid = ""
        bid.cid = ""
        bid.id = ""
        bid.lurl = ""
        bid.nurl = ""
        bid.price = ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double ?? 0
        bid.adomain = [""]
        bid.impid = ""
        seatBid.bid = [bid]
        
        eventModel.seatBid = seatBid
        
        return eventModel
    }
    
    func generateSeatBid(ad: MSPAd, request: AdRequest, bidResponse: BidResponse) -> Com_Google_Openrtb_BidResponse.SeatBid {
        var eventModel = Com_Google_Openrtb_BidResponse.SeatBid()
        eventModel.seat = bidResponse.winningBidSeat ?? ""
        eventModel.bid = [generateBid(ad: ad, request: request, bidResponse: bidResponse)]
        return eventModel
    }
    
    func generateBid(ad: MSPAd, request: AdRequest, bidResponse: BidResponse) -> Com_Google_Openrtb_BidResponse.SeatBid.Bid {
        var eventModel = Com_Google_Openrtb_BidResponse.SeatBid.Bid()
        eventModel.adid = bidResponse.winningBid?.bid.adid ?? ""
        eventModel.adm = bidResponse.winningBid?.adm ?? ""
        eventModel.crid = bidResponse.winningBid?.bid.crid ?? ""
        eventModel.cid = bidResponse.winningBid?.bid.cid ?? ""
        eventModel.id = bidResponse.winningBid?.bid.bidID ?? ""
        eventModel.lurl = bidResponse.winningBid?.bid.lurl ?? ""
        eventModel.nurl = bidResponse.winningBid?.bid.nurl ?? ""
        eventModel.price = Double(bidResponse.winningBid?.price ?? 0)
        eventModel.adomain = bidResponse.winningBid?.bid.adomain ?? [""]
        eventModel.impid = bidResponse.winningBid?.bid.impid ?? ""
        
        return eventModel
    }
    
    func shouldLogSampledMESEvent() -> Bool {
        if MSP.shared.isLogSampled {
            return true
        }
        if let mspUserId = UserDefaults.standard.string(forKey: "msp_user_id"),
           let whiteList = MSP.shared.logWhiteList,
           whiteList.contains(mspUserId) {
            return true
        }
        return false
    }
}

