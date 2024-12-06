//
//  NovaAppOpenAdViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

public enum NovaAppOpenAdResource {
    case image(UIImage)
    case imageURL(String)
    case video(NovaNativeAdVideoInfo)
}

@objc public class NovaAppOpenAdViewController: UIViewController {

    // MARK: - Properties

    private let appOpenAd: NovaAppOpenAd
    private let adResource: NovaAppOpenAdResource
    private var hasImpressionLogged: Bool

    init(appOpenAd: NovaAppOpenAd, adResource: NovaAppOpenAdResource) {
        self.appOpenAd = appOpenAd
        self.adResource = adResource
        self.hasImpressionLogged = false

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {

        let viewActionHandler = NovaAppOpenAdViewActionHandler(viewController: self)
        let actionHandler = ActionHandlerMaster(actionHandlers: [viewActionHandler])
        
        let adView: UIView
        
        switch adResource {
        case let .image(image):
            let media = NovaNativeAdMedia.image(.image(image))
            if appOpenAd.isVerticalImage ?? false {
                adView = NovaAppOpenVerticalImageAdView(with: media, appOpenAd: appOpenAd, actionHandler: actionHandler)
            } else {
                adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler)
            }
            
        case let .imageURL(imageURL):
            let media = NovaNativeAdMedia.image(.imageURLStr(imageURL))
            adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler)
            

        case .video(let videoInfo):
            if videoInfo.isVertical {
                adView = NovaAppOpenVerticalVideoAdView(appOpenAd: appOpenAd, videoInfo: videoInfo, actionHandler: actionHandler, viewController: self)
            } else {
                let media = NovaNativeAdMedia.video(NovaNativeAdVideoResource(videoInfo: videoInfo, adToken: appOpenAd.encryptedAdToken, reporter: nil))
                adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler)
                
            }
        }
       
        view = adView
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if case let .video(videoInfo) = adResource {
            if videoInfo.isVertical {
                (view as? NovaAppOpenVerticalVideoAdView)?.startPlaying()
            } else {
                (view as? NovaAppOpenAdViewV3)?.mediaStartShown()
            }
        }
        
        if !hasImpressionLogged {
            hasImpressionLogged = true
            NovaAdMetricReporter.logAdImpression(
                thirdPartyImpressionTrackingUrls: appOpenAd.thirdPartyImpressionTrackingUrls,
                encryptedAdToken: appOpenAd.encryptedAdToken,
                startTimeInMs: appOpenAd.startTimeInMs,
                expirationTimeInMs: appOpenAd.expirationTimeInMs)
            
            appOpenAd.delegate?.appOpenAdDidDisplay(appOpenAd)
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if case let .video(videoInfo) = adResource {
            if videoInfo.isVertical {
                (view as? NovaAppOpenVerticalVideoAdView)?.endPlaying()
            } else {
                (view as? NovaAppOpenAdViewV3)?.mediaEndShown()
            }
        }

        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    @objc internal func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        //dismiss(animated: false)
    }
}
