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
}

extension NovaAppOpenAdViewActionHandler: ActionHandling {
    public func supportedActions() -> [String: Any.Type] {
        return [
            NovaAppOpenAdViewActionKey.adTapped.rawValue: EmptyActionDataModel.self,
            NovaAppOpenAdViewActionKey.manualSkip.rawValue: EmptyActionDataModel.self,
            //NovaAppOpenAdViewActionKey.feedbackReport.rawValue: NovaAppOpenAdFeedBackReportActionModel.self,
        ]
    }

    public func performAction(actionModel: ActionModel) {
        switch actionModel.actionKey {
        case NovaAppOpenAdViewActionKey.adTapped.rawValue:
            didTapAd()

        case NovaAppOpenAdViewActionKey.manualSkip.rawValue:
            didManualSkip()

        //case NovaAppOpenAdViewActionKey.feedbackReport.rawValue:
            //if let dataModel = actionModel.actionDataModel as? NovaAppOpenAdFeedBackReportActionModel {
            //    didTapReportAd(with: dataModel.appOpenAd)
            //}

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
}
