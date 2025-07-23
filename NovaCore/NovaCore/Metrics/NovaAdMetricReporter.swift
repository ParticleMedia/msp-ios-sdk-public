//
//  NovaAdMetricReporter.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation


@objc public class NovaAdMetricReporter: NSObject {
    public static func logAdImpression(thirdPartyImpressionTrackingUrls: [String],
                                       encryptedAdToken: String,
                                       startTimeInMs: Double? = nil,
                                       expirationTimeInMs: Double? = nil) {
        // Third party impression tracking
        AdsThirdPartyMetricReporter.logImpression(thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls)

        var params: [String: String] = [:]
        if let startTimeInMs, let expirationTimeInMs {
            params["start_ms"] = "\(startTimeInMs)"
            params["expiration_ms"] = "\(expirationTimeInMs)"
            params["current_ms"] = "\(Date().timeIntervalSince1970 * 1000)"
        }
        // Nova platform impression tracking
        logNovaAdEvent(.impression, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logAdClick(
        thirdPartyClickTrackingUrls: [String],
        encryptedAdToken: String,
        durationInMs: Int? = nil,
        clickArea: ClickableAdArea? = nil
    ) {
        // Third party click tracking
        AdsThirdPartyMetricReporter.logClick(thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls)

        // Nova platform click tracking
        var params: [String: String] = [:]
        if let durationInMs = durationInMs {
            params["duration_ms"] = "\(durationInMs)"
        }
        if let clickArea {
            params["click_area_name"] = clickArea.rawValue
        }

        logNovaAdEvent(.click, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logAdSkip(reason: NovaAdSkipReason, encryptedAdToken: String, durationInMs: Int) {
        let params: [String: String] = [
            "action": reason.rawValue,
            "duration_ms": "\(durationInMs)",
        ]

        logNovaAdEvent(.skipAd, encryptedAdToken: encryptedAdToken, params: params)
    }

    @objc public static func logAdHide(reason: String, encryptedAdToken: String) {
        let params: [String: String] = [
            "reason": reason,
        ]

        logNovaAdEvent(.hideAd, encryptedAdToken: encryptedAdToken, params: params)
    }

    @objc public static func logAdUnhide(encryptedAdToken: String) {
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

        params["event_type"] = event.rawValue
        params["encrypted_ad_token"] = encryptedAdToken
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

public extension NovaAdMetricReporter {
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
