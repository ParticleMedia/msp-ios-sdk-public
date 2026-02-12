import Foundation
@_implementationOnly import Kingfisher
import UIKit

open class NovaNativeAdView: UIView {
    // MARK: - Properties
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    public var icon: UIImageView?
    public var customClickableViews: [UIView]?
    public let mediaView: NovaAdMediaView

    private var tappableViews: [UIView]? {
        didSet {
            tappableViews?.forEach {
                $0.isUserInteractionEnabled = true
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapAdView(sender:)))
                tapGesture.accessibilityLabel = $0.accessibilityIdentifier
                $0.addGestureRecognizer(tapGesture)
                // TODO: - GPY now container has no adClickArea, maybe add in the future
                //                assert($0.adClickArea != nil)
            }
        }
    }

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?

    private(set) var nativeAd: NovaNativeAdItem?

    // Used to trigger impression check repeatedly until logged.
    var timer: Timer?

    // Track start time for click events
    private var startTime: CFTimeInterval = 0

    private(set) var iABMetricReporter: IABMetricReporter?

    // MARK: -

    public init(mediaView: NovaAdMediaView? = nil) {
        self.mediaView = mediaView ?? .init()
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        unregisterAd()
        //iABMetricReporter?.stopSession()
    }

    func bindView(nativeAd: NovaNativeAdItem) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
    }

    public func setupViews(with nativeAd: NovaNativeAdItem, clickableViews: [UIView]? = nil) {
        register(nativeAd)
        // Create action context for the media view
        let actionContext = NovaAdMediaActionContext(
            adActionTracingInfo: nativeAd.actionTracingInfo,
            adActionExtraInfo: nativeAd.actionExtraInfo,
            viewController: nil
        )

        mediaView
            .config(
                with: nativeAd.mediaContent,
                actionContext: actionContext,
                iabReporter: self.iABMetricReporter
            ) {
                nativeAd.delegate?.nativeAdDidFinishRender(nativeAd)
            }
        tappableViews = clickableViews
    }
}

// MARK: - Public methods

extension NovaNativeAdView {
    func register(_ nativeAd: NovaNativeAdItem) {
        self.nativeAd = nativeAd

        // Initialize start time for click tracking
        startTime = CACurrentMediaTime()

        titleLabel?.adClickArea = .headline
        bodyLabel?.adClickArea = .body
        advertiserLabel?.adClickArea = .advertiser
        callToActionButton?.adClickArea = .cta
        icon?.adClickArea = .icon

        actionHelper = NovaActionHelper.build(
            with: .adInView(
                model: AdActionModel(
                    tracingInfo: nativeAd.actionTracingInfo,
                    extraInfo: nativeAd.actionExtraInfo,
                    ctrType: nativeAd.adCtrType
                )
            )
        )

        // In case previous OMIDSDK's session is left started without a stop.
        iABMetricReporter?.stopSession()
        iABMetricReporter = Self.buildIABMetricReporterFor(nativeAd: nativeAd, adView: self)

        startTimerIfNeeded()
    }

    func unregisterAd() {
        stopTimerIfNeeded()
        iABMetricReporter?.stopSession()
        self.nativeAd = nil
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    static func buildIABMetricReporterFor(nativeAd: NovaNativeAdItem, adView: UIView) -> IABMetricReporter? {
        let ctrUrlStr = nativeAd.adCtrType.url.absoluteString

        guard !nativeAd.thirdPartyViewTrackingUrls.isEmpty else { return nil }

        let reporter = IABMetricReporter()
        reporter.startSession(
            adView: adView,
            contentUrl: ctrUrlStr,
            thirdPartyViewTrackingUrls: nativeAd.thirdPartyViewTrackingUrls,
            hasVideo: nativeAd._videoInfo != nil)
        return reporter
    }

    @objc func didTapAdView(sender: UIGestureRecognizer) {
        guard self.nativeAd != nil else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        let clickArea = sender.view?.adClickArea ?? .cta

        if let actionHelper = actionHelper {
            self.actionHelper =
                actionHelper
                .logNovaClickEvent(with: CACurrentMediaTime() - startTime, in: clickArea)
                .handleAdTap(in: sender.view)
        }
    }
}
