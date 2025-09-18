import Foundation
import UIKit

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
        guard timer == nil else { return }

        let timer = Timer(timeInterval: Constants.detectionInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.detectImpression()
                self?.detectVideoOnScreen()
            }
        }
        timer.tolerance = 0.1
        RunLoop.current.add(timer, forMode: .common)

        self.timer = timer
    }

    func stopTimerIfNeeded() {
        guard let timer else { return }

        timer.invalidate()
        self.timer = nil
        nativeAd?.mediaContent.videoController?.stop()
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    func detectImpression() {
        guard nativeAd?.hasImpressionLogged != true else { return }
        guard let window = self.window else { return }

        let frameInWindow = convert(frame, to: window.screen.fixedCoordinateSpace)
        let intersection = frameInWindow.intersection(window.frame)

        if Constants.visibleAreaThreshold.isLessThanOrEqualTo(intersection.height) {
            logAdImpression()
        }
    }

    // TODO: lsy, 这个可能导致开始和暂停的时机和 newsbreak 上略有不同，我记得 nb 上更加严格
    func detectVideoOnScreen() {
        if mediaView.novaIsPartiallyVisibleOnScreen, mediaView.onTop, UIApplication.shared.applicationState == .active {
            nativeAd?.mediaContent.videoController?.play()
        } else {
            nativeAd?.mediaContent.videoController?.pause()
        }
    }
    
    func logAdImpression() {
        guard let nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        guard !nativeAd.hasImpressionLogged else { return }

        nativeAd.hasImpressionLogged = true

        // IAB impression tracking
        iABMetricReporter?.logImpression()

        NovaAdMetricReporter.logAdImpression(
            thirdPartyImpressionTrackingUrls: nativeAd.thirdPartyImpressionTrackingUrls,
            encryptedAdToken: nativeAd.encryptedAdToken,
            adUnitId: nativeAd.adUnitId)

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
        iABMetricReporter?.logLoaded()
    }
}
