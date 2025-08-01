import Foundation
import UIKit

open class NovaNativeAdView: UIView {
    // MARK: - Properties
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    public var icon: UIImageView?
    //public let mediaView: NovaNativeAdMediaView = {
    //    let view = NovaNativeAdMediaView()
    //    view.accessibilityIdentifier = "media"
    //    view.translatesAutoresizingMaskIntoConstraints = false
    //    return view
    //}()
    public let mediaView: NovaNativeAdMediaView
    
    public var novaNativeAdVideoDelegate: NovaNativeAdVideoDelegate?
    
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

    public init(actionHandler: ActionHandling, mediaView: NovaNativeAdMediaView? = nil) {
        self.actionHandler = actionHandler
        self.mediaView = mediaView ?? {
            let view = NovaNativeAdMediaView()
            view.adClickArea = .media
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        super.init(frame: .zero)
        if let popUpView = mediaView?.videoView.popOverCtaController?.tappableView {
            self.seTappableView(view: popUpView)
        }
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
        callToActionButton?.setTitle(nativeAd.callToAction, for: .normal)
        
        let mediaVM = NovaNativeAdMediaViewModel(encryptedAdToken: nativeAd.encryptedAdToken,
                                                 imageUrlStr: nativeAd.imageUrlStr,
                                                 videoInfo: nativeAd.videoInfo)
        mediaView.config(with: mediaVM, iabReporter: self.iABMetricReporter) {
            nativeAd.delegate?.nativeAdDidFinishRender(nativeAd)
        }
        register(nativeAd)
    }
    
    public func prepareViewForInteraction(nativeAd: NovaNativeAdItem) {
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
        
        titleLabel?.adClickArea = .headline
        bodyLabel?.adClickArea = .body
        advertiserLabel?.adClickArea = .advertiser
        callToActionButton?.adClickArea = .cta
        mediaView.adClickArea = .media
        icon?.adClickArea = .icon

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
    
    public func seTappableView(view: UIView) {
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapAdView(sender:)))
        tapGesture.accessibilityLabel = view.accessibilityIdentifier
        view.addGestureRecognizer(tapGesture)
    }
}

// MARK: - Private methods

private extension NovaNativeAdView {
    static func buildIABMetricReporterFor(nativeAd: NovaNativeAdItem, adView: UIView) -> IABMetricReporter? {
        guard let ctrUrlStr = nativeAd.ctrUrl?.absoluteString,
              !nativeAd.thirdPartyViewTrackingUrls.isEmpty
        else { return nil }

        let reporter = IABMetricReporter()
        reporter.startSession(
            adView: adView,
            contentUrl: ctrUrlStr,
            thirdPartyViewTrackingUrls: nativeAd.thirdPartyViewTrackingUrls,
            hasVideo: nativeAd.videoInfo != nil)
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

        let clickArea = sender.view?.adClickArea
        NovaAdMetricReporter.logAdClick(
            thirdPartyClickTrackingUrls: nativeAd.thirdPartyClickTrackingUrls,
            encryptedAdToken: nativeAd.encryptedAdToken,
            adUnitId: nativeAd.adUnitId,
            clickArea: clickArea
        )

        nativeAd.delegate?.nativeAdDidLogClick(
            nativeAd,
            clickAreaName: NovaAdMetricReporter.convertNovaClickAreaNameToMetric(clickArea: clickArea?.rawValue) ?? ""
        )

        let actionKey: String

        switch nativeAd.launchOption {
        case .launchBrowser:
            actionKey = NovaAdOpenActionKey.launchBrowser.rawValue
        case .launchWebView:
            if nativeAd.appStoreId != nil {
                actionKey = NovaAdOpenActionKey.launchStore.rawValue
            } else {
                actionKey = NovaAdOpenActionKey.launchWebView.rawValue
            }
        }

        let actionDataModel = NovaAdOpenActionDataModel(
            url: ctrUrl,
            clickTime: CACurrentMediaTime(),
            ad: nativeAd)

        let actionModel = ActionModel(actionKey: actionKey, actionDataModel: actionDataModel)
        actionHandler.performAction(actionModel: actionModel)
    }
}
