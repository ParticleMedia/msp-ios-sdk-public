//
//  NovaInterstitialAdViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

// MARK: - NovaInterstitialAdReportHandling

import Foundation
@_implementationOnly import SnapKit
import UIKit

public struct NovaAdReportContext {
    public let advertiser: String?
    public let headline: String?
    public let body: String?
    public let adId: String
    public let adSetId: String
    public let adRequestId: String
    public let encryptedToken: String
    public let extra: [String: Any]

    public init(
        advertiser: String?,
        headline: String?,
        body: String?,
        adId: String,
        adSetId: String,
        adRequestId: String,
        encryptedToken: String,
        extra: [String : Any] = [:]
    ) {
        self.advertiser = advertiser
        self.headline = headline
        self.body = body
        self.adId = adId
        self.adSetId = adSetId
        self.adRequestId = adRequestId
        self.encryptedToken = encryptedToken
        self.extra = extra
    }
}

extension NovaInterstitialAdItem {
    var novaAdReportContext: NovaAdReportContext {
        return .init(
            advertiser: advertiser,
            headline: headline,
            body: body,
            adId: adId,
            adSetId: adSetId,
            adRequestId: requestId,
            encryptedToken: encryptedAdToken
        )
    }
}

public protocol NovaInterstitialAdReportHandling {
    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext)

    // optional methods
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool
}

public extension NovaInterstitialAdReportHandling {
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool { false }
}

// MARK: - NovaInterstitialAdViewController

class NovaInterstitialAdViewController: UIViewController {
    // MARK: Lifecycle

    init(interstitialAd: NovaInterstitialAdItem, reportHandling: (any NovaInterstitialAdReportHandling)) {
        self.interstitialAd = interstitialAd
        self.reportHandling = reportHandling

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Support all orientations on iPad, portrait only on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
        } else {
            return .portrait
        }
    }

    override var shouldAutorotate: Bool {
        // Allow rotation on iPad, disable on iPhone
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = NovaColorPalettes.buttonText
        setupSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        adView?.willAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        adView?.didAppear()

        if !didAppear {
            didAppear = true

            // Enhanced impression logging from NewsBreak
            NovaAdMetricReporter
                .logAdImpression(
                    thirdPartyImpressionTrackingUrls: interstitialAd.thirdPartyImpressionTrackingUrls,
                    encryptedAdToken: interstitialAd.encryptedAdToken,
                    adUnitId: interstitialAd.adUnitId
                )

            // Enhanced tracing from NewsBreak (simplified for NovaCore)
            if let tracingID = interstitialAd.adOpportunityID {
                // TODO: Implement tracing functionality when needed
                print("Tracing impression for ID: \(tracingID)")
            }
        }
        interstitialAd.delegate?.interstitialAdDidDisplay(interstitialAd)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Will disappear - protocol method handles the specifics
        adView?.willDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // End playing - protocol method handles the specifics
        adView?.didDisappear()

        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // TODO: lsy, check out if this logic works
        guard let _ = self.adView as? NovaInterstitialAdNormalView,
              UIDevice.current.userInterfaceIdiom == .pad
        else {
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.adView?.setupSubviews()
        })
    }

    @objc func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        dismiss(animated: false) {
            self.interstitialAd.delegate?.interstitialAdDidDismiss(self.interstitialAd)
        }
    }

    // MARK: Private

    private let interstitialAd: NovaInterstitialAdItem
    private let reportHandling: any NovaInterstitialAdReportHandling
    private var didAppear: Bool = false

    private var adView: NovaInterstitialAdViewProtocol?
}

// MARK: - Private Extension

private extension NovaInterstitialAdViewController {
    private func setupSubviews() {
        let adView = NovaInterstitialAdViewFactory.createAdView(
            interstitialAd: interstitialAd,
            viewController: self,
            reportHandling: reportHandling
        )

        // Add the view to the view hierarchy
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.adView = adView
    }
}
