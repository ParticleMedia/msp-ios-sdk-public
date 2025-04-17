//
//  NovaAppOpenAdViewActionHandler.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

@objc public class NovaAppOpenAdViewActionHandler: NSObject {
    private weak var viewController: UIViewController?
    //private var feedbackHandler: AdsFeedbackActionHandler?
    //private weak var feedbackDelegate: AdsFeedbackActionDelegate?

    public init(viewController: UIViewController) {
        self.viewController = viewController
        //self.feedbackDelegate = feedbackDelegate
        super.init()
    }
    
    private static let acceptedSchemes: [String] = ["http", "https", "newsbreak"]
    private static let httpSchemes: [String] = ["http", "https"]

    private var model: NovaAdOpenActionDataModel?
    private var webType: NovaAdOpenLandingLogger.WebType?
}

extension NovaAppOpenAdViewActionHandler: ActionHandling {
    public func supportedActions() -> [String: Any.Type] {
        return [
            NovaAppOpenAdViewActionKey.adTapped.rawValue: EmptyActionDataModel.self,
            NovaAppOpenAdViewActionKey.manualSkip.rawValue: EmptyActionDataModel.self,
            NovaAppOpenAdViewActionKey.launchBrowser.rawValue: NovaAdOpenActionDataModel.self,
            NovaAppOpenAdViewActionKey.launchWebView.rawValue: NovaAdOpenActionDataModel.self,
            NovaAppOpenAdViewActionKey.launchStore.rawValue:
                NovaAdOpenActionDataModel.self,
            //NovaAppOpenAdViewActionKey.feedbackReport.rawValue: NovaAppOpenAdFeedBackReportActionModel.self,
        ]
    }

    public func performAction(actionModel: ActionModel) {
        
        switch actionModel.actionKey {
        case NovaAppOpenAdViewActionKey.adTapped.rawValue:
            didTapAd()

        case NovaAppOpenAdViewActionKey.manualSkip.rawValue:
            didManualSkip()
            
        case NovaAppOpenAdViewActionKey.launchBrowser.rawValue:
            guard let actionDataModel = SafeAs(actionModel.actionDataModel, NovaAdOpenActionDataModel.self) else {
                return
            }
            launchBrowser(with: actionDataModel.url)
            
        case NovaAppOpenAdViewActionKey.launchWebView.rawValue:
            guard let actionDataModel = SafeAs(actionModel.actionDataModel, NovaAdOpenActionDataModel.self) else {
                return
            }
            launchWebView(with: actionDataModel.url, model: actionDataModel)

        //case NovaAppOpenAdViewActionKey.feedbackReport.rawValue:
            //if let dataModel = actionModel.actionDataModel as? NovaAppOpenAdFeedBackReportActionModel {
            //    didTapReportAd(with: dataModel.appOpenAd)
            //}
            
        case NovaAppOpenAdViewActionKey.launchStore.rawValue:
            guard let actionDataModel = SafeAs(actionModel.actionDataModel, NovaAdOpenActionDataModel.self) else {
                return
            }
            if let appStoreId = actionDataModel.appStoreId,
               !appStoreId.isEmpty,
                let appStoreIdInInt = Int(appStoreId) {
                NovaAdOpenActionHandleUtil.launchStore(with: actionDataModel.url, appStoreId: appStoreIdInInt, viewController: self.viewController, model: self.model)
            } else {
                launchWebView(with: actionDataModel.url, model: actionDataModel)
            }

        default:
            break
        }
    }
}

private extension NovaAppOpenAdViewActionHandler {
    func didTapAd() {
        //viewController?.dismiss(animated: true)
    }

    func didManualSkip() {
        viewController?.dismiss(animated: true)
    }

    /*
    func didTapReportAd(with appOpenAd: NovaAppOpenAd) {
        guard let vc = viewController ?? UIApplication.keyRootViewController else {
            return
        }
        guard let feedbackDelegate else {
            DebugLogging.info(.ads, "interstitial ad's feedback delegate should not be nil")
            return
        }
        let selectAdDataModel = createSelectedAdDataModel(with: appOpenAd)

        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [])
        let bottomSheetViewController = AdsFeedbackBottomSheetViewController(
            actionHandler: actionHandlerMaster,
            shouldShowHideOption: false
        )

        let adsFeedbackActionHandler = AdsFeedbackActionHandler(
            selectedAdDataModel: selectAdDataModel,
            bottomSheetViewController: bottomSheetViewController,
            rootViewController: vc,
            delegate: feedbackDelegate
        )
        // NOTE: (shanyu.li) action handler needs to be kept to ensure it is not nil when calling `handleFeedbackViewDismissed`
        self.feedbackHandler = adsFeedbackActionHandler
        actionHandlerMaster.addActionHandlers(actionHandlers: [adsFeedbackActionHandler])

        let presentationController = SheetPresentationController(
            presentedViewController: bottomSheetViewController,
            presenting: vc,
            enablePullDownToDismiss: false
        )

        bottomSheetViewController.transitioningDelegate = presentationController
        viewController?.present(bottomSheetViewController, animated: true)
    }

    func createSelectedAdDataModel(with appOpenAd: NovaAppOpenAd) -> AdsFeedbackSelectedAdDataModel {
        return AdsFeedbackSelectedAdDataModel(adOpportunityId: "",
                                              placementId: appOpenAd.adUnitId,
                                              adType: "nova",
                                              advertiser: appOpenAd.advertiser,
                                              headline: appOpenAd.headline,
                                              body: appOpenAd.body,
                                              eCPMInDollar: 0,
                                              adRequestId: appOpenAd.requestId,
                                              adSetId: appOpenAd.adSetId,
                                              adId: appOpenAd.adId,
                                              encryptedAdToken: appOpenAd.encryptedAdToken,
                                              isNovaAd: true,
                                              shouldShowHideOption: false)
    }
     */
    
    
    func launchBrowser(with url: URL) {
        guard let scheme = url.scheme,
              Self.acceptedSchemes.contains(scheme)
        else {
            assertionFailure("Invalid url.")
            return
        }

        UIApplication.shared.open(url)
    }

    func launchWebView(with url: URL, model: NovaAdOpenActionDataModel) {
        // It would crash if we pass in url that is not with http:// or https:// schemes.
        guard let scheme = url.scheme,
              Self.httpSchemes.contains(scheme)
        else {
            assertionFailure("Invalid url.")
            launchBrowser(with: url)
            return
        }
        guard let vc = self.viewController else {
            assertionFailure("Invalid vc.")
            launchBrowser(with: url)
            return
        }

        self.model = model
        webType = .unified
        DispatchQueue.main.async {
            NovaAdOpenActionHandleUtil.launchUnified(vc: vc, model: model)
        }
    }
    
    public func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
    //            assertionFailure("cannot cast \(object) to \(objectType)")
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }
}


