//
//  NovaAdOpenActionHandleUtil.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 4/16/25.
//

import UIKit
import StoreKit

public class NovaAdOpenActionHandleUtil {
    
    private class StoreDelegate: NSObject, SKStoreProductViewControllerDelegate {
        func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
            viewController.dismiss(animated: true, completion: nil)
        }
    }
    
    static func launchStore(with url: URL, appStoreId: Int, viewController: UIViewController?, model: NovaAdOpenActionDataModel?) {
        let storeViewController = SKStoreProductViewController()
        storeViewController.delegate = StoreDelegate()
        let parameters = [SKStoreProductParameterITunesItemIdentifier: appStoreId]
        storeViewController.loadProduct(withParameters: parameters) {result, error in
            guard let vc = viewController ?? UIApplication.novakeyRootViewController else {
                return
            }
            if result {
                NovaAdOpenActionHandleUtil.appInstallConversionTracking(to: url)
                vc.present(storeViewController, animated: true)
            } else {
                // possible skerror: https://adapty.io/blog/ios-skerrordomain-error-codes/
               
                guard let model = model else {
                    return
                }
                NovaAdOpenActionHandleUtil.launchUnified(vc: vc, model: model)
            }
        }
    }
    
    static func launchUnified(vc: UIViewController, model: NovaAdOpenActionDataModel) {
        let webViewController = {
            if let videoInfo = model.videoInfo, videoInfo.isPlayOnLandingPage {
                NovaAdsVideoLandingWebViewController(model: model)
            } else {
                NovaAdsLandingWebViewController(dataModel: model)
            }
        }()
        webViewController.modalPresentationStyle = .fullScreen
        vc.present(webViewController, animated: true)
    }
    
    static func appInstallConversionTracking(to thirdPartyUrl: URL) {
        URLSession.shared.dataTask(with: thirdPartyUrl, completionHandler: {_, _, _ in }).resume()
    }
}
