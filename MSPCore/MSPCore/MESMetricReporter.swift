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
        case loadAdRequest = "load_ad_request"
        case getAdFromCache = "get_ad_from_cache"
        case loadAdResult = "load_ad_result"
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
    
    public func logSDKInit() {
        var eventModel = Com_Newsbreak_Mes_Events_SdkInitEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
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
    
    public func logAdImpression(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, params: [String : Any?]?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdImpressionEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if bidResponse is BidResponse,
           let mBidResponse = bidResponse as? BidResponse {
            eventModel.requestContext = generateRequestContext(request: adRequest, bidResponse: mBidResponse)
            eventModel.ad = generateAdContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
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
            report(event: .adImpression, with: tracingData) { success, error in
               
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
    
    public func logAdRequest(adRequest: AdRequest) {
        var eventModel = Com_Newsbreak_Mes_Events_LoadAdRequest()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.placementID = adRequest.placementId
    
        eventModel.os = .ios
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        
        
        do {
            let tracingData = try eventModel.serializedData()
            report(event: .loadAdRequest, with: tracingData) { success, error in
               
            }
        } catch {
            
        }
    }
    
    func generateRequestContext(request: AdRequest, bidResponse: BidResponse) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = generateBidRequest(request: request, bidResponse: bidResponse)
        eventModel.ext = generateRequestContextExt(request: request, bidResponse: bidResponse)
        
        return eventModel
    }
    
    func generateBidRequest(request: AdRequest, bidResponse: BidResponse) -> Com_Google_Openrtb_BidRequest {
        var eventModel = Com_Google_Openrtb_BidRequest()
        
        eventModel.id = bidResponse.winningBid?.bid.impid ?? ""
        
        return eventModel
    }
    
    func generateRequestContextExt(request: AdRequest, bidResponse: BidResponse) -> Com_Newsbreak_Monetization_Common_RequestContextExt {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContextExt()
        eventModel.source = request.placementId
        eventModel.placementID = bidResponse.adUnitId ?? request.placementId
        eventModel.userID = UserDefaults.standard.string(forKey: "msp_user_id") ?? ""
        
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
    
    
}

