//
//  NovaInterstitialAdViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
@_implementationOnly import SnapKit
import UIKit

// MARK: - NovaAdsFeedbackActionDelegate

protocol NovaAdsFeedbackActionDelegate: AnyObject {
    func updateAdFeedbackViewForViewType(_ viewType: Int)
}

// MARK: - NovaAdFeedbackViewType

enum NovaAdFeedbackViewType: Int {
    case reportAdView = 0
    case hideAdView = 1
    case other = 2
}

// MARK: - NovaInterstitialAdViewController

class NovaInterstitialAdViewController: UIViewController {
    // MARK: Lifecycle

    init(interstitialAd: NovaInterstitialAdItem) {
        self.interstitialAd = interstitialAd

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

    // MARK: - Feedback delegate

    weak var feedbackDelegate: NovaAdsFeedbackActionDelegate?

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
        dismiss(animated: false)
    }

    // MARK: - Feedback Methods

    func updateAdFeedbackViewForViewType(_ viewType: Int) {
        switch viewType {
        case NovaAdFeedbackViewType.reportAdView.rawValue, NovaAdFeedbackViewType.hideAdView.rawValue:
            dismiss(animated: true)
            interstitialAd.delegate?.interstitialAdDidDismiss(interstitialAd)
        default:
            break
        }
    }

    // MARK: Private

    private let interstitialAd: NovaInterstitialAdItem
    private var didAppear: Bool = false

    private var adView: NovaInterstitialAdViewProtocol?
}

// MARK: - Private Extension

private extension NovaInterstitialAdViewController {
    private func setupSubviews() {
        let adView = NovaInterstitialAdViewFactory.createAdView(
            interstitialAd: interstitialAd,
            viewController: self
        )

        // Add the view to the view hierarchy
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.adView = adView
    }
}
