import Foundation


class NovaAdOpenLandingLogger: NSObject {
    public enum WebType: String {
        case safari
        case unified
    }
    /*
    static func logStart(adId: String,
                         requestId: String,
                         adUnitId: String,
                         startTime: Double,
                         webType: OpenWebType) {
        let parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageStart, parameters: parameters)
    }

    static func logLoaded(adId: String,
                          requestId: String,
                          adUnitId: String,
                          startTime: Double,
                          success: Bool,
                          error: Error?,
                          webType: OpenWebType) {
        var parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "success": success,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        if let error {
            parameters["error"] = error.localizedDescription
        }
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageAllLoad, parameters: parameters)
    }

    static func logClose(adId: String,
                         requestId: String,
                         adUnitId: String,
                         startTime: Double,
                         status: NovaAdOpenLandingStatus,
                         webType: OpenWebType) {
        let parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "reason": "close",
            "status": status.rawValue,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageClose, parameters: parameters)
    }
    
    static func logJumpOut(
        adId: String,
        requestId: String,
        adUnitId: String,
        startTime: Double,
        scrollDepth: Double?,
        pageIndex: Int?,
        webType: OpenWebType
    ) {
        var parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        if let scrollDepth {
            parameters["scroll_depth"] = scrollDepth
        } else {
            DebugLogging.debug(.ads, "Did not get scrollDepth")
        }
        if let pageIndex {
            parameters["page_index"] = pageIndex
        } else {
            DebugLogging.debug(.ads, "Did not get pageIndex")
        }
        
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageJumpOut, parameters: parameters)
    }

    static func logJumpIn(
        adId: String,
        requestId: String,
        adUnitId: String,
        startTime: Double,
        scrollDepth: Double?,
        pageIndex: Int?,
        webType: OpenWebType
    ) {
        var parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        if let scrollDepth {
            parameters["scroll_depth"] = scrollDepth
        } else {
            DebugLogging.debug(.ads, "Did not get scrollDepth")
        }
        if let pageIndex {
            parameters["page_index"] = pageIndex
        } else {
            DebugLogging.debug(.ads, "Did not get pageIndex")
        }
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageJumpIn, parameters: parameters)
    }

    static func logResignActive(adId: String,
                                requestId: String,
                                adUnitId: String,
                                startTime: Double,
                                webType: OpenWebType) {
        let parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageResignActive, parameters: parameters)
    }

    static func logAliveAfter5Seconds(adId: String,
                                      requestId: String,
                                      adUnitId: String,
                                      startTime: Double,
                                      webType: OpenWebType) {
        let parameters: [String: Any] = [
            "ad_id": adId,
            "request_id": requestId,
            "ad_unit_id": adUnitId,
            "duration_ms": durationMS(startTime),
            "web_type": webType.rawValue,
        ]
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageAliveAfter5s, parameters: parameters)
    }

    static func logRecycledAfter5Seconds(webType: OpenWebType) {
        let parameters: [String: Any] = [
            "web_type": webType.rawValue,
        ]
        MetricService.shared.logRegularAndRealTimeEvent(event: .novaLandingPageRecycledAfter5s)
    }

    private static func durationMS(_ startTime: Double) -> Int {
        return Int((CACurrentMediaTime() - startTime) * 1000)
    }
     */
}

