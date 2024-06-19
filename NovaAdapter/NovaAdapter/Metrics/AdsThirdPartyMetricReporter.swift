public enum AdsThirdPartyMetricReporter {
    public static func logImpression(thirdPartyImpressionTrackingUrls: [String]) {
        for thirdPartyImpressionTrackingUrl in thirdPartyImpressionTrackingUrls {
            //DebugLogging.info(.ads, "Third party impression tracking, url = \(thirdPartyImpressionTrackingUrl)")

            if let trackingURL = URL(string: thirdPartyImpressionTrackingUrl) {
                URLSession.shared.dataTask(with: trackingURL).resume()
            }
        }
    }

    public static func logClick(thirdPartyClickTrackingUrls: [String]) {
        for thirdPartyClickTrackingUrl in thirdPartyClickTrackingUrls {
            //DebugLogging.info(.ads, "Third party click tracking, url = \(thirdPartyClickTrackingUrl)")

            if let trackingUrl = URL(string: thirdPartyClickTrackingUrl) {
                URLSession.shared.dataTask(with: trackingUrl).resume()
            }
        }
    }
}
