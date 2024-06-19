import Foundation
import UIKit

public class NovaNativeAdView: UIView {
    // MARK: - Properties

    @objc public var tappableViews: [UIView]? {
        didSet {
            tappableViews?.forEach {
                $0.isUserInteractionEnabled = true
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapAdView(sender:)))
                tapGesture.accessibilityLabel = $0.accessibilityIdentifier
                $0.addGestureRecognizer(tapGesture)
            }
        }
    }

    private let actionHandler: ActionHandling

    private(set) var nativeAd: NovaNativeAdItem?

    // Used to trigger impression check repeatedly until logged.
    var timer: Timer?

    public private(set) var iABMetricReporter: IABMetricReporter?

    // MARK: -

    init(actionHandler: ActionHandling) {
        self.actionHandler = actionHandler

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopTimerIfNeeded()
        //iABMetricReporter?.stopSession()
    }
}

// MARK: - Public methods

public extension NovaNativeAdView {
    @objc func register(_ nativeAd: NovaNativeAdItem) {
        self.nativeAd = nativeAd

        // In case previous OMIDSDK's session is left started without a stop.
        //iABMetricReporter?.stopSession()
        //iABMetricReporter = Self.buildIABMetricReporterFor(nativeAd: nativeAd, adView: self)

        startTimerIfNeeded()
    }

    func unregisterAd() {
        nativeAd = nil

        stopTimerIfNeeded()
        //iABMetricReporter?.stopSession()
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    static func buildIABMetricReporterFor(nativeAd: NovaNativeAdItem, adView: UIView) -> IABMetricReporter? {
        guard let ctrUrlStr = nativeAd.ctrUrl?.absoluteString,
              !nativeAd.thirdPartyViewTrackingUrls.isEmpty
        else { return nil }

        let reporter = IABMetricReporter()
        //reporter.startSession(
        //    adView: adView,
        //    contentUrl: ctrUrlStr,
        //    thirdPartyViewTrackingUrls: nativeAd.thirdPartyViewTrackingUrls,
        //    hasVideo: nativeAd.videoInfo != nil)
        return reporter
    }

    @objc func didTapAdView(sender: UIGestureRecognizer) {
        guard let nativeAd = self.nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        guard let ctrUrl = nativeAd.ctrUrl else {
            assertionFailure("Native ad click url cannot be nil")
            return
        }

        let clickArea = sender.view?.accessibilityIdentifier
        NovaAdMetricReporter.logAdClick(
            thirdPartyClickTrackingUrls: nativeAd.thirdPartyClickTrackingUrls,
            encryptedAdToken: nativeAd.encryptedAdToken,
            clickArea: clickArea
        )

        nativeAd.delegate?.nativeAdDidLogClick(
            nativeAd,
            clickAreaName: NovaAdMetricReporter.convertNovaClickAreaNameToMetric(clickArea: clickArea) ?? ""
        )

        let actionKey: String

        switch nativeAd.launchOption {
        case .launchBrowser:
            actionKey = NovaAdOpenActionKey.launchBrowser.rawValue
        case .launchWebView:
            actionKey = NovaAdOpenActionKey.launchWebView.rawValue
        }

        let actionDataModel = NovaAdOpenActionDataModel(
            url: ctrUrl,
            clickTime: CACurrentMediaTime(),
            ad: nativeAd)

        let actionModel = ActionModel(actionKey: actionKey, actionDataModel: actionDataModel)
        actionHandler.performAction(actionModel: actionModel)
    }
}
