import Foundation

enum AdsThirdPartyMetricReporter {
    static func logImpression(thirdPartyImpressionTrackingUrls: [String]) {
        for thirdPartyImpressionTrackingUrl in thirdPartyImpressionTrackingUrls {
            //DebugLogging.info(.ads, "Third party impression tracking, url = \(thirdPartyImpressionTrackingUrl)")

            if let trackingURL = URL(string: thirdPartyImpressionTrackingUrl) {
                NovaTrackingUrlHelper.fire(url: trackingURL)
            }
        }
    }

    static func logClick(thirdPartyClickTrackingUrls: [String]) {
        for thirdPartyClickTrackingUrl in thirdPartyClickTrackingUrls {
            //DebugLogging.info(.ads, "Third party click tracking, url = \(thirdPartyClickTrackingUrl)")

            if let trackingUrl = URL(string: thirdPartyClickTrackingUrl) {
                NovaTrackingUrlHelper.fire(url: trackingUrl)
            }
        }
    }
}
