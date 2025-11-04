//
//  NovaAdMetricReporter.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation
import UIKit


class NovaAdMetricReporter: NSObject {
    static func logAdImpression(thirdPartyImpressionTrackingUrls: [String],
                                encryptedAdToken: String,
                                adUnitId: String,
                                startTimeInMs: Double? = nil,
                                expirationTimeInMs: Double? = nil)
    {
        // Third party impression tracking
        AdsThirdPartyMetricReporter.logImpression(thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls)

        var params: [String: String] = [:]
        if let startTimeInMs, let expirationTimeInMs {
            params[NovaAdMetricKeys.START_MS] = "\(startTimeInMs)"
            params[NovaAdMetricKeys.EXPIRATION_MS] = "\(expirationTimeInMs)"
            params[NovaAdMetricKeys.CURRENT_MS] = "\(Date().timeIntervalSince1970 * 1000)"
        }
        params[NovaAdMetricKeys.AD_UNIT_ID] = adUnitId
        params[NovaAdMetricKeys.USER_ID] = UserDefaults.standard.string(forKey: "msp_user_id") ?? ""
        // Nova platform impression tracking
        logNovaAdEvent(.impression, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logAdClick(
        thirdPartyClickTrackingUrls: [String],
        encryptedAdToken: String,
        adUnitId: String,
        durationInMs: Int? = nil,
        clickArea: ClickableAdArea? = nil
    ) {
        // Third party click tracking
        AdsThirdPartyMetricReporter.logClick(thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls)

        // Nova platform click tracking
        var params: [String: String] = [:]
        if let durationInMs = durationInMs {
            params[NovaAdMetricKeys.DURATION_MS] = "\(durationInMs)"
        }
        if let clickArea {
            params[NovaAdMetricKeys.CLICK_AREA_NAME] = clickArea.rawValue
        }
        params[NovaAdMetricKeys.AD_UNIT_ID] = adUnitId
        params[NovaAdMetricKeys.USER_ID] = UserDefaults.standard.string(forKey: "msp_user_id") ?? ""
        logNovaAdEvent(.click, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logAdSkip(reason: NovaAdSkipReason, encryptedAdToken: String, durationInMs: String) {
        let params: [String: String] = [
            NovaAdMetricKeys.ACTION: reason.rawValue,
            NovaAdMetricKeys.DURATION_MS: durationInMs,
        ]

        logNovaAdEvent(.skipAd, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logAdHide(reason: String, encryptedAdToken: String) {
        let params: [String: String] = [
            NovaAdMetricKeys.REASON: reason,
        ]

        logNovaAdEvent(.hideAd, encryptedAdToken: encryptedAdToken, params: params)
    }

    enum PlayableTapReason: String {
        case click
        case auto
    }

    static func logPlayableTapToTry(
        encryptedAdToken: String,
        reason: PlayableTapReason,
        durationInMs: Int? = nil,
        clickArea: ClickableAdArea? = nil
    ) {
        var params: [String: String] = [:]
        params["reason"] = reason.rawValue
        if let durationInMs {
            params["duration_ms"] = "\(durationInMs)"
        }
        if let clickArea {
            params[NovaAdMetricKeys.CLICK_AREA_NAME] = clickArea.rawValue
        }

        logNovaAdEvent(.playableTapToTry, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logAdUnhide(encryptedAdToken: String) {
        logNovaAdEvent(.unhideAd, encryptedAdToken: encryptedAdToken)
    }

    static func logVideoEvent(_ event: NovaAdEvent, encryptedAdToken: String, params: [String: String] = [:]) {
        logNovaAdEvent(event, encryptedAdToken: encryptedAdToken, params: params)
    }
    
    static func logWebEvent(_ event: NovaAdEvent, encryptedAdToken: String, params: [String: String] = [:]) {
        logNovaAdEvent(event, encryptedAdToken: encryptedAdToken, params: params)
    }
}

// MARK: - Private methods

private extension NovaAdMetricReporter {
    static func logNovaAdEvent(_ event: NovaAdEvent, encryptedAdToken: String, params: [String: String] = [:]) {
        var params = params

        params[NovaAdMetricKeys.EVENT_TYPE] = event.rawValue
        params[NovaAdMetricKeys.ENCRYPTED_AD_TOKEN] = encryptedAdToken
        params[NovaAdMetricKeys.EVENT_TIME] = "\(Int64(Date().timeIntervalSince1970 * 1000))"
        params[NovaAdMetricKeys.OS] = "ios"
        params[NovaAdMetricKeys.OSV] =  UIDevice.current.systemVersion
        if let cv = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            params[NovaAdMetricKeys.CV] = cv
        }
        //params["session_id"] = "\(HpEngine.sharedInstance().nbSessionId)"

        //let user = HpEngine.sharedInstance().user
        //params["user_id"] = user?.uid
        //params["profile_id"] = user?.pid

        var components = URLComponents(string: NovaConstants.shared.NovaEventHostUrl)
        components?.path = "/api/logAdEvent/"
        components?.queryItems = params.map {
            URLQueryItem(name: $0.0, value: $0.1)
        }

        guard let url = components?.url else { return }

        URLSession.shared.dataTask(with: url).resume()
    }
}

extension NovaAdMetricReporter {
    static func convertNovaClickAreaNameToMetric(clickArea: String?) -> String? {
        guard let clickArea else {
            return nil
        }
        
        switch clickArea {
        case "icon", "advertiser", "badge":
            return clickArea
        case "headline":
            return "headlineLabel"
        case "body":
            return "bodyLabel"
        case "media":
            return "mediaView"
        case "cta":
            return "ctaButton"
        default:
            return nil
        }
    }
}

struct NovaAdMetricKeys {
    static let START_MS = "start_ms"
    static let EXPIRATION_MS = "expiration_ms"
    static let CURRENT_MS = "current_ms"
    static let DURATION_MS = "duration_ms"
    static let LATENCY_MS = "latency_ms"
    static let VIDEO_LENGTH_MS = "video_length_ms"
    static let POSITION_MS = "position_ms"
    static let LOOP_COUNT = "loop_count"
    static let IS_PLAY_AUTOMATICALLY = "is_play_automatically"
    static let IS_MUTE = "is_mute"
    static let IS_LOOP = "is_loop"
    static let AD_UNIT_ID = "ad_unit_id"
    static let USER_ID = "user_id"
    static let CLICK_AREA_NAME = "click_area_name"
    static let ACTION = "action"
    static let REASON = "reason"
    static let ERROR = "error"
    static let OFFSET = "offset"
    
    static let EVENT_TYPE = "event_type"
    static let ENCRYPTED_AD_TOKEN = "encrypted_ad_token"
    static let EVENT_TIME = "event_time"
    
    static let OS = "os"
    static let CV = "cv"
    static let OSV = "osv"
}
