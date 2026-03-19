//
//  AdListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//

import Foundation
import UIKit

public protocol AdListener: AnyObject {
    //Deprecated after SDK Bidding:
    //func onAdLoaded(ad: MSPAd)
    @available(*, deprecated, message: "Use onError(msg:loadInfo:) instead")
    func onError(msg: String)
    func onError(msg: String, loadInfo: [String: Any])

    func onAdImpression(ad: MSPAd)

    func onAdClick(ad: MSPAd)

    @available(*, deprecated, message: "Use onAdLoaded(placementId:loadInfo:) instead")
    func onAdLoaded(placementId: String)
    func onAdLoaded(placementId: String, loadInfo: [String: Any])

    func onAdDismissed(ad: MSPAd)
    /// Called when the user earns the reward for a rewarded ad.
    /// This callback is emitted at most once per ad instance.
    func onAdRewardReceived(ad: MSPAd)

    func getRootViewController() -> UIViewController?
}

// MARK: - Backward Compatibility
public extension AdListener {
    func onError(msg: String) {
    }

    func onError(msg: String, loadInfo: [String: Any]) {
        onError(msg: msg)
    }

    func onAdLoaded(placementId: String) {
    }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        onAdLoaded(placementId: placementId)
    }

    func onAdRewardReceived(ad: MSPAd) {
    }
}
