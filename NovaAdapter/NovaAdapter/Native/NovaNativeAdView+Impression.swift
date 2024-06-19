import Foundation

extension NovaNativeAdView {
    // MARK: - Constants

    private enum Constants {
        static let detectionInterval = 0.2
        static let visibleAreaThreshold = 1.0
    }

    // MARK: - Internal methods

    func startTimerIfNeeded() {
        guard let nativeAd = self.nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        if !nativeAd.hasLoadedLogged {
            logAdLoaded()
        }
        // Only start the timer when ad impression hasn't been logged, and no existing timer.
        guard !nativeAd.hasImpressionLogged, timer == nil else { return }

        let timer = Timer(timeInterval: Constants.detectionInterval, repeats: true, block: detectImpression)
        timer.tolerance = 0.1
        RunLoop.current.add(timer, forMode: .common)

        self.timer = timer
    }

    func stopTimerIfNeeded() {
        guard let timer = self.timer else { return }

        timer.invalidate()
        self.timer = nil
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    func detectImpression(timer: Timer) {
        guard let window = self.window else { return }

        let frameInWindow = convert(frame, to: window.screen.fixedCoordinateSpace)
        let intersection = frameInWindow.intersection(window.frame)

        if Constants.visibleAreaThreshold.isLessThanOrEqualTo(intersection.height) {
            stopTimerIfNeeded()
            logAdImpression()
        }
    }

    func logAdImpression() {
        guard let nativeAd = self.nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        guard !nativeAd.hasImpressionLogged else { return }

        nativeAd.hasImpressionLogged = true

        // IAB impression tracking
        //iABMetricReporter?.logImpression()

        NovaAdMetricReporter.logAdImpression(
            thirdPartyImpressionTrackingUrls: nativeAd.thirdPartyImpressionTrackingUrls,
            encryptedAdToken: nativeAd.encryptedAdToken)

        nativeAd.delegate?.nativeAdDidLogImpression(nativeAd)
    }

    func logAdLoaded() {
        guard let nativeAd = self.nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        guard !nativeAd.hasLoadedLogged else { return }

        nativeAd.hasLoadedLogged = true

        // IAB loaded tracking
        //iABMetricReporter?.logLoaded()
    }
}
