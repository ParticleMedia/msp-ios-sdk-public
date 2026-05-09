//
//  NovaRewardedAdDelegate.swift
//  NovaCore
//

import Foundation

/// Lifecycle callbacks specific to rewarded ads.
public protocol NovaRewardedAdDelegate: AnyObject {
    func rewardedAdDidDisplay(_ rewardedAd: NovaRewardedAdItem)
    func rewardedAdDidDismiss(_ rewardedAd: NovaRewardedAdItem)
    func rewardedAdDidLogClick(_ rewardedAd: NovaRewardedAdItem, clickAreaName: String?, clickPosition: UInt32?)
    /// Called when the H5 page fires `novaNativeBridge.onAdRewarded()`.
    /// Guaranteed to fire at most once per ad instance.
    func rewardedAdDidEarnReward(_ rewardedAd: NovaRewardedAdItem)
}
