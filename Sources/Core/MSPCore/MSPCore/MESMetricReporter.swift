//
//  MESMetricReporter.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 10/7/24.
//

//import SwiftProtobuf

import AdSupport
import Foundation
import MSPiOSCore
@_implementationOnly import PrebidMobile
@_implementationOnly import SwiftProtobuf
import UIKit

private typealias ReportCompletion = (Bool, Error?) -> Void

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
        case userSignal = "user_signal"
        case adBidLost = "ad_bid_lost"
        case adDismiss = "ad_dismiss"
    }

    private func reportData(event: AdEventType, with data: Message, completion: ReportCompletion? = nil) {
        do {
            let tracingData = try data.serializedData()
            report(event: event, with: tracingData, completion: completion)
        } catch {
            MSPLogger.shared.error(message: "Failed to serialize protobuf data for event \(event.rawValue):\(error)")
            completion?(false, error)
        }
    }

    private func report(event: AdEventType, with data: Data, completion: ReportCompletion?) {
        innerReport(event: event, with: data) { success, error in
            completion?(success, error)
        }
    }

    private func innerReport(event type: AdEventType, with data: Data, completion: @escaping ReportCompletion) {
        let host = MSP.shared.mesHost.isEmpty ? "mes.newsbreak.com" : MSP.shared.mesHost
        let urlStr = host + "/v1/event/" + type.rawValue
        guard let url = URL(string: urlStr) else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlStr)"])
            completion(false, error)
            return
        }
        var request = URLRequest(url: url)
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
                completion(
                    false,
                    NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to report event"]))
            }
        }

        task.resume()
    }

    public func logSDKInit(
        totalCompleteTimeInMs: Int32?, blockLatencyInMs: Int32?, adNetworkCompleteTimeInMs: [String: Int32]
    ) {
        var eventModel = Com_Newsbreak_Mes_Events_SdkInitEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = MSPDevice.shared.getOSType()
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

        MSPDevice.shared.collectDeviceInfo()
        if let ppid = MSP.shared.ppid {
            eventModel.ppid = ppid
        }
        if let mspId = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_ID) {
            eventModel.mspID = mspId
        }
        eventModel.ifa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        if let batteryLevel = MSPDevice.shared.batteryLevel {
            eventModel.batteryLevel = batteryLevel
        }
        eventModel.batteryStatus = MSPDevice.shared.getBatteryStatusString()
        eventModel.fontSize = MSPDevice.shared.getFontSizeString()
        eventModel.timezone = MSPDevice.shared.getTimezoneString()
        if let availableMemoryBytes = MSPDevice.shared.availableMemory {
            eventModel.availableMemoryBytes = UInt64(availableMemoryBytes)
        }
        if let isLowPowerMode = MSPDevice.shared.isLowPowerMode {
            eventModel.isLowDataMode = isLowPowerMode
        }
        if let isLowDataMode = MSPDevice.shared.isLowDataMode {
            eventModel.isLowDataMode = isLowDataMode
        }

        eventModel.appSignal = getAppSignal()
        eventModel.sdkSignal = getSdkSignal()
        eventModel.deviceSignal = getDeviceSignal()

        reportData(event: .sdkInit, with: eventModel)
    }

    private func getAppSignal() -> Com_Newsbreak_Monetization_Signals_AppSignal {
        var appSignal = Com_Newsbreak_Monetization_Signals_AppSignal()

        let info = Bundle.main.infoDictionary ?? [:]

        appSignal.name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? ""
        appSignal.bundle = Bundle.main.bundleIdentifier ?? ""
        appSignal.ver = info["CFBundleShortVersionString"] as? String ?? ""
        appSignal.domain = ""
        appSignal.page = ""
        appSignal.ppid = MSP.shared.ppid ?? ""

        return appSignal
    }

    private func getSdkSignal() -> Com_Newsbreak_Monetization_Signals_SDKSignal {
        var sdkSignal = Com_Newsbreak_Monetization_Signals_SDKSignal()

        if let appId = MSP.shared.appId {
            sdkSignal.appID = Int32(appId)
        }
        if let orgId = MSP.shared.orgId {
            sdkSignal.orgID = Int32(orgId)
        }
        sdkSignal.mspID = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_ID) ?? ""
        sdkSignal.clientTs = Int64(Date().timeIntervalSince1970 * 1000)
        sdkSignal.sdkVersion = MSP.shared.version
        sdkSignal.platform = Com_Newsbreak_Monetization_Signals_SdkPlatform.ios
        sdkSignal.uuid = getSDKSignalUUID()

        return sdkSignal
    }

    private func getSDKSignalUUID() -> String {
        let keyUUID = "device_signal_uuid"
        if let uuid = UserDefaults.standard.string(forKey: keyUUID) {
            return uuid
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.setValue(newId, forKey: keyUUID)
            return newId
        }
    }

    private func getDeviceSignal() -> Com_Newsbreak_Monetization_Signals_DeviceSignal {
        var deviceSignal = Com_Newsbreak_Monetization_Signals_DeviceSignal()

        deviceSignal.make = "Apple"
        deviceSignal.model = MSPDevice.shared.getDeviceModel()
        deviceSignal.os = UIDevice.current.systemName
        deviceSignal.osv = UIDevice.current.systemVersion

        let scale = UIScreen.main.nativeScale
        let size = UIScreen.main.bounds.size
        deviceSignal.w = Int32(size.width * scale)
        deviceSignal.h = Int32(size.height * scale)

        deviceSignal.volumeLevel = MSPDevice.shared.getVolumeLevel()
        deviceSignal.orientation = MSPDevice.shared.getOrientationString(orientation: UIDevice.current.orientation)
        deviceSignal.fontSize = MSPDevice.shared.getFontSizeString()

        deviceSignal.connectionType = MSPDevice.shared.getConnectionType()

        deviceSignal.country = MSPDevice.shared.getCountry()
        deviceSignal.locale = Locale.current.identifier

        UserAgentManager.shared.start()
        deviceSignal.ua = UserAgentManager.shared.userAgent

        deviceSignal.ifa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        deviceSignal.ifv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        deviceSignal.lmt = MSPDevice.shared.isIDFAAuthorized()

        return deviceSignal
    }

    public func logGetAdFromCache(cacheKey: String, fill: Bool, ad: MSPAd?) {
        var eventModel = Com_Newsbreak_Mes_Events_GetAdFromCacheEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.fill = fill
        eventModel.placementID = cacheKey
        if let ad = ad,
            let seat = ad.adInfo["seat"] as? String
        {
            eventModel.seat = seat
        }

        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }

        reportData(event: .getAdFromCache, with: eventModel)
    }

    public func logAdImpression(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdImpressionEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if let bidResponse = bidResponse,
            let mBidResponse = bidResponse as? BidResponse
        {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
            eventModel.ad = generateAdContext(ad: ad, adRequest: adRequest, bidResponse: mBidResponse)
        } else {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
            eventModel.ad = generateAdContext(ad: ad)
        }

        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version

        reportData(event: .adImpression, with: eventModel)
    }

    public func logAdClick(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any?) {
        logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse, clickMetadata: nil)
    }

    public func logAdClick(
        ad: MSPiOSCore.MSPAd,
        adRequest: MSPiOSCore.AdRequest,
        bidResponse: Any?,
        clickMetadata: AdClickMetadata?
    ) {
        var eventModel = Com_Newsbreak_Mes_Events_AdClickEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        MSPLogger.shared.info(
            message:
                "[MES] Building ad_click event. adFormat=\(adRequest.adFormat), clickAreaName=\(clickMetadata?.clickAreaName ?? "nil"), clickPosition=\(clickMetadata?.clickPosition.map(String.init) ?? "nil")"
        )
        if let bidResponse = bidResponse,
            bidResponse is BidResponse,
            let mBidResponse = bidResponse as? BidResponse
        {
            eventModel.requestContext = generateRequestContext(
                ad: ad,
                request: adRequest,
                bidResponse: mBidResponse,
                clickMetadata: clickMetadata
            )
            eventModel.ad = generateAdContext(ad: ad, adRequest: adRequest, bidResponse: mBidResponse)
        } else {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, clickMetadata: clickMetadata)
            eventModel.ad = generateAdContext(ad: ad)
        }

        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version

        reportData(event: .adClick, with: eventModel)
    }

    public func logAdResult(placementId: String, ad: MSPAd?, fill: Bool, isFromCache: Bool) {
        var eventModel = Com_Newsbreak_Mes_Events_LoadAdResult()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.placementID = placementId
        eventModel.fill = fill
        eventModel.isFromCache = isFromCache

        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }

        reportData(event: .loadAdResult, with: eventModel)
    }

    public func logAdResponse(
        ad: MSPiOSCore.MSPAd?,
        adRequest: MSPiOSCore.AdRequest,
        errorCode: MSPErrorCode,
        errorMessage: String?,
        bidResponse: Any? = nil
    ) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_AdResponse()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = MSPDevice.shared.getOSType()
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
        if let bidResponse = bidResponse as? BidResponse {
            if let ad = ad {
                eventModel.ad = generateAdContext(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
            }
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, bidResponse: bidResponse)
        } else {
            if let ad = ad {
                eventModel.ad = generateAdContext(ad: ad)
            }
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        }

        if let adUnitId = ad?.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String {
            eventModel.requestContext.ext.placementID = adUnitId
        }

        if let requestStartTime = adRequest.requestStartTime {
            eventModel.latency = Int32((Date().timeIntervalSince1970 - requestStartTime) * 1000)
        }

        eventModel.s2SBidTokenLatency = adRequest.s2sLatencyInfo.bidTokenLatency
        eventModel.s2SBidRequestLatency = adRequest.s2sLatencyInfo.bidRequestLatencyMs
        eventModel.s2SAdLoadLatency = adRequest.s2sLatencyInfo.adLoadLatencyMs

        eventModel.mspSdkVersion = MSP.shared.version

        reportData(event: .adResponse, with: eventModel)
    }

    public func logLoadAd(
        adRequest: AdRequest, ad: MSPAd?, filledFromCache: Bool, latency: Double, errorMessage: String?
    ) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_LoadAd()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = MSPDevice.shared.getOSType()
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

        eventModel.auctionBidderLatency = adRequest.s2sLatencyInfo.auctionBidderLatency
        eventModel.s2SBidTokenLatency = adRequest.s2sLatencyInfo.bidTokenLatency
        eventModel.s2SBidRequestLatency = adRequest.s2sLatencyInfo.bidRequestLatencyMs
        eventModel.s2SAdLoadLatency = adRequest.s2sLatencyInfo.adLoadLatencyMs

        reportData(event: .loadAd, with: eventModel)
    }

    public func logGetAd(ad: MSPAd?, placementId: String, errorMessage: String? = nil) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_GetAdEvent()
        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = MSPDevice.shared.getOSType()
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

        reportData(event: .getAd, with: eventModel)
    }

    public func logAdRequest(adRequest: AdRequest) {
        guard shouldLogSampledMESEvent() else { return }
        var eventModel = Com_Newsbreak_Mes_Events_AdRequest()

        eventModel.clientTsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version
        eventModel.requestContext = generateRequestContext(ad: nil, request: adRequest)

        reportData(event: .adRequest, with: eventModel)
    }

    public func logAdHide(
        ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, adScreenshot: Data?,
        fullScreenShot: Data?
    ) {
        var eventModel = Com_Newsbreak_Mes_Events_AdHideEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.reason = reason
        eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        eventModel.os = MSPDevice.shared.getOSType()
        eventModel.ad = generateAdContext(
            ad: ad,
            adRequest: adRequest,
            bidResponse: bidResponse as? BidResponse,
            adScreenShot: adScreenshot,
            fullScreenShot: fullScreenShot)
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }

        reportData(event: .adHide, with: eventModel)
    }

    public func logAdDismiss(ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdDismissEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        if let bidResponse = bidResponse,
            let mBidResponse = bidResponse as? BidResponse
        {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest, bidResponse: mBidResponse)
            eventModel.ad = generateAdContext(ad: ad, adRequest: adRequest, bidResponse: mBidResponse)
        } else {
            eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
            eventModel.ad = generateAdContext(ad: ad)
        }

        eventModel.os = MSPDevice.shared.getOSType()
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }
        eventModel.mspSdkVersion = MSP.shared.version

        reportData(event: .adDismiss, with: eventModel)
    }

    public func logAdReport(
        ad: MSPiOSCore.MSPAd, adRequest: MSPiOSCore.AdRequest, bidResponse: Any, reason: String, description: String?,
        adScreenshot: Data?, fullScreenShot: Data?
    ) {
        var eventModel = Com_Newsbreak_Mes_Events_AdReportEvent()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.reason = reason
        if let description = description {
            eventModel.description_p = description
        }
        eventModel.requestContext = generateRequestContext(ad: ad, request: adRequest)
        eventModel.os = MSPDevice.shared.getOSType()
        eventModel.ad = generateAdContext(
            ad: ad,
            adRequest: adRequest,
            bidResponse: bidResponse as? BidResponse,
            adScreenShot: adScreenshot,
            fullScreenShot: fullScreenShot)
        if let org = MSP.shared.org {
            eventModel.org = org
        }
        if let app = MSP.shared.app {
            eventModel.app = app
        }

        reportData(event: .adReport, with: eventModel)
    }

    func generateRequestContext(
        ad: MSPAd,
        request: AdRequest,
        bidResponse: BidResponse,
        clickMetadata: AdClickMetadata? = nil
    )
        -> Com_Newsbreak_Monetization_Common_RequestContext
    {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = generateBidRequest(
            request: request,
            bidResponse: bidResponse,
            clickMetadata: clickMetadata
        )
        eventModel.ext = generateRequestContextExt(ad: ad, request: request, bidResponse: bidResponse)

        return eventModel
    }

    func generateRequestContext(
        ad: MSPAd?,
        request: AdRequest,
        bidResponse: BidResponse,
        clickMetadata: AdClickMetadata? = nil
    )
        -> Com_Newsbreak_Monetization_Common_RequestContext
    {
        guard let ad = ad else {
            var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
            eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
            eventModel.bidRequest = generateBidRequest(
                request: request,
                bidResponse: bidResponse,
                clickMetadata: clickMetadata
            )
            eventModel.ext = generateRequestContextExt(request: request, bidResponse: bidResponse)

            return eventModel
        }

        return generateRequestContext(
            ad: ad,
            request: request,
            bidResponse: bidResponse,
            clickMetadata: clickMetadata
        )
    }

    func generateRequestContext(
        ad: MSPAd?,
        request: AdRequest,
        clickMetadata: AdClickMetadata? = nil
    ) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = Com_Google_Openrtb_BidRequest()
        eventModel.ext = Com_Newsbreak_Monetization_Common_RequestContextExt()

        let bidRequestId = ad?.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] as? String
        eventModel.bidRequest.id = bidRequestId ?? ""
        eventModel.bidRequest.test = !request.testParams.isEmpty
        applyRewardedRequestMetadata(
            to: &eventModel.bidRequest,
            request: request,
            bidResponse: nil,
            clickMetadata: clickMetadata
        )
        eventModel.ext.source = request.placementId
        eventModel.ext.placementID = ad?.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String ?? ""
        eventModel.ext.userID = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) ?? ""

        return eventModel
    }

    func generateRequestContext(ad: MSPAd?, requestId: String?) -> Com_Newsbreak_Monetization_Common_RequestContext {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContext()
        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.bidRequest = Com_Google_Openrtb_BidRequest()

        eventModel.ext = Com_Newsbreak_Monetization_Common_RequestContextExt()

        let requestIdFromAd = ad?.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] as? String
        eventModel.bidRequest.id = requestIdFromAd ?? requestId ?? ""
        eventModel.ext.placementID = ad?.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String ?? ""
        eventModel.ext.userID = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) ?? ""

        return eventModel
    }

    func generateBidRequest(
        request: AdRequest,
        bidResponse: BidResponse,
        clickMetadata: AdClickMetadata? = nil
    ) -> Com_Google_Openrtb_BidRequest {
        var eventModel = Com_Google_Openrtb_BidRequest()

        eventModel.id = bidResponse.rawResponse?.requestID ?? ""

        if let country = bidResponse.inferredCountry {
            var device = Com_Google_Openrtb_BidRequest.Device()
            var geo = Com_Google_Openrtb_BidRequest.Geo()
            geo.country = country
            device.geo = geo
            eventModel.device = device
        }

        eventModel.test = !request.testParams.isEmpty
        applyRewardedRequestMetadata(
            to: &eventModel,
            request: request,
            bidResponse: bidResponse,
            clickMetadata: clickMetadata
        )

        return eventModel
    }

    private func applyRewardedRequestMetadata(
        to bidRequest: inout Com_Google_Openrtb_BidRequest,
        request: AdRequest,
        bidResponse: BidResponse?,
        clickMetadata: AdClickMetadata?
    ) {
        guard request.adFormat == .rewarded else { return }

        var imp = Com_Google_Openrtb_BidRequest.Imp()
        imp.id = bidResponse?.winningBid?.bid.impid ?? "1"
        imp.tagid = request.placementId
        imp.instl = true
        imp.rwdd = true
        imp.video = Com_Google_Openrtb_BidRequest.Imp.Video()

        var ext: [String: Any] = [
            "placement": request.placementId,
            "ad_format": MSPConstants.AD_FORMAT_REWARDED_VIDEO,
        ]
        if let clickAreaName = clickMetadata?.clickAreaName, !clickAreaName.isEmpty {
            ext["click_area_name"] = clickAreaName
        }
        if let clickPosition = clickMetadata?.clickPosition {
            ext["click_position"] = Int(clickPosition)
        }
        if let extData = try? JSONSerialization.data(withJSONObject: ext),
           let extString = String(data: extData, encoding: .utf8) {
            imp.ext = extString
            MSPLogger.shared.info(message: "[MES] Rewarded request metadata attached to bidRequest.imp.ext=\(extString)")
        }

        bidRequest.imp = [imp]
    }

    func generateRequestContextExt(ad: MSPAd, request: AdRequest, bidResponse: BidResponse)
        -> Com_Newsbreak_Monetization_Common_RequestContextExt
    {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContextExt()
        eventModel.source = request.placementId
        if let adUnitId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] as? String,
            !adUnitId.isEmpty
        {
            eventModel.placementID = adUnitId
        } else {
            eventModel.placementID = bidResponse.adUnitId ?? request.placementId
        }
        eventModel.userID = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) ?? ""

        if let rawResponseJson = bidResponse.rawResponseInJson,
            let extDict = rawResponseJson["ext"] as? [String: Any],
            let bucketInfoDict = extDict["msp_exp_bucket_info"] as? [String: Any],
            let bucketList = bucketInfoDict["exp_bucket_list"] as? [String]
        {
            eventModel.buckets = bucketList
        }

        return eventModel
    }

    func generateRequestContextExt(request: AdRequest, bidResponse: BidResponse)
        -> Com_Newsbreak_Monetization_Common_RequestContextExt
    {
        var eventModel = Com_Newsbreak_Monetization_Common_RequestContextExt()
        eventModel.source = request.placementId
        eventModel.placementID = bidResponse.adUnitId ?? request.placementId
        eventModel.userID = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) ?? ""

        if let rawResponseJson = bidResponse.rawResponseInJson,
            let extDict = rawResponseJson["ext"] as? [String: Any],
            let bucketInfoDict = extDict["msp_exp_bucket_info"] as? [String: Any],
            let bucketList = bucketInfoDict["exp_bucket_list"] as? [String]
        {
            eventModel.buckets = bucketList
        }

        return eventModel
    }

    private func generateAdContext(
        ad: MSPAd,
        adRequest: AdRequest? = nil,
        bidResponse: BidResponse? = nil,
        adScreenShot: Data? = nil,
        fullScreenShot: Data? = nil
    ) -> Com_Newsbreak_Monetization_Common_Ad {
        var eventModel = Com_Newsbreak_Monetization_Common_Ad()

        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        setAdContextTypeInfo(adContext: &eventModel, ad: ad)
        if let adScreenShot = adScreenShot {
            eventModel.adScreenshot = adScreenShot
        }
        if let fullScreenShot = fullScreenShot {
            eventModel.fullScreenshot = fullScreenShot
        }
        if let adRequest = adRequest,
            let bidResponse = bidResponse
        {
            eventModel.seatBid = generateSeatBid(ad: ad, request: adRequest, bidResponse: bidResponse)
        } else {
            eventModel.seatBid = generateSeatBid(ad: ad)
        }

        return eventModel
    }

    private func setAdContextTypeInfo(adContext: inout Com_Newsbreak_Monetization_Common_Ad, ad: MSPAd) {
        if ad is MSPiOSCore.NativeAd,
            let nativeAd = ad as? MSPiOSCore.NativeAd
        {
            adContext.title = nativeAd.title
            adContext.body = nativeAd.body
            adContext.advertiser = nativeAd.advertiser
            adContext.type = .native
        } else if ad is InterstitialAd {
            adContext.type = .interstitial
        } else if ad is RewardedAd {
            // MES common proto has no rewarded enum; PRD treats rewarded as rewarded_video.
            // Use video rather than leaving rewarded events as unspecified.
            adContext.type = .video
        } else if ad is BannerAd {
            adContext.type = .display
        }
    }

    func generateSeatBid(ad: MSPAd, request: AdRequest, bidResponse: BidResponse)
        -> Com_Google_Openrtb_BidResponse.SeatBid
    {
        var eventModel = Com_Google_Openrtb_BidResponse.SeatBid()
        eventModel.seat = bidResponse.winningBidSeat ?? ""
        eventModel.bid = [generateBid(ad: ad, request: request, bidResponse: bidResponse)]
        return eventModel
    }

    private func generateSeatBid(ad: MSPAd) -> Com_Google_Openrtb_BidResponse.SeatBid {
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

        return seatBid
    }

    func generateBid(ad: MSPAd, request: AdRequest, bidResponse: BidResponse)
        -> Com_Google_Openrtb_BidResponse.SeatBid.Bid
    {
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
        if let mspUserId = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID),
            let whiteList = MSP.shared.logWhiteList,
            whiteList.contains(mspUserId)
        {
            return true
        }
        return false
    }

    func tryLogUserSignal(type: Com_Newsbreak_Mes_Events_UserSignalType) {
        let isAttribution = type == Com_Newsbreak_Mes_Events_UserSignalType.attribution
        let attributionSentBefore = UserDefaults.standard.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION) == true

        if isAttribution && attributionSentBefore {
            MSPLogger.shared.info(
                message: "Try log user_signal event failed: user_signal event with type Attribution was sent before")
            return
        }

        logUserSignal(type: type)
    }

    private func logUserSignal(type: Com_Newsbreak_Mes_Events_UserSignalType) {
        var eventModel = Com_Newsbreak_Mes_Events_UserSignal()

        eventModel.type = type
        eventModel.sdkSignal = getSdkSignal()
        eventModel.deviceSignal = getDeviceSignal()
        eventModel.appSignal = getAppSignal()

        let isAttribution = type == Com_Newsbreak_Mes_Events_UserSignalType.attribution

        reportData(event: .userSignal, with: eventModel) { success, error in
            if success && error == nil && isAttribution {
                MSPLogger.shared.info(message: "Logging user signal succeeded")
                UserDefaults.standard.set(true, forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)
            }

            if let error = error {
                MSPLogger.shared.info(message: "Logging user signal failed: \(error)")
            }
        }
    }

    func logAdBidLost(winnerBidderName: String, winnerPrice: Float, ad: MSPAd?, requestId: String?) {
        var eventModel = Com_Newsbreak_Mes_Events_AdBidLostEvent()

        eventModel.tsMs = UInt64(Date().timeIntervalSince1970 * 1000)
        eventModel.requestContext = generateRequestContext(ad: ad, requestId: requestId)
        if let ad = ad {
            eventModel.ad = generateAdContext(ad: ad)
        }
        eventModel.os = .ios
        eventModel.org = MSP.shared.org ?? ""
        eventModel.app = MSP.shared.app ?? ""
        eventModel.mspSdkVersion = MSP.shared.version
        eventModel.winnerBidderName = winnerBidderName
        eventModel.winnerPrice = winnerPrice

        reportData(event: .adBidLost, with: eventModel)
    }
}
