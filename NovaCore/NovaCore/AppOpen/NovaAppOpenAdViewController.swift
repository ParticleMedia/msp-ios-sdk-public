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
    
    var countdownTimer: Timer?
    var countdownSecondRemaining: Int

    init(appOpenAd: NovaAppOpenAd, adResource: NovaAppOpenAdResource) {
        self.appOpenAd = appOpenAd
        self.adResource = adResource
        self.hasImpressionLogged = false
        self.countdownSecondRemaining = appOpenAd.closeCountDownTimeSecond ?? 0

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
        
        if let novaAppOpenAdLayout = appOpenAd.novaAppOpenAdLayout {
            let media: NovaNativeAdMedia
            switch adResource {
            case let .image(image):
                media = NovaNativeAdMedia.image(.image(image))
            case let .imageURL(imageURL):
                media = NovaNativeAdMedia.image(.imageURLStr(imageURL))
            case .video(let videoInfo):
                media = NovaNativeAdMedia.video(NovaNativeAdVideoResource(videoInfo: videoInfo, adToken: appOpenAd.encryptedAdToken, reporter: nil))
            }
            switch novaAppOpenAdLayout {
            case .vertical, .verticalCancelTopRight, .endCard:
                if case let .video(videoInfo) = adResource {
                    adView = NovaAppOpenVerticalVideoAdView(appOpenAd: appOpenAd, videoInfo: videoInfo, actionHandler: actionHandler, viewController: self, novaAppOpenAdLayout: novaAppOpenAdLayout)
                } else {
                    adView = NovaAppOpenVerticalImageAdView(with: media, appOpenAd: appOpenAd, actionHandler: actionHandler, viewController: self, novaAppOpenAdLayout: novaAppOpenAdLayout)
                }
            case .horizontal, .horizontalCancelTopRight:
                adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler, novaAppOpenAdLayout: novaAppOpenAdLayout)
            }
        } else {
            
            switch adResource {
            case let .image(image):
                let media = NovaNativeAdMedia.image(.image(image))
                if appOpenAd.isVerticalImage ?? false {
                    adView = NovaAppOpenVerticalImageAdView(with: media, appOpenAd: appOpenAd, actionHandler: actionHandler, viewController: self, novaAppOpenAdLayout: nil)
                } else {
                    adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler, novaAppOpenAdLayout: nil)
                }
                
            case let .imageURL(imageURL):
                let media = NovaNativeAdMedia.image(.imageURLStr(imageURL))
                adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler, novaAppOpenAdLayout: nil)
                
                
            case .video(let videoInfo):
                if videoInfo.isVertical {
                    adView = NovaAppOpenVerticalVideoAdView(appOpenAd: appOpenAd, videoInfo: videoInfo, actionHandler: actionHandler, viewController: self, novaAppOpenAdLayout: nil)
                } else {
                    let media = NovaNativeAdMedia.video(NovaNativeAdVideoResource(videoInfo: videoInfo, adToken: appOpenAd.encryptedAdToken, reporter: nil))
                    adView = NovaAppOpenAdViewV3(with: media, openAd: appOpenAd, actionHandler: actionHandler, novaAppOpenAdLayout: nil)
                    
                }
            }
        }
       
        view = adView
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.appOpenAd.novaAppOpenAdLayout == .horizontalCancelTopRight || self.appOpenAd.novaAppOpenAdLayout == .verticalCancelTopRight {
            var button: UIButton?
            var clickableArea: UIView?
            if view is NovaAppOpenAdViewV3,
               let appOpenAdView = view as? NovaAppOpenAdViewV3 {
                button = appOpenAdView.topRightCloseButton
                clickableArea = appOpenAdView.topRightCloseButtonArea
            } else if view is NovaAppOpenVerticalImageAdView,
                      let appOpenAdView = view as? NovaAppOpenVerticalImageAdView {
                button = appOpenAdView.topRightCloseButton
                clickableArea = appOpenAdView.topRightCloseButtonArea
            } else if view is NovaAppOpenVerticalVideoAdView,
                      let appOpenAdView = view as? NovaAppOpenVerticalVideoAdView{
                button = appOpenAdView.topRightCloseButton
                clickableArea = appOpenAdView.topRightCloseButtonArea
            }
            
            if let button = button,
               let clickableArea = clickableArea {
                if self.countdownSecondRemaining > 0 {
                    self.topRightCloseButtonStartCountDown(button: button, clickableArea: clickableArea)
                } else {
                    self.enableTopRightCloseButton(button: button, clickableArea: clickableArea)
                }
            }
        }
        //(self.view as? NovaAppOpenAdViewV3)?.renderTopRightCloseButton()
    }
    
    public func topRightCloseButtonStartCountDown(button: UIButton, clickableArea: UIView) {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.countdownSecondRemaining > 0 {
                clickableArea.isUserInteractionEnabled = false
                button.setTitle("\(self.countdownSecondRemaining)", for: .normal)
            } else {
                self.enableTopRightCloseButton(button: button, clickableArea: clickableArea)
            }
            self.countdownSecondRemaining -= 1
        }
        countdownTimer?.fire()
    }
    public func enableTopRightCloseButton(button: UIButton, clickableArea: UIView) {
        clickableArea.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        clickableArea.isUserInteractionEnabled = true
        self.countdownTimer?.invalidate()
        button.setTitle(nil, for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let darkColor = self.appOpenAd.novaAppOpenAdLayout == .verticalCancelTopRight ? NovaColorPalettes.Gray.tint600 : NovaColorPalettes.Gray.tint200
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config)?.withTintColor(UIColor(light: NovaColorPalettes.Gray.tint600, dark: darkColor), renderingMode: .alwaysOriginal), for: .normal)
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
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    public override var shouldAutorotate: Bool {
        return false
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
         
        guard let adView = self.view as? NovaAppOpenAdViewV3,
              UIDevice.current.userInterfaceIdiom == .pad else {
            return
        }
        coordinator.animate(alongsideTransition: { _ in
            adView.setupSubviews()
        })
    }
}
