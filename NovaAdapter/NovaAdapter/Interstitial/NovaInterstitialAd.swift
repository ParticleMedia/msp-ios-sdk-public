//
//  NovaInterstitialAd.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import MSPiOSCore
import NovaCore
import UIKit


public class NovaInterstitialAd: MSPiOSCore.InterstitialAd {
    public weak var rootViewController: UIViewController?
    public var interstitialAdItem: NovaInterstitialAdItem?
    
    public override func show() {
        if let rootViewController = rootViewController {
            let reportAdapter = ReportHandlerAdapter(outer: nil, ad: self)
            interstitialAdItem?.present(rootViewController: rootViewController, reportHandling: reportAdapter)
        }
    }
    
    public override func show(rootViewController: UIViewController?) {
        if let rootViewController = rootViewController {
            let reportAdapter = ReportHandlerAdapter(outer: nil, ad: self)
            interstitialAdItem?.present(rootViewController: rootViewController, reportHandling: reportAdapter)
        }
    }

    public override func show(
        rootViewController: UIViewController?,
        interstitialAdReportHandling: (any InterstitialAdReportHandling)?
    ) {
        if let rootViewController {
            let reportAdapter = ReportHandlerAdapter(outer: interstitialAdReportHandling, ad: self)
            interstitialAdItem?
                .present(rootViewController: rootViewController, reportHandling: reportAdapter)
        }
    }

    public override func isValid() -> Bool {
        return interstitialAdItem != nil
    }

    public override func dismiss(animated: Bool) {
        interstitialAdItem?.dismiss(animated: animated)
    }
}
