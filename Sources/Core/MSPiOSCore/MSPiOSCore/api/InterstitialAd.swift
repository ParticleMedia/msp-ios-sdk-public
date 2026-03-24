//
//  InterstitialAd.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 9/30/24.
//

import Foundation
import UIKit

public protocol InterstitialAdReportHandling: AnyObject {
    func startReportFlow(
        from presentingVC: UIViewController?,
        for ad: InterstitialAd,
        metadata: [String: Any]?
    )

    // MARK: Optional Methods
    func canShowReportButton(for ad: InterstitialAd) -> Bool
}

extension InterstitialAdReportHandling {
    public func canShowReportButton(for ad: InterstitialAd) -> Bool { false }
}

open class InterstitialAd: MSPAd {
    @MainActor
    open func show() {
        fatalError("Subclass must override show() method")
    }

    @MainActor
    open func show(rootViewController: UIViewController?) {
        show()
    }

    @MainActor
    open func show(rootViewController: UIViewController?, interstitialAdReportHandling: InterstitialAdReportHandling?) {
        show(rootViewController: rootViewController)
    }
}
