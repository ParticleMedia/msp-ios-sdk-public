import Foundation
import UIKit

open class NovaNativeAdView: UIView {
    // MARK: - Properties
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    public var icon: UIImageView?
    public let mediaView: NovaAdMediaView

    public var novaAdMediaViewDelegate: NovaAdMediaViewDelegate?

    // TODO: lsy, 外界最后是直接使用的这个？not good enough
    public var tappableViews: [UIView]? {
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
        self.mediaView = mediaView ?? {
            let view = NovaAdMediaView()
            view.adClickArea = .media
            return view
        }()
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopTimerIfNeeded()
        //iABMetricReporter?.stopSession()
    }
    
    func bindView(nativeAd: NovaNativeAdItem) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
    }
    
    public func setUpView(nativeAd: NovaNativeAdItem) {
        titleLabel?.text = nativeAd.headline
        bodyLabel?.text = nativeAd.body
        advertiserLabel?.text = nativeAd.advertiser
        callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)

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
        register(nativeAd)
    }

    // TODO: lsy, 这个方法和上面那个有什么区别
    public func prepareViewForInteraction(nativeAd: NovaNativeAdItem) {
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
        register(nativeAd)
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
        mediaView.adClickArea = .media
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
        nativeAd = nil

        stopTimerIfNeeded()
        iABMetricReporter?.stopSession()
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
        guard let nativeAd = self.nativeAd else {
            assertionFailure("Native ad view should have an associated ad")
            return
        }

        let clickArea = sender.view?.adClickArea ?? .cta
        
        if let actionHelper = actionHelper {
            self.actionHelper = actionHelper
                .logNovaClickEvent(with: CACurrentMediaTime() - startTime, in: clickArea)
                .handleAdTap(in: sender.view)
        }
        
        nativeAd.delegate?.nativeAdDidLogClick(
            nativeAd,
            clickAreaName: NovaAdMetricReporter.convertNovaClickAreaNameToMetric(clickArea: clickArea.rawValue) ?? ""
        )
    }
}
