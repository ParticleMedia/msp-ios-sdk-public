//
//  MESMetricReporter.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

import Foundation
import MSPiOSCore
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
    
    public func logAdImpression(ad: MSPAd) {
        var eventModel = Com_Newsbreak_Mes_Events_AdImpressionEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.ad = generateAdContext(ad: ad)
        
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
    
    func generateRequestContext(request: AdRequest) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        return eventModel
    }
    
    func generateAdContext(ad: MSPAd) -> Com_Newsbreak_Monetization_Common_Ad {
        var eventModel = Com_Newsbreak_Monetization_Common_Ad()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if ad is NativeAd,
           let nativeAd = ad as? NativeAd {
            eventModel.title = nativeAd.title
            eventModel.body = nativeAd.body
            eventModel.advertiser = nativeAd.advertiser
            eventModel.type = .native
        } else if ad is InterstitialAd {
            eventModel.type = .interstitial
        } else if ad is BannerAd {
            eventModel.type = .display
        }
        return eventModel
    }
    
}

