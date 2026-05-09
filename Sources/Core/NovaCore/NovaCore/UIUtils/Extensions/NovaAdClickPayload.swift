//
//  NovaAdClickPayload.swift
//  NovaCore
//

import Foundation

struct NovaAdClickPayload {
    let url: URL?
    let area: ClickableAdArea
    let extras: [String: String]

    init(url: URL?, area: ClickableAdArea, extras: [String: String] = [:]) {
        self.url = url
        self.area = area
        self.extras = extras
    }
}

extension NovaAdClickPayload {
    /// Keys allowed to flow from H5 `novaNativeBridge.open()` payload into ad click reporting.
    /// H5 is an untrusted source — only whitelisted keys may enter the DSP query string.
    static let allowedExtraKeys: Set<String> = [
        NovaAdMetricKeys.PRODUCT_ID,
        NovaAdMetricKeys.GRID_IDX,
    ]

    /// Builds a click payload from the raw `novaNativeBridge.open(payload)` JS bridge argument.
    ///
    /// Recognized payload keys (any others are ignored — H5 is untrusted):
    /// - `url` (`String`): landing page URL; bad strings collapse to `nil`.
    /// - `click_area_name` (`String`): click area tag; unknown values become `.custom(raw)`.
    /// - `product_id` (`String` or number): forwarded into DSP click reporting.
    /// - `grid_idx` (`String` or number): forwarded into DSP click reporting.
    ///
    /// `rawPayload` may be a `[String: Any]` (JS object), a `String` (JSON-encoded object),
    /// or anything else — unsupported types yield an empty payload rather than a crash.
    static func openPayload(from rawPayload: Any?) -> NovaAdClickPayload {
        guard let json = jsonObject(from: rawPayload) else {
            return NovaAdClickPayload(url: nil, area: ClickableAdArea(from: ""))
        }

        let customUrl: URL?
        if let urlString = json["url"] as? String, !urlString.isEmpty {
            customUrl = URL(string: urlString)
        } else {
            customUrl = nil
        }

        let clickAreaString = (json["click_area_name"] as? String) ?? ""
        return NovaAdClickPayload(
            url: customUrl,
            area: ClickableAdArea(from: clickAreaString),
            extras: extractAllowedExtras(from: json)
        )
    }

    /// Extracts whitelisted reporting fields from a parsed JSON payload.
    /// Numeric values are stringified; missing or empty values are dropped.
    private static func extractAllowedExtras(from json: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for key in allowedExtraKeys {
            guard let raw = json[key] else { continue }
            if let s = raw as? String, !s.isEmpty {
                result[key] = s
            } else if let n = raw as? NSNumber {
                result[key] = n.stringValue
            }
        }
        return result
    }

    private static func jsonObject(from rawPayload: Any?) -> [String: Any]? {
        if let json = rawPayload as? [String: Any] {
            return json
        }

        guard let jsonString = rawPayload as? String,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return json
    }
}
