//
//  NovaAdOpenActionHandler.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/19/24.
//

import Foundation
import UIKit


public final class NovaAdOpenActionHandler: NSObject {
    // MARK: - Properties

    private static let acceptedSchemes: [String] = ["http", "https", "newsbreak"]
    private static let httpSchemes: [String] = ["http", "https"]

    private var model: NovaAdOpenActionDataModel?
    private var webType: NovaAdOpenLandingLogger.WebType?
    
    private weak var viewController: UIViewController?
    
    public init(viewController: UIViewController?) {
        self.viewController = viewController
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willResignActiveNotification,
                                                  object: nil)
    }
}

// MARK: - ActionHandling

extension NovaAdOpenActionHandler: ActionHandling {
    public func supportedActions() -> [String: Any.Type] {
        return [
            NovaAdOpenActionKey.launchBrowser.rawValue: NovaAdOpenActionDataModel.self,
            NovaAdOpenActionKey.launchWebView.rawValue: NovaAdOpenActionDataModel.self,
            NovaAdOpenActionKey.launchStore.rawValue: NovaAdOpenActionDataModel.self
        ]
    }

    public func performAction(actionModel: ActionModel) {
        guard let actionKey = NovaAdOpenActionKey(rawValue: actionModel.actionKey) else { return }
        guard let actionDataModel = SafeAs(actionModel.actionDataModel, NovaAdOpenActionDataModel.self) else {
            return
        }

        switch actionKey {
        case NovaAdOpenActionKey.launchBrowser:
            launchBrowser(with: actionDataModel.url)

        case NovaAdOpenActionKey.launchWebView:
            launchWebView(with: actionDataModel.url, model: actionDataModel)
            
        case NovaAdOpenActionKey.launchStore:
            if let appStoreId = actionDataModel.appStoreId,
               !appStoreId.isEmpty,
                let appStoreIdInInt = Int(appStoreId) {
                NovaAdOpenActionHandleUtil.launchStore(with: actionDataModel.url, appStoreId: appStoreIdInInt, viewController: self.viewController, model: self.model)
            } else {
                launchWebView(with: actionDataModel.url, model: actionDataModel)
            }
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

// MARK: - Private methods

private extension NovaAdOpenActionHandler {

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
        guard let vc = UIApplication.novakeyRootViewController else {
            assertionFailure("Invalid vc.")
            launchBrowser(with: url)
            return
        }

        self.model = model
        webType = .unified
        DispatchQueue.main.async {
            NovaAdOpenActionHandleUtil.launchUnified(vc: vc, model: model)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillResignActive(_:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        checkIfAliveAfter5s(webType: webType!)
    }

    @objc func handleApplicationWillResignActive(_ aNoticiation: Notification) {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willResignActiveNotification,
                                                  object: nil)
        guard let model = self.model, let webType = webType else {
            assertionFailure("Invalid status, missing data model.")
            return
        }
        NovaAdMetricReporter.logWebEvent(.novaLandingPageResignActive, encryptedAdToken: model.encryptedAdToken)
        /*
        NovaAdOpenLandingLogger.logResignActive(adId: model.adId,
                                               requestId: model.requestId,
                                               adUnitId: model.adUnitId,
                                               startTime: model.clickTime,
                                               webType: webType)
         */
    }

    func checkIfAliveAfter5s(webType: NovaAdOpenLandingLogger.WebType) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) { [weak self] in
            
            if let self, let model = self.model {
                NovaAdMetricReporter.logWebEvent(.novaLandingPageAliveAfter5s, encryptedAdToken: model.encryptedAdToken)
                /*
                NovaAdOpenLandingLogger.logAliveAfter5Seconds(adId: model.adId,
                                                             requestId: model.requestId,
                                                             adUnitId: model.adUnitId,
                                                             startTime: model.clickTime,
                                                             webType: webType)
                 */
            } else {
                NovaAdMetricReporter.logWebEvent(.novaLandingPageRecycledAfter5s, encryptedAdToken: self?.model?.encryptedAdToken ?? "")
                //NovaAdOpenLandingLogger.logRecycledAfter5Seconds(webType: webType)
            }
             
        }
    }
}
