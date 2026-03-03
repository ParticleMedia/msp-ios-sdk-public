import Foundation
import ObjectiveC
import UIKit

private var isImageShowingAssociatedKey: UInt8 = 0

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
                self?.detectImageOnScreen()
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
        if nativeAd?.mediaContent.videoController?.videoView.superview == self.mediaView {
            nativeAd?.mediaContent.videoController?.pause()
        }
        if isImageShowing, let nativeAd {
            NovaAdImageMetricReporter.logImageDwell(
                encryptedAdToken: nativeAd.encryptedAdToken
            )
            isImageShowing = false
        }
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    var isImageShowing: Bool {
        get {
            (objc_getAssociatedObject(self, &isImageShowingAssociatedKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &isImageShowingAssociatedKey,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

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
        guard let videoView = nativeAd?.mediaContent.videoController?.videoView else { return }

        if videoView.superview != self.mediaView {
            stopTimerIfNeeded()
            return
        }

        let isVisible = mediaView.novaIsPartiallyVisibleOnScreen
        let isOnTop = mediaView.onTop
        let appState = UIApplication.shared.applicationState
        let shouldPlay = isVisible && isOnTop && appState == .active

        if shouldPlay {
            nativeAd?.mediaContent.videoController?.play()
        } else {
            nativeAd?.mediaContent.videoController?.pause()
        }
    }

    func detectImageOnScreen() {
        guard let nativeAd else { return }
        guard let imageView = nativeAd.mediaContent.imageController?.imageView else { return }

        if imageView.superview != self.mediaView {
            stopTimerIfNeeded()
            return
        }

        let isVisible = mediaView.novaIsPartiallyVisibleOnScreen
        let isOnTop = mediaView.onTop
        let appState = UIApplication.shared.applicationState
        let shouldShow = isVisible && isOnTop && appState == .active

        if shouldShow {
            if !isImageShowing {
                let token = nativeAd.encryptedAdToken
                NovaAdImageMetricReporter.makeRecord(encryptedAdToken: token)
                NovaAdImageMetricReporter.trackImageShowTime(encryptedAdToken: token)
                nativeAd.mediaContent.imageController?.delegate?.imageViewDidStartDisplaying()
                isImageShowing = true
            }
        } else if isImageShowing {
            NovaAdImageMetricReporter.logImageDwell(
                encryptedAdToken: nativeAd.encryptedAdToken
            )
            isImageShowing = false
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
