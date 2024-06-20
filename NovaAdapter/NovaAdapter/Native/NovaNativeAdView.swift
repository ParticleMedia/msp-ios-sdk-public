import Foundation
import UIKit

open class NovaNativeAdView: UIView {
    // MARK: - Properties
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    
    public let mediaView: NovaNativeAdMediaView = {
        let view = NovaNativeAdMediaView()
        view.accessibilityIdentifier = "media"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
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

    public init(actionHandler: ActionHandling) {
        self.actionHandler = actionHandler

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
    
    open func bindView(nativeAd: NovaNativeAdItem) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
    }
    
    open func setUpView(nativeAd: NovaNativeAdItem) {
        
        
        titleLabel?.text = nativeAd.headline
        bodyLabel?.text = nativeAd.body
        advertiserLabel?.text = nativeAd.advertiser
        callToActionButton?.titleLabel?.text = nativeAd.callToAction
        //self.nativeAdView.callToActionView?.isUserInteractionEnabled = false
        //self.gadMediaView.translatesAutoresizingMaskIntoConstraints = false
        //self.gadMediaView.contentMode = .scaleAspectFill
        //self.gadMediaView.mediaContent = nativeAd.mediaContent
        //self.nativeAdView.mediaView = gadMediaView
        let mediaVM = NovaNativeAdMediaViewModel(encryptedAdToken: nativeAd.encryptedAdToken,
                                                 imageUrlStr: nativeAd.imageUrlStr,
                                                 videoInfo: nativeAd.videoInfo)
        mediaView.config(with: mediaVM, iabReporter: self.iABMetricReporter) {
            nativeAd.delegate?.nativeAdDidFinishRender(nativeAd)
        }
        register(nativeAd)
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
